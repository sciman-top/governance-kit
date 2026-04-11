param(
  [string]$RepoRoot = ".",
  [ValidateSet("recurring", "monthly-review")]
  [string]$TaskType = "recurring",
  [string]$TaskName = "",
  [ValidateSet("Daily", "Weekly", "Monthly")]
  [string]$Cadence = "Weekly",
  [string]$At = "09:30",
  [ValidateSet("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")]
  [string]$DayOfWeek = "Monday",
  [ValidateRange(1, 28)]
  [int]$DayOfMonth = 1,
  [switch]$Force,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoPath = (Resolve-Path -LiteralPath $RepoRoot).Path
$reviewScript = ""
if ($TaskType -eq "monthly-review") {
  $reviewScript = Join-Path $repoPath "scripts\governance\run-monthly-policy-review.ps1"
  if (-not $PSBoundParameters.ContainsKey("Cadence")) {
    $Cadence = "Monthly"
  }
  if ([string]::IsNullOrWhiteSpace($TaskName)) {
    $TaskName = "repo-governance-hub-monthly-policy-review"
  }
} else {
  $reviewScript = Join-Path $repoPath "scripts\governance\run-recurring-review.ps1"
  if ([string]::IsNullOrWhiteSpace($TaskName)) {
    $TaskName = "repo-governance-hub-recurring-review"
  }
}
if (-not (Test-Path -LiteralPath $reviewScript -PathType Leaf)) {
  throw "Review script not found: $reviewScript"
}

if (-not (Get-Command -Name Register-ScheduledTask -ErrorAction SilentlyContinue)) {
  throw "Register-ScheduledTask is not available on this machine."
}

$timeValue = $null
try {
  $timeValue = [DateTime]::ParseExact($At, "HH:mm", [System.Globalization.CultureInfo]::InvariantCulture)
} catch {
  throw "Invalid -At value: $At (expected HH:mm, e.g. 09:30)"
}

$triggerAt = Get-Date -Hour $timeValue.Hour -Minute $timeValue.Minute -Second 0
$today = (Get-Date).Date
if ($triggerAt -lt (Get-Date)) {
  $triggerAt = $triggerAt.AddDays(1)
}

$psArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$reviewScript`" -RepoRoot `"$repoPath`""
$action = $null
$trigger = $null
$settings = $null
$useSchtasksMonthly = $Cadence -eq "Monthly"
if (-not $useSchtasksMonthly) {
  $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $psArgs -WorkingDirectory $repoPath
  switch ($Cadence) {
    "Daily" {
      $trigger = New-ScheduledTaskTrigger -Daily -At $triggerAt
    }
    "Weekly" {
      $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $triggerAt
    }
    default {
      throw "Unsupported cadence: $Cadence"
    }
  }
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
}
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($DryRun.IsPresent) {
  Write-Host "REGISTER_REVIEW_TASK_DRYRUN"
  Write-Host ("task_name={0}" -f $TaskName)
  Write-Host ("task_type={0}" -f $TaskType)
  Write-Host ("repo_root={0}" -f ($repoPath -replace '\\', '/'))
  Write-Host ("cadence={0}" -f $Cadence)
  if ($Cadence -eq "Weekly") {
    Write-Host ("day_of_week={0}" -f $DayOfWeek)
  }
  if ($Cadence -eq "Monthly") {
    Write-Host ("day_of_month={0}" -f $DayOfMonth)
  }
  Write-Host ("at={0}" -f $At)
  Write-Host ("task_exists={0}" -f ($null -ne $existing))
  if ($useSchtasksMonthly) {
    $taskRunPreview = "powershell.exe $psArgs"
    Write-Host ("command=schtasks /Create /TN `"{0}`" /TR `"{1}`" /SC MONTHLY /D {2} /ST {3}" -f $TaskName, $taskRunPreview, $DayOfMonth, $At)
  } else {
    Write-Host ("command=powershell.exe {0}" -f $psArgs)
  }
  exit 0
}

if ($null -ne $existing -and -not $Force.IsPresent) {
  throw "Task already exists: $TaskName (use -Force to replace)"
}

if ($useSchtasksMonthly) {
  if (-not (Get-Command -Name schtasks -ErrorAction SilentlyContinue)) {
    throw "schtasks command is not available on this machine."
  }
  $taskRun = "powershell.exe $psArgs"
  $args = @("/Create", "/TN", $TaskName, "/TR", $taskRun, "/SC", "MONTHLY", "/D", "$DayOfMonth", "/ST", $At)
  if ($Force.IsPresent) {
    $args += "/F"
  }
  & schtasks @args | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "schtasks create failed with exit code $LASTEXITCODE"
  }
} else {
  if ($null -ne $existing -and $Force.IsPresent) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  }
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description "Run repo-governance-hub recurring review and reminders"
}

Write-Host "REGISTER_REVIEW_TASK_DONE"
Write-Host ("task_name={0}" -f $TaskName)
Write-Host ("cadence={0}" -f $Cadence)
Write-Host ("at={0}" -f $At)

