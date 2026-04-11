param(
  [string]$GovernanceKitRoot = ".",
  [switch]$Diagnostics,
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-NormalizedPath([string]$PathText) {
  $resolved = Resolve-Path -LiteralPath $PathText -ErrorAction Stop
  return ([System.IO.Path]::GetFullPath($resolved.Path) -replace '\\', '/').TrimEnd('/')
}

function Ensure-ParentDirectory([string]$PathText) {
  $parent = Split-Path -Parent $PathText
  if ([string]::IsNullOrWhiteSpace($parent)) { return }
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
}

function ConvertTo-Slug([string]$Text) {
  if ([string]::IsNullOrWhiteSpace($Text)) { return "candidate" }
  $slug = ($Text.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
  if ([string]::IsNullOrWhiteSpace($slug)) { return "candidate" }
  if ($slug.Length -gt 24) { $slug = $slug.Substring(0, 24).Trim('-') }
  if ([string]::IsNullOrWhiteSpace($slug)) { return "candidate" }
  return $slug
}

function New-UnicodeString([int[]]$CodePoints) {
  if ($null -eq $CodePoints -or $CodePoints.Count -eq 0) { return "" }
  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function Get-SignatureHash8([string]$Text) {
  $input = if ($null -eq $Text) { "" } else { $Text.ToLowerInvariant().Trim() }
  if ([string]::IsNullOrWhiteSpace($input)) { return "00000000" }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($input)
    $hashBytes = $sha.ComputeHash($bytes)
    $hex = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLowerInvariant()
    return $hex.Substring(0, 8)
  } finally {
    $sha.Dispose()
  }
}

function New-DefaultPolicy {
  return [pscustomobject]@{
    schema_version = "1.0"
    enabled = $true
    threshold_count = 3
    window_days = 14
    cooldown_days = 14
    max_promotions_per_run = 3
    event_relative_path = ".governance/skill-candidates/events.jsonl"
    registry_relative_path = ".governance/skill-candidates/promotion-registry.json"
    skills_root = "E:/CODE/skills-manager"
    overrides_relative_path = "overrides"
    auto_run_skills_manager_gates = $true
  }
}

function Merge-Policy([psobject]$Base, [psobject]$Candidate) {
  if ($null -eq $Candidate) { return $Base }
  foreach ($prop in $Candidate.PSObject.Properties) {
    if ($null -eq $prop.Value) { continue }
    if ($Base.PSObject.Properties[$prop.Name]) {
      $Base.$($prop.Name) = $prop.Value
    } else {
      $Base | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
    }
  }
  return $Base
}

function Load-JsonObject([string]$PathText) {
  if (-not (Test-Path -LiteralPath $PathText -PathType Leaf)) { return $null }
  return (Get-Content -LiteralPath $PathText -Raw | ConvertFrom-Json)
}

function Load-Registry([string]$PathText) {
  $obj = Load-JsonObject $PathText
  if ($null -eq $obj) {
    return [pscustomobject]@{
      schema_version = "1.0"
      promoted = @()
    }
  }
  if ($null -eq $obj.PSObject.Properties['promoted']) {
    $obj | Add-Member -NotePropertyName promoted -NotePropertyValue @()
  }
  return $obj
}

function Normalize-RepoList([object]$Parsed) {
  if ($null -eq $Parsed) { return @() }
  $list = @($Parsed)
  if ($list.Count -eq 1) {
    $single = $list[0]
    $valueProp = $single.PSObject.Properties['value']
    if ($null -ne $valueProp) {
      $candidate = @($valueProp.Value)
      if ($candidate.Count -gt 0) {
        return $candidate
      }
    }
  }
  return $list
}

function Save-Registry([string]$PathText, [psobject]$Registry) {
  Ensure-ParentDirectory $PathText
  $Registry | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $PathText -Encoding utf8
}

function Read-EventLines([string]$PathText) {
  if (-not (Test-Path -LiteralPath $PathText -PathType Leaf)) { return @() }
  $items = New-Object System.Collections.Generic.List[object]
  foreach ($line in @(Get-Content -LiteralPath $PathText -Encoding utf8)) {
    $text = [string]$line
    if ([string]::IsNullOrWhiteSpace($text)) { continue }
    try {
      $items.Add(($text | ConvertFrom-Json)) | Out-Null
    } catch {
      if ($Diagnostics) {
        Write-Warning ("skill_promotion.parse_error file={0} line={1}" -f ($PathText -replace '\\', '/'), $text.Substring(0, [Math]::Min(120, $text.Length)))
      }
    }
  }
  return @($items.ToArray())
}

function Get-PromotedLookup([psobject]$Registry) {
  $lookup = @{}
  foreach ($item in @($Registry.promoted)) {
    if ($null -eq $item) { continue }
    $signature = [string]$item.issue_signature
    if ([string]::IsNullOrWhiteSpace($signature)) { continue }
    $lookup[$signature.ToLowerInvariant()] = $item
  }
  return $lookup
}

function Build-SkillContent([string]$SkillName, [string]$Signature, [int]$Count, [string[]]$Repos) {
  $repoText = if ($Repos.Count -gt 0) { ($Repos -join ", ") } else { "unknown-repo" }
  @(
    "---",
    ("name: {0}" -f $SkillName),
    ("description: Auto-promoted from repeated issue signature '{0}' (hits={1})." -f $Signature, $Count),
    "---",
    "",
    "1. Reproduce the issue using the latest command/log context in the current repository.",
    "2. Apply the proven fix pattern associated with this signature before adding new abstractions.",
    "3. Verify with repository gates in fixed order: build -> test -> contract/invariant -> hotspot.",
    "4. If the same signature reappears, update this skill and evidence records instead of creating a duplicate skill.",
    "",
    ("source_repos: {0}" -f $repoText)
  ) -join "`n"
}

function Invoke-SkillsManagerGates([string]$SkillsRoot) {
  $skillsScript = Join-Path ($SkillsRoot -replace '/', '\') "skills.ps1"
  if (-not (Test-Path -LiteralPath $skillsScript -PathType Leaf)) {
    throw "skills.ps1 not found: $skillsScript"
  }
  $psExe = "powershell"
  $pwshCmd = Get-Command -Name "pwsh" -ErrorAction SilentlyContinue
  if ($null -ne $pwshCmd) { $psExe = $pwshCmd.Source }

  $cmdDiscover = New-UnicodeString @(0x53D1, 0x73B0) # 发现
  $cmdBuildApply = New-UnicodeString @(0x6784, 0x5EFA, 0x751F, 0x6548) # 构建生效

  Push-Location -LiteralPath ($SkillsRoot -replace '/', '\')
  try {
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $skillsScript "doctor" "--strict"
    if ($LASTEXITCODE -ne 0) { throw "skills.ps1 doctor --strict failed (exit=$LASTEXITCODE)" }
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $skillsScript $cmdBuildApply
    if ($LASTEXITCODE -ne 0) { throw "skills.ps1 build/apply failed (exit=$LASTEXITCODE)" }
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $skillsScript $cmdDiscover | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "skills.ps1 discover failed (exit=$LASTEXITCODE)" }
  } finally {
    Pop-Location
  }
}

$kitRoot = Resolve-NormalizedPath $GovernanceKitRoot
$policyPath = Join-Path ($kitRoot -replace '/', '\') ".governance\skill-promotion-policy.json"
$policyTemplatePath = Join-Path ($kitRoot -replace '/', '\') "source\project\_common\custom\.governance\skill-promotion-policy.json"

$policy = New-DefaultPolicy
$policy = Merge-Policy -Base $policy -Candidate (Load-JsonObject $policyTemplatePath)
$policy = Merge-Policy -Base $policy -Candidate (Load-JsonObject $policyPath)

if (-not [bool]$policy.enabled) {
  $disabled = [pscustomobject]@{
    schema_version = "1.0"
    status = "disabled"
    policy_path = ($policyPath -replace '\\', '/')
    promoted_count = 0
    promoted = @()
  }
  if ($AsJson) { $disabled | ConvertTo-Json -Depth 8 | Write-Output } else { Write-Host "skill_promotion.status=disabled" }
  exit 0
}

$reposPath = Join-Path ($kitRoot -replace '/', '\') "config\repositories.json"
if (-not (Test-Path -LiteralPath $reposPath -PathType Leaf)) {
  throw "repositories.json not found: $reposPath"
}
$repos = Normalize-RepoList (Get-Content -LiteralPath $reposPath -Raw | ConvertFrom-Json)
if ($Diagnostics) {
  Write-Host ("skill_promotion.repos_count={0}" -f $repos.Count)
  Write-Host ("skill_promotion.repos_type={0}" -f $repos.GetType().FullName)
  Write-Host ("skill_promotion.repos_preview={0}" -f (($repos | ConvertTo-Json -Depth 4 -Compress)))
}

$registryPath = Join-Path ($kitRoot -replace '/', '\') (($policy.registry_relative_path -replace '/', '\'))
$registry = Load-Registry $registryPath
$promotedLookup = Get-PromotedLookup $registry

$now = Get-Date
$windowStart = $now.AddDays(-1 * [int]$policy.window_days)
$cooldownDays = [int]$policy.cooldown_days
$maxPromotions = [Math]::Max(1, [int]$policy.max_promotions_per_run)
$threshold = [Math]::Max(1, [int]$policy.threshold_count)

$groupMap = @{}
$eventCount = 0
foreach ($repoEntry in @($repos)) {
  $repoText = [string]$repoEntry
  if ([string]::IsNullOrWhiteSpace($repoText)) { continue }
  if (-not (Test-Path -LiteralPath ($repoText -replace '/', '\') -PathType Container)) { continue }
  $eventPath = Join-Path (($repoText -replace '/', '\')) (($policy.event_relative_path -replace '/', '\'))
  if ($Diagnostics) {
    Write-Host ("skill_promotion.scan repo={0} event_path={1} exists={2}" -f ($repoText -replace '\\', '/'), ($eventPath -replace '\\', '/'), (Test-Path -LiteralPath $eventPath -PathType Leaf))
  }
  foreach ($event in @(Read-EventLines $eventPath)) {
    if ($null -eq $event) { continue }
    $signature = [string]$event.issue_signature
    if ([string]::IsNullOrWhiteSpace($signature)) { continue }
    $eventTime = $null
    try { $eventTime = [datetime]$event.timestamp } catch { $eventTime = $null }
    if ($null -eq $eventTime -or $eventTime -lt $windowStart) { continue }
    $eventCount++

    $key = $signature.Trim().ToLowerInvariant()
    if (-not $groupMap.ContainsKey($key)) {
      $groupMap[$key] = [pscustomobject]@{
        issue_signature = $key
        count = 0
        repos = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
        latest_event = $eventTime
      }
    }
    $bucket = $groupMap[$key]
    $bucket.count = [int]$bucket.count + 1
    $bucket.repos.Add(($repoText -replace '\\', '/')) | Out-Null
    if ($eventTime -gt [datetime]$bucket.latest_event) {
      $bucket.latest_event = $eventTime
    }
  }
}

if ($Diagnostics) {
  Write-Host ("skill_promotion.scanned_event_count={0}" -f $eventCount)
}

$eligible = New-Object System.Collections.Generic.List[object]
foreach ($key in $groupMap.Keys) {
  $item = $groupMap[$key]
  if ([int]$item.count -lt $threshold) { continue }

  if ($promotedLookup.ContainsKey($key)) {
    $lastPromoted = $null
    try { $lastPromoted = [datetime]$promotedLookup[$key].promoted_at } catch { $lastPromoted = $null }
    if ($null -ne $lastPromoted -and $cooldownDays -gt 0 -and $lastPromoted -gt $now.AddDays(-1 * $cooldownDays)) {
      continue
    }
  }
  $eligible.Add($item) | Out-Null
}

$selected = @($eligible | Sort-Object -Property @{Expression="count";Descending=$true}, @{Expression="latest_event";Descending=$true} | Select-Object -First $maxPromotions)

$skillsRoot = Resolve-NormalizedPath $policy.skills_root
$overridesRoot = Join-Path ($skillsRoot -replace '/', '\') (($policy.overrides_relative_path -replace '/', '\'))
if (-not (Test-Path -LiteralPath $overridesRoot -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $overridesRoot | Out-Null
}

$promotedItems = New-Object System.Collections.Generic.List[object]
foreach ($item in @($selected)) {
  $signature = [string]$item.issue_signature
  $slug = ConvertTo-Slug $signature
  $hash8 = Get-SignatureHash8 $signature
  $skillName = "custom-auto-$slug-$hash8"
  $skillDir = Join-Path $overridesRoot $skillName
  $skillFile = Join-Path $skillDir "SKILL.md"
  if (-not (Test-Path -LiteralPath $skillDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
  }
  $reposUsed = @($item.repos | Sort-Object)
  $skillContent = Build-SkillContent -SkillName $skillName -Signature $signature -Count ([int]$item.count) -Repos $reposUsed
  Set-Content -LiteralPath $skillFile -Encoding utf8 -Value $skillContent

  $registryRecord = [pscustomobject]@{
    issue_signature = $signature
    skill_name = $skillName
    promoted_at = $now.ToString("o")
    hit_count = [int]$item.count
    repos = $reposUsed
  }

  $existing = @($registry.promoted | Where-Object { ([string]$_.issue_signature).ToLowerInvariant() -eq $signature })
  if ($existing.Count -gt 0) {
    foreach ($entry in $existing) {
      $entry.skill_name = $registryRecord.skill_name
      $entry.promoted_at = $registryRecord.promoted_at
      $entry.hit_count = $registryRecord.hit_count
      $entry.repos = $registryRecord.repos
    }
  } else {
    $registry.promoted += $registryRecord
  }

  $promotedItems.Add($registryRecord) | Out-Null
}

Save-Registry -PathText $registryPath -Registry $registry

$gatesRan = $false
if ($promotedItems.Count -gt 0 -and [bool]$policy.auto_run_skills_manager_gates) {
  Invoke-SkillsManagerGates -SkillsRoot $skillsRoot
  $gatesRan = $true
}

$eventWindowStartText = ""
try {
  $eventWindowStartText = ([datetime]$windowStart).ToString("o")
} catch {
  $eventWindowStartText = [string]$windowStart
}
$promotedArray = @($promotedItems | ForEach-Object { $_ })

$result = [ordered]@{
  schema_version = "1.0"
  status = "ok"
  policy_path = ($policyPath -replace '\\', '/')
  event_window_start = $eventWindowStartText
  threshold_count = [int]$threshold
  scanned_event_count = [int]$eventCount
  grouped_signature_count = [int]$groupMap.Count
  eligible_signature_count = [int]$eligible.Count
  selected_signature_count = [int]$selected.Count
  promoted_count = [int]$promotedItems.Count
  gates_ran = [bool]$gatesRan
  skills_root = [string]$skillsRoot
  overrides_root = ($overridesRoot -replace '\\', '/')
  promoted = $promotedArray
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 10 | Write-Output
} else {
  Write-Host ("skill_promotion.promoted_count={0}" -f $promotedItems.Count)
  Write-Host ("skill_promotion.gates_ran={0}" -f $gatesRan)
  foreach ($p in @($promotedItems)) {
    Write-Host ("[PROMOTED] signature={0} skill={1} hit_count={2}" -f $p.issue_signature, $p.skill_name, $p.hit_count)
  }
}
