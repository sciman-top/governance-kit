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

  return $null
}

function Get-ProjectRulePolicyPath([string]$KitRoot) {
  return Join-Path $KitRoot "config\project-rule-policy.json"
}

function Read-ProjectRuleAllowRepos([string]$KitRoot) {
  $path = Get-ProjectRulePolicyPath $KitRoot
  if (!(Test-Path $path)) { return @() }

  try {
    $policy = Get-Content -Path $path -Raw | ConvertFrom-Json
  } catch {
    throw "project-rule-policy.json invalid JSON: $path"
  }

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
