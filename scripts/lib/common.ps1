$ErrorActionPreference = "Stop"

if (-not (Get-Variable -Name JsonFileCache -Scope Script -ErrorAction SilentlyContinue)) {
  $script:JsonFileCache = @{}
}
if (-not (Get-Variable -Name FileHashCache -Scope Script -ErrorAction SilentlyContinue)) {
  $script:FileHashCache = @{}
}

function Get-FileCacheStamp([string]$Path) {
  $fileInfo = Get-Item -LiteralPath $Path -ErrorAction Stop
  return ($fileInfo.Length.ToString() + ":" + $fileInfo.LastWriteTimeUtc.Ticks.ToString())
}

function Read-JsonFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [object]$DefaultValue = $null,
    [switch]$UseCache,
    [string]$DisplayName = ""
  )

  if ([string]::IsNullOrWhiteSpace($Path)) {
    throw "Path is required for Read-JsonFile."
  }
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $DefaultValue
  }

  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $cacheKey = $fullPath.ToLowerInvariant()
  $stamp = Get-FileCacheStamp -Path $fullPath

  if ($UseCache -and $script:JsonFileCache.ContainsKey($cacheKey)) {
    $cached = $script:JsonFileCache[$cacheKey]
    if ($null -ne $cached -and $cached.PSObject.Properties['stamp'] -and [string]$cached.stamp -eq $stamp) {
      return $cached.value
    }
  }

  $label = if ([string]::IsNullOrWhiteSpace($DisplayName)) { $fullPath } else { $DisplayName }
  try {
    $value = Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json
  } catch {
    throw "$label invalid JSON: $fullPath"
  }

  if ($UseCache) {
    $script:JsonFileCache[$cacheKey] = [pscustomobject]@{
      stamp = $stamp
      value = $value
    }
  }

  if ($null -eq $value) {
    return $DefaultValue
  }

  return $value
}

function Read-JsonArray([string]$Path) {
  $raw = Read-JsonFile -Path $Path -DefaultValue @() -UseCache
  if ($null -eq $raw) { return @() }
  if ($raw -is [System.Array]) { return @($raw) }
  if ($raw.PSObject -and $raw.PSObject.Properties['value']) { return @($raw.value) }
  return @($raw)
}

function Write-JsonArray([string]$Path, [object[]]$Items, [int]$Depth=6) {
  $json = @($Items) | ConvertTo-Json -Depth $Depth
  $jsonTrim = $json.TrimStart()
  if ($Items.Count -eq 1 -and -not $jsonTrim.StartsWith("[")) {
    $json = "[`n$json`n]"
  }
  Set-Content -Path $Path -Value $json -Encoding UTF8
}

function Read-Utf8NoBom([string]$Path) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  return [System.IO.File]::ReadAllText($Path, $enc)
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function Invoke-CommandCapture {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Command,
    [int]$HeadLines = 20,
    [switch]$IncludeTimestamp
  )

  $output = $null
  $exitCode = 0
  try {
    $output = Invoke-Expression $Command 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }
  } catch {
    $output = $_.Exception.Message
    $exitCode = 1
  }

  $lines = @()
  if (-not [string]::IsNullOrWhiteSpace($output)) {
    $lines = @(
      $output -split "`r?`n" |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      Select-Object -First $HeadLines
    )
  }

  $result = [ordered]@{
    cmd = $Command
    exit_code = [int]$exitCode
    key_output = ($lines -join " | ")
    raw_output = [string]$output
    output = [string]$output
  }
  if ($IncludeTimestamp) {
    $result.timestamp = (Get-Date).ToString("o")
  }

  return [pscustomobject]$result
}

function Assert-Command {
  param([Parameter(Mandatory = $true)][string]$Name)

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Invoke-LoggedCommand {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Action,
    [Parameter(Mandatory = $true)][string]$WorkDir,
    [Parameter(Mandatory = $true)][string]$LogRoot
  )

  if (-not (Test-Path -LiteralPath $LogRoot -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
  }

  $safeName = ($Name -replace '[^a-zA-Z0-9._-]', '_')
  $logPath = Join-Path $LogRoot ((Get-Date -Format "yyyyMMdd-HHmmss") + "-" + $safeName + ".log")

  Push-Location $WorkDir
  try {
    & $Action *>&1 | Tee-Object -LiteralPath $logPath | Out-Host
    $exitCode = $LASTEXITCODE
  } finally {
    Pop-Location
  }

  if ($null -eq $exitCode) { $exitCode = 0 }

  return [pscustomobject]@{
    name = $Name
    exit_code = [int]$exitCode
    log_path = $logPath
  }
}

function Get-FileSha256([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) {
    throw "Path is required for Get-FileSha256."
  }
  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "File not found: $Path"
  }

  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $cacheKey = $fullPath.ToLowerInvariant()
  $cacheStamp = Get-FileCacheStamp -Path $fullPath
  if ($script:FileHashCache.ContainsKey($cacheKey)) {
    $cached = $script:FileHashCache[$cacheKey]
    if ($null -ne $cached -and $cached.PSObject.Properties['stamp'] -and [string]$cached.stamp -eq $cacheStamp) {
      return [string]$cached.hash
    }
  }

  $hashCmd = Get-Command -Name "Get-FileHash" -ErrorAction SilentlyContinue
  $hash = $null
  if ($null -ne $hashCmd) {
    $hash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    $script:FileHashCache[$cacheKey] = [pscustomobject]@{
      stamp = $cacheStamp
      hash = $hash
    }
    return $hash
  }

  $stream = $null
  $sha256 = $null
  try {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($fullPath)
    $bytes = $sha256.ComputeHash($stream)
    $hash = ([System.BitConverter]::ToString($bytes) -replace '-', '')
    $script:FileHashCache[$cacheKey] = [pscustomobject]@{
      stamp = $cacheStamp
      hash = $hash
    }
    return $hash
  } finally {
    if ($null -ne $stream) {
      $stream.Dispose()
    }
    if ($null -ne $sha256) {
      $sha256.Dispose()
    }
  }
}

function Test-FileContentEqual([string]$PathA, [string]$PathB) {
  if ([string]::IsNullOrWhiteSpace($PathA) -or [string]::IsNullOrWhiteSpace($PathB)) {
    throw "Both file paths are required for Test-FileContentEqual."
  }
  if (-not (Test-Path -LiteralPath $PathA -PathType Leaf)) { return $false }
  if (-not (Test-Path -LiteralPath $PathB -PathType Leaf)) { return $false }

  $a = Get-Item -LiteralPath $PathA -ErrorAction Stop
  $b = Get-Item -LiteralPath $PathB -ErrorAction Stop
  if ($a.Length -ne $b.Length) { return $false }
  if ($a.Length -eq 0) { return $true }

  $hashA = Get-FileSha256 -Path $a.FullName
  $hashB = Get-FileSha256 -Path $b.FullName
  return $hashA -eq $hashB
}

function Normalize-Repo([string]$Path) {
  return ([System.IO.Path]::GetFullPath(($Path -replace '/', '\')) -replace '\\','/').TrimEnd('/')
}

function Get-RelativePathSafe([string]$BasePath, [string]$TargetPath) {
  $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\')
  $target = [System.IO.Path]::GetFullPath($TargetPath)
  if ($target.StartsWith($base + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
    return $target.Substring($base.Length + 1) -replace '\\', '/'
  }
  return $target -replace '\\', '/'
}

function Is-ProjectRuleSource([string]$Source) {
  $s = ([string]$Source -replace '\\', '/')
  if (-not $s.StartsWith("source/project/", [System.StringComparison]::OrdinalIgnoreCase)) {
    return $false
  }
  # project custom files are installable for any repo matching repoName policy;
  # only top-level project rule docs are controlled by allowProjectRulesForRepos.
  if ($s -match "^source/project/[^/]+/custom/") {
    return $false
  }
  return $true
}

function Get-RepoName([string]$RepoPath) {
  $repoNorm = Normalize-Repo $RepoPath
  return Split-Path -Leaf $repoNorm
}

function Get-ProjectRuleSourceForRepo([string]$KitRoot, [string]$RepoPath, [string]$FileName) {
  $repoName = Get-RepoName $RepoPath
  $repoScopedRel = "source/project/$repoName/$FileName"
  $repoScopedAbs = Join-Path $KitRoot ($repoScopedRel -replace '/', '\')
  if (Test-Path $repoScopedAbs) {
    return $repoScopedRel
  }

  $legacyRel = "source/project/$FileName"
  $legacyAbs = Join-Path $KitRoot ($legacyRel -replace '/', '\')
  if (Test-Path $legacyAbs) {
    return $legacyRel
  }

  $templateRel = Get-DefaultProjectRuleTemplateSource -KitRoot $KitRoot -FileName $FileName
  if ($null -ne $templateRel) {
    return $templateRel
  }

  return $null
}

function Get-DefaultProjectRuleTemplateSource([string]$KitRoot, [string]$FileName) {
  if ([string]::IsNullOrWhiteSpace($FileName)) {
    return $null
  }

  $templateRel = "source/template/project/$FileName"
  $templateAbs = Join-Path $KitRoot ($templateRel -replace '/', '\')
  if (Test-Path -LiteralPath $templateAbs -PathType Leaf) {
    return $templateRel
  }

  return $null
}

function Get-ProjectRulePolicyPath([string]$KitRoot) {
  return Join-Path $KitRoot "config\project-rule-policy.json"
}

function Read-ProjectRulePolicy([string]$KitRoot) {
  $path = Get-ProjectRulePolicyPath $KitRoot
  $defaultPolicy = [pscustomobject]@{
    allowProjectRulesForRepos = @()
    defaults = [pscustomobject]@{
      allow_auto_fix = $true
      allow_rule_optimization = $true
      allow_local_optimize_without_backflow = $false
      max_autonomous_iterations = 3
      max_repeated_failure_per_step = 2
      stop_on_irreversible_risk = $true
      forbid_breaking_contract = $true
      auto_commit_enabled = $false
      auto_commit_on_checkpoints = @()
      auto_commit_message_prefix = "Governance milestone auto commit"
    }
    repos = @()
  }

  $policy = Read-JsonFile -Path $path -DefaultValue $null -UseCache -DisplayName "project-rule-policy.json"

  if ($null -eq $policy) {
    return $defaultPolicy
  }

  if ($null -eq $policy.PSObject.Properties['allowProjectRulesForRepos']) {
    $policy | Add-Member -NotePropertyName allowProjectRulesForRepos -NotePropertyValue @()
  }
  if ($null -eq $policy.PSObject.Properties['defaults']) {
    $policy | Add-Member -NotePropertyName defaults -NotePropertyValue $defaultPolicy.defaults
  }
  if ($null -eq $policy.defaults.PSObject.Properties['allow_auto_fix']) {
    $policy.defaults | Add-Member -NotePropertyName allow_auto_fix -NotePropertyValue $true
  }
  if ($null -eq $policy.defaults.PSObject.Properties['allow_rule_optimization']) {
    $policy.defaults | Add-Member -NotePropertyName allow_rule_optimization -NotePropertyValue $true
  }
  if ($null -eq $policy.defaults.PSObject.Properties['allow_local_optimize_without_backflow']) {
    $policy.defaults | Add-Member -NotePropertyName allow_local_optimize_without_backflow -NotePropertyValue $false
  }
  if ($null -eq $policy.defaults.PSObject.Properties['max_autonomous_iterations']) {
    $policy.defaults | Add-Member -NotePropertyName max_autonomous_iterations -NotePropertyValue 3
  }
  if ($null -eq $policy.defaults.PSObject.Properties['max_repeated_failure_per_step']) {
    $policy.defaults | Add-Member -NotePropertyName max_repeated_failure_per_step -NotePropertyValue 2
  }
  if ($null -eq $policy.defaults.PSObject.Properties['stop_on_irreversible_risk']) {
    $policy.defaults | Add-Member -NotePropertyName stop_on_irreversible_risk -NotePropertyValue $true
  }
  if ($null -eq $policy.defaults.PSObject.Properties['forbid_breaking_contract']) {
    $policy.defaults | Add-Member -NotePropertyName forbid_breaking_contract -NotePropertyValue $true
  }
  if ($null -eq $policy.defaults.PSObject.Properties['auto_commit_enabled']) {
    $policy.defaults | Add-Member -NotePropertyName auto_commit_enabled -NotePropertyValue $false
  }
  if ($null -eq $policy.defaults.PSObject.Properties['auto_commit_on_checkpoints']) {
    $policy.defaults | Add-Member -NotePropertyName auto_commit_on_checkpoints -NotePropertyValue @()
  }
  if ($null -eq $policy.defaults.PSObject.Properties['auto_commit_message_prefix']) {
    $policy.defaults | Add-Member -NotePropertyName auto_commit_message_prefix -NotePropertyValue "Governance milestone auto commit"
  }
  if ($null -eq $policy.PSObject.Properties['repos']) {
    $policy | Add-Member -NotePropertyName repos -NotePropertyValue @()
  }

  return $policy
}

function Read-ProjectRuleAllowRepos([string]$KitRoot) {
  $policy = Read-ProjectRulePolicy $KitRoot
  if ($null -eq $policy.allowProjectRulesForRepos) { return @() }
  $repos = @($policy.allowProjectRulesForRepos)
  $normalized = @()
  foreach ($r in $repos) {
    if (-not [string]::IsNullOrWhiteSpace([string]$r)) {
      $normalized += Normalize-Repo ([string]$r)
    }
  }
  return $normalized
}

function Is-RepoAllowedForProjectRules([string]$Repo, [string[]]$AllowRepos) {
  $repoNorm = Normalize-Repo $Repo
  foreach ($r in $AllowRepos) {
    if ((Normalize-Repo ([string]$r)).Equals($repoNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function Get-RepoAutomationPolicy([string]$KitRoot, [string]$Repo) {
  $repoNorm = Normalize-Repo $Repo
  $policy = Read-ProjectRulePolicy $KitRoot
  $allowRepos = @()
  if ($null -ne $policy.PSObject.Properties['allowProjectRulesForRepos'] -and $null -ne $policy.allowProjectRulesForRepos) {
    foreach ($r in @($policy.allowProjectRulesForRepos)) {
      if (-not [string]::IsNullOrWhiteSpace([string]$r)) {
        $allowRepos += Normalize-Repo ([string]$r)
      }
    }
  }
  $allowProjectRules = Is-RepoAllowedForProjectRules -Repo $repoNorm -AllowRepos $allowRepos

  $effectiveAllowAutoFix = [bool]$policy.defaults.allow_auto_fix
  $effectiveAllowRuleOptimization = [bool]$policy.defaults.allow_rule_optimization
  $effectiveAllowLocalOptimizeWithoutBackflow = [bool]$policy.defaults.allow_local_optimize_without_backflow
  $effectiveMaxAutonomousIterations = [int]$policy.defaults.max_autonomous_iterations
  $effectiveMaxRepeatedFailurePerStep = [int]$policy.defaults.max_repeated_failure_per_step
  $effectiveStopOnIrreversibleRisk = [bool]$policy.defaults.stop_on_irreversible_risk
  $effectiveForbidBreakingContract = [bool]$policy.defaults.forbid_breaking_contract
  $effectiveAutoCommitEnabled = [bool]$policy.defaults.auto_commit_enabled
  $effectiveAutoCommitOnCheckpoints = @($policy.defaults.auto_commit_on_checkpoints)
  $effectiveAutoCommitMessagePrefix = [string]$policy.defaults.auto_commit_message_prefix

  foreach ($entry in @($policy.repos)) {
    if ($null -eq $entry) { continue }

    $entryMatch = $false
    if ($entry.PSObject.Properties['repo'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repo)) {
      $entryRepoNorm = Normalize-Repo ([string]$entry.repo)
      if ($entryRepoNorm.Equals($repoNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
        $entryMatch = $true
      }
    }
    if (-not $entryMatch -and $entry.PSObject.Properties['repoName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repoName)) {
      $repoName = Get-RepoName $repoNorm
      if (([string]$entry.repoName).Equals($repoName, [System.StringComparison]::OrdinalIgnoreCase)) {
        $entryMatch = $true
      }
    }
    if (-not $entryMatch) { continue }

    if ($entry.PSObject.Properties['allow_auto_fix']) {
      $effectiveAllowAutoFix = [bool]$entry.allow_auto_fix
    }
    if ($entry.PSObject.Properties['allow_rule_optimization']) {
      $effectiveAllowRuleOptimization = [bool]$entry.allow_rule_optimization
    }
    if ($entry.PSObject.Properties['allow_local_optimize_without_backflow']) {
      $effectiveAllowLocalOptimizeWithoutBackflow = [bool]$entry.allow_local_optimize_without_backflow
    }
    if ($entry.PSObject.Properties['max_autonomous_iterations']) {
      $effectiveMaxAutonomousIterations = [int]$entry.max_autonomous_iterations
    }
    if ($entry.PSObject.Properties['max_repeated_failure_per_step']) {
      $effectiveMaxRepeatedFailurePerStep = [int]$entry.max_repeated_failure_per_step
    }
    if ($entry.PSObject.Properties['stop_on_irreversible_risk']) {
      $effectiveStopOnIrreversibleRisk = [bool]$entry.stop_on_irreversible_risk
    }
    if ($entry.PSObject.Properties['forbid_breaking_contract']) {
      $effectiveForbidBreakingContract = [bool]$entry.forbid_breaking_contract
    }
    if ($entry.PSObject.Properties['auto_commit_enabled']) {
      $effectiveAutoCommitEnabled = [bool]$entry.auto_commit_enabled
    }
    if ($entry.PSObject.Properties['auto_commit_on_checkpoints']) {
      $effectiveAutoCommitOnCheckpoints = @($entry.auto_commit_on_checkpoints)
    }
    if ($entry.PSObject.Properties['auto_commit_message_prefix']) {
      $effectiveAutoCommitMessagePrefix = [string]$entry.auto_commit_message_prefix
    }
  }

  return [pscustomobject]@{
    repo = $repoNorm
    allow_project_rules = [bool]$allowProjectRules
    allow_auto_fix = [bool]$effectiveAllowAutoFix
    allow_rule_optimization = [bool]$effectiveAllowRuleOptimization
    allow_local_optimize_without_backflow = [bool]$effectiveAllowLocalOptimizeWithoutBackflow
    max_autonomous_iterations = [int]$effectiveMaxAutonomousIterations
    max_repeated_failure_per_step = [int]$effectiveMaxRepeatedFailurePerStep
    stop_on_irreversible_risk = [bool]$effectiveStopOnIrreversibleRisk
    forbid_breaking_contract = [bool]$effectiveForbidBreakingContract
    auto_commit_enabled = [bool]$effectiveAutoCommitEnabled
    auto_commit_on_checkpoints = @($effectiveAutoCommitOnCheckpoints)
    auto_commit_message_prefix = [string]$effectiveAutoCommitMessagePrefix
  }
}

function Get-ProjectCustomFilesForRepo([string]$KitRoot, [string]$RepoPath, [string]$RepoName) {
  $configPath = Join-Path $KitRoot "config\project-custom-files.json"
  $cfg = Read-JsonFile -Path $configPath -DefaultValue $null -UseCache -DisplayName "project-custom-files.json"
  if ($null -eq $cfg) { return @() }

  $repoNorm = Normalize-Repo $RepoPath
  $repoLeaf = if ([string]::IsNullOrWhiteSpace($RepoName)) { Get-RepoName $RepoPath } else { $RepoName }

  $files = [System.Collections.Generic.List[string]]::new()

  if ($null -ne $cfg.default) {
    foreach ($f in @($cfg.default)) {
      if (-not [string]::IsNullOrWhiteSpace([string]$f)) {
        [void]$files.Add(([string]$f -replace '\\', '/').TrimStart('/'))
      }
    }
  }

  if ($null -ne $cfg.repos) {
    foreach ($entry in @($cfg.repos)) {
      if ($null -eq $entry) { continue }

      $match = $false
      if ($entry.PSObject.Properties['repo'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repo)) {
        $entryRepoNorm = Normalize-Repo ([string]$entry.repo)
        if ($entryRepoNorm.Equals($repoNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
          $match = $true
        }
      }
      if (-not $match -and $entry.PSObject.Properties['repoName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repoName)) {
        if (([string]$entry.repoName).Equals($repoLeaf, [System.StringComparison]::OrdinalIgnoreCase)) {
          $match = $true
        }
      }
      if (-not $match) { continue }

      foreach ($f in @($entry.files)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$f)) {
          [void]$files.Add(([string]$f -replace '\\', '/').TrimStart('/'))
        }
      }
    }
  }

  $codexRuntimeFiles = @(Get-CodexRuntimeFilesForRepo -KitRoot $KitRoot -RepoPath $RepoPath -RepoName $repoLeaf)
  foreach ($f in $codexRuntimeFiles) {
    if (-not [string]::IsNullOrWhiteSpace([string]$f)) {
      [void]$files.Add(([string]$f -replace '\\', '/').TrimStart('/'))
    }
  }

  $unique = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $ordered = [System.Collections.Generic.List[string]]::new()
  foreach ($f in $files) {
    if ($unique.Add($f)) {
      [void]$ordered.Add($f)
    }
  }

  return @($ordered)
}

function Get-CodexRuntimeFilesForRepo([string]$KitRoot, [string]$RepoPath, [string]$RepoName) {
  $policyPath = Join-Path $KitRoot "config\codex-runtime-policy.json"
  $policy = Read-JsonFile -Path $policyPath -DefaultValue $null -UseCache -DisplayName "codex-runtime-policy.json"

  if ($null -eq $policy) { return @() }

  $enabled = $false
  if ($null -ne $policy.PSObject.Properties['enabled_by_default']) {
    $enabled = [bool]$policy.enabled_by_default
  }

  $repoNorm = Normalize-Repo $RepoPath
  $repoLeaf = if ([string]::IsNullOrWhiteSpace($RepoName)) { Get-RepoName $RepoPath } else { [string]$RepoName }

  foreach ($entry in @($policy.repos)) {
    if ($null -eq $entry) { continue }

    $match = $false
    if ($entry.PSObject.Properties['repo'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repo)) {
      $entryRepoNorm = Normalize-Repo ([string]$entry.repo)
      if ($entryRepoNorm.Equals($repoNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
        $match = $true
      }
    }
    if (-not $match -and $entry.PSObject.Properties['repoName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repoName)) {
      if (([string]$entry.repoName).Equals($repoLeaf, [System.StringComparison]::OrdinalIgnoreCase)) {
        $match = $true
      }
    }
    if (-not $match) { continue }

    if ($entry.PSObject.Properties['enabled']) {
      $enabled = [bool]$entry.enabled
    }
  }

  if (-not $enabled) { return @() }
  if ($null -eq $policy.PSObject.Properties['default_files'] -or $null -eq $policy.default_files) { return @() }

  $files = [System.Collections.Generic.List[string]]::new()
  foreach ($f in @($policy.default_files)) {
    if (-not [string]::IsNullOrWhiteSpace([string]$f)) {
      [void]$files.Add(([string]$f -replace '\\', '/').TrimStart('/'))
    }
  }

  return @($files.ToArray())
}

function Get-ProjectCustomSourceForRepo([string]$KitRoot, [string]$RepoName, [string]$CustomRelativePath) {
  if ([string]::IsNullOrWhiteSpace($CustomRelativePath)) {
    return $null
  }

  $customRel = ([string]$CustomRelativePath -replace '\\', '/').TrimStart('/')
  $repoNameSafe = if ([string]::IsNullOrWhiteSpace($RepoName)) { "" } else { [string]$RepoName }

  $repoScopedRel = if ([string]::IsNullOrWhiteSpace($repoNameSafe)) { $null } else { "source/project/$repoNameSafe/custom/$customRel" }
  if (-not [string]::IsNullOrWhiteSpace($repoScopedRel)) {
    $repoScopedAbs = Join-Path $KitRoot ($repoScopedRel -replace '/', '\')
    if (Test-Path -LiteralPath $repoScopedAbs -PathType Leaf) {
      return $repoScopedRel
    }
  }

  $commonRel = "source/project/_common/custom/$customRel"
  $commonAbs = Join-Path $KitRoot ($commonRel -replace '/', '\')
  if (Test-Path -LiteralPath $commonAbs -PathType Leaf) {
    return $commonRel
  }

  return $null
}

function Parse-KeyValueFile([string]$Path) {
  $map = @{}
  foreach ($line in (Get-Content -Path $Path)) {
    if ($line -match '^\s*([^=]+)=(.*)$') {
      $key = $matches[1].Trim()
      $value = $matches[2].Trim()
      $map[$key] = $value
    }
  }
  return $map
}

function Parse-IsoDate([string]$Text) {
  if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
  try {
    return [datetime]::ParseExact(
      $Text,
      "yyyy-MM-dd",
      [System.Globalization.CultureInfo]::InvariantCulture,
      [System.Globalization.DateTimeStyles]::None
    )
  } catch {
    return $null
  }
}

function Get-ReleaseDistributionPolicy {
  param(
    [Parameter(Mandatory = $true)]
    [string]$KitRoot
  )

  $path = Join-Path $KitRoot "config\release-distribution-policy.json"
  return Read-JsonFile -Path $path -DefaultValue $null -UseCache -DisplayName "release-distribution-policy.json"
}

function Get-ReleaseDistributionPolicyForRepo {
  param(
    [object]$Policy,
    [Parameter(Mandatory = $true)]
    [string]$RepoName,
    [switch]$FallbackToDefault
  )

  if ($null -eq $Policy) { return $null }

  if ($null -ne $Policy.PSObject.Properties['repos'] -and $null -ne $Policy.repos) {
    $repoEntry = @($Policy.repos | Where-Object {
      $_ -ne $null -and
      $_.PSObject.Properties['repoName'] -and
      ([string]$_.repoName).Equals($RepoName, [System.StringComparison]::OrdinalIgnoreCase)
    } | Select-Object -First 1)[0]
    if ($null -ne $repoEntry) { return $repoEntry }
  }

  if ($FallbackToDefault -and $null -ne $Policy.PSObject.Properties['default']) {
    return $Policy.default
  }

  return $null
}

function Resolve-EffectiveClarificationScenario {
  param(
    [string]$RequestedScenario = "auto",
    [string]$ContextFile = "",
    [string]$CurrentMode = ""
  )

  $validScenarios = @("plan", "requirement", "bugfix", "acceptance")

  if ($RequestedScenario -ne "auto" -and -not [string]::IsNullOrWhiteSpace($RequestedScenario) -and $validScenarios -contains $RequestedScenario) {
    return [pscustomobject]@{
      scenario = $RequestedScenario
      source = "param"
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($ContextFile) -and (Test-Path -LiteralPath $ContextFile)) {
    try {
      $ctx = Read-JsonFile -Path $ContextFile -DisplayName "clarification context"
      $ctxScenario = ""
      if ($null -ne $ctx.PSObject.Properties['clarification_scenario']) {
        $ctxScenario = [string]$ctx.clarification_scenario
      } elseif ($null -ne $ctx.PSObject.Properties['scenario']) {
        $ctxScenario = [string]$ctx.scenario
      }
      if ($validScenarios -contains $ctxScenario) {
        return [pscustomobject]@{
          scenario = $ctxScenario
          source = "context_file"
        }
      }
    } catch {
      Write-Host ("[WARN] clarification context parse failed: {0}" -f $ContextFile)
    }
  }

  if ($CurrentMode -eq "plan") {
    return [pscustomobject]@{
      scenario = "plan"
      source = "mode"
    }
  }

  return [pscustomobject]@{
    scenario = "bugfix"
    source = "fallback"
  }
}

function Invoke-ClarificationTracker {
  param(
    [Parameter(Mandatory = $true)][string]$TrackerScript,
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [Parameter(Mandatory = $true)][string]$IssueId,
    [Parameter(Mandatory = $true)][string]$Scenario,
    [Parameter(Mandatory = $true)][string]$Mode,
    [string]$Outcome = "",
    [string]$Reason = "",
    [string]$PowerShellPath = ""
  )

  if ([string]::IsNullOrWhiteSpace($PowerShellPath)) {
    $PowerShellPath = Get-CurrentPowerShellPath
  }
  if (-not (Test-Path -LiteralPath $TrackerScript -PathType Leaf)) {
    throw "clarification tracker script not found: $TrackerScript"
  }
  if (-not (Get-Command -Name $PowerShellPath -ErrorAction SilentlyContinue)) {
    throw "PowerShell command not found: $PowerShellPath"
  }

  $args = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $TrackerScript,
    "-RepoPath", $RepoPath,
    "-IssueId", $IssueId,
    "-Scenario", $Scenario,
    "-Mode", $Mode
  )
  if (-not [string]::IsNullOrWhiteSpace($Outcome)) {
    $args += @("-Outcome", $Outcome)
  }
  if (-not [string]::IsNullOrWhiteSpace($Reason)) {
    $args += @("-Reason", $Reason)
  }

  $json = & $PowerShellPath @args
  if ($LASTEXITCODE -ne 0) {
    throw "clarification tracker failed with exit code $LASTEXITCODE"
  }
  $jsonText = [string]::Join([Environment]::NewLine, @($json))
  if ([string]::IsNullOrWhiteSpace($jsonText)) {
    throw "clarification tracker returned empty output"
  }

  try {
    return $jsonText | ConvertFrom-Json
  } catch {
    throw "clarification tracker returned invalid JSON"
  }
}

function Get-RuleDocMetadata([string]$Path) {
  if (!(Test-Path $Path)) {
    return [pscustomobject]@{
      version = $null
      last_update = $null
    }
  }

  $text = Get-Content -Path $Path -Raw
  # Match markdown metadata lines like: **版本**: 9.31 or **Version**: 9.31
  $versionMatch = [regex]::Match($text, "(?m)^\*\*.+?\*+:\s*([0-9]+\.[0-9]+)\s*$")
  # Match markdown metadata lines like: **最后更新**: 2026-03-30
  $dateMatch = [regex]::Match($text, "(?m)^\*\*.+?\*+:\s*([0-9]{4}-[0-9]{2}-[0-9]{2})\s*$")

  return [pscustomobject]@{
    version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { $null }
    last_update = if ($dateMatch.Success) { $dateMatch.Groups[1].Value } else { $null }
  }
}

function New-ScriptLock([string]$KitRoot, [string]$LockName, [int]$TimeoutSeconds = 120) {
  if ([string]::IsNullOrWhiteSpace($KitRoot)) {
    throw "KitRoot is required for New-ScriptLock."
  }
  if ([string]::IsNullOrWhiteSpace($LockName)) {
    throw "LockName is required for New-ScriptLock."
  }
  if ($TimeoutSeconds -lt 1) {
    throw "TimeoutSeconds must be >= 1."
  }

  $lockDir = Join-Path $KitRoot ".locks"
  if (!(Test-Path -LiteralPath $lockDir)) {
    New-Item -ItemType Directory -Path $lockDir -Force | Out-Null
  }

  $lockPath = Join-Path $lockDir ($LockName + ".lock")
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    try {
      $stream = [System.IO.File]::Open(
        $lockPath,
        [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
      )
      $meta = "pid=$PID`nacquired_at=$((Get-Date).ToString('o'))`n"
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($meta)
      $stream.SetLength(0)
      $stream.Write($bytes, 0, $bytes.Length)
      $stream.Flush()
      return [pscustomobject]@{
        name = $LockName
        path = $lockPath
        stream = $stream
      }
    } catch [System.IO.IOException] {
      Start-Sleep -Milliseconds 200
    }
  } while ((Get-Date) -lt $deadline)

  throw "Failed to acquire script lock '$LockName' within ${TimeoutSeconds}s: $lockPath"
}

function Release-ScriptLock([object]$LockHandle) {
  if ($null -eq $LockHandle) { return }
  if ($LockHandle.PSObject.Properties['stream'] -and $null -ne $LockHandle.stream) {
    try {
      $LockHandle.stream.Dispose()
    } catch {
    }
  }
}

function Get-ModeRisk([string]$Mode) {
  switch ($Mode) {
    "plan"  { return "LOW(read-only)" }
    "safe"  { return "MEDIUM(controlled-write)" }
    "force" { return "HIGH(override-write)" }
    default { return "UNKNOWN" }
  }
}

function Write-ModeRisk([string]$ScriptName, [string]$Mode) {
  $risk = Get-ModeRisk $Mode
  Write-Host "[MODE] $ScriptName mode=$Mode risk=$risk"
}

function Get-CurrentPowerShellPath() {
  $exe = (Get-Process -Id $PID -ErrorAction SilentlyContinue).Path
  if ([string]::IsNullOrWhiteSpace($exe)) {
    return "powershell"
  }
  return $exe
}

function Invoke-ChildScript([string]$ScriptPath, [string[]]$ScriptArgs = @()) {
  $psExe = Get-CurrentPowerShellPath
  & $psExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ScriptArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Script failed with exit code ${LASTEXITCODE}: $ScriptPath"
  }
}

function Invoke-ChildScriptCapture([string]$ScriptPath, [string[]]$ScriptArgs = @()) {
  $psExe = Get-CurrentPowerShellPath
  $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ScriptArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Script failed with exit code ${LASTEXITCODE}: $ScriptPath"
  }
  return $out
}
