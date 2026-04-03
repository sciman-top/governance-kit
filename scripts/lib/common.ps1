$ErrorActionPreference = "Stop"

function Read-JsonArray([string]$Path) {
  if (!(Test-Path $Path)) { return @() }
  $raw = Get-Content -Path $Path -Raw | ConvertFrom-Json
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

  if (!(Test-Path $path)) {
    return $defaultPolicy
  }

  try {
    $policy = Get-Content -Path $path -Raw | ConvertFrom-Json
  } catch {
    throw "project-rule-policy.json invalid JSON: $path"
  }

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
  $allowRepos = Read-ProjectRuleAllowRepos $KitRoot
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
  if (!(Test-Path $configPath)) { return @() }

  try {
    $cfg = Get-Content -Path $configPath -Raw | ConvertFrom-Json
  } catch {
    throw "project-custom-files.json invalid JSON: $configPath"
  }

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

  $unique = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $ordered = [System.Collections.Generic.List[string]]::new()
  foreach ($f in $files) {
    if ($unique.Add($f)) {
      [void]$ordered.Add($f)
    }
  }

  return @($ordered)
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
