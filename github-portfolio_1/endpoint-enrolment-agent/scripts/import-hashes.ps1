<#
.SYNOPSIS
  Module 5 - Hardware Hash Importer. Validates CSV, skips duplicates, imports, reports.
.NOTES
  Write action: run only with the write identity AFTER recorded approval.
  Import a single test device first before any bulk import.
#>
param(
  [Parameter(Mandatory)] [string] $CsvPath
)

$required = 'Device Serial Number', 'Windows Product ID', 'Hardware Hash'
$rows = Import-Csv $CsvPath

# 1. Validate structure
$missing = $required | Where-Object { $_ -notin $rows[0].PSObject.Properties.Name }
if ($missing) { throw "CSV missing columns: $($missing -join ', ')" }

# 2. Existing serials for duplicate detection
$existing = Get-MgDeviceManagementWindowsAutopilotDeviceIdentity |
            Select-Object -ExpandProperty SerialNumber

$report = foreach ($r in $rows) {
  $serial = $r.'Device Serial Number'
  if ([string]::IsNullOrWhiteSpace($serial) -or [string]::IsNullOrWhiteSpace($r.'Hardware Hash')) {
    [pscustomobject]@{ Serial = $serial; Status = 'Failed'; Reason = 'Blank field' }
    continue
  }
  if ($existing -contains $serial) {
    [pscustomobject]@{ Serial = $serial; Status = 'Skipped'; Reason = 'Duplicate' }
    continue
  }
  try {
    $null = New-MgDeviceManagementImportedWindowsAutopilotDeviceIdentity `
      -SerialNumber $serial -HardwareIdentifier $r.'Hardware Hash' -ErrorAction Stop
    [pscustomobject]@{ Serial = $serial; Status = 'Imported'; Reason = '' }
  } catch {
    [pscustomobject]@{ Serial = $serial; Status = 'Failed'; Reason = $_.Exception.Message }
  }
}

$report | Format-Table -AutoSize
$report | Group-Object Status | Select-Object Name, Count
