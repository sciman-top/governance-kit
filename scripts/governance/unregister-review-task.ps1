param(
  [string]$TaskName = "governance-kit-recurring-review",
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command -Name Unregister-ScheduledTask -ErrorAction SilentlyContinue)) {
  throw "Unregister-ScheduledTask is not available on this machine."
}

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -eq $existing) {
  Write-Host "UNREGISTER_REVIEW_TASK_SKIP"
  Write-Host ("task_name={0}" -f $TaskName)
  Write-Host "reason=task_not_found"
  exit 0
}

if ($DryRun.IsPresent) {
  Write-Host "UNREGISTER_REVIEW_TASK_DRYRUN"
  Write-Host ("task_name={0}" -f $TaskName)
  exit 0
}

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false

Write-Host "UNREGISTER_REVIEW_TASK_DONE"
Write-Host ("task_name={0}" -f $TaskName)
