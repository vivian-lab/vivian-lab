<#
.SYNOPSIS
  Module 2 - Prerequisite Checker. Read-only readiness report (Red/Amber/Green).
.NOTES
  Runs with the read-only identity only. Makes no changes to the tenant.
  Confirm cmdlets and scopes against current Microsoft Learn docs before use.
#>
param(
  [Parameter(Mandatory)] [string] $TargetGroupName,
  [string] $NamingPrefix = 'EP-'
)

Connect-MgGraph -Scopes 'DeviceManagementConfiguration.Read.All',
                        'DeviceManagementServiceConfig.Read.All',
                        'Group.Read.All' -NoWelcome

$results = [System.Collections.Generic.List[object]]::new()
function Add-Check($Name, $Result, $Rag) {
  $results.Add([pscustomobject]@{ Check = $Name; Result = $Result; RAG = $Rag })
}

# Enrolment configuration readable (proxy for Intune being set up)
try {
  $enrol = Get-MgDeviceManagementDeviceEnrollmentConfiguration -ErrorAction Stop
  Add-Check 'Enrolment configuration readable' "$($enrol.Count) configs" 'GREEN'
} catch {
  Add-Check 'Enrolment configuration readable' 'Failed' 'RED'
}

# Target group exists
$group = Get-MgGroup -Filter "displayName eq '$TargetGroupName'"
if ($group) { Add-Check "Target group $TargetGroupName" 'Found' 'GREEN' }
else        { Add-Check "Target group $TargetGroupName" 'Missing' 'AMBER' }

# Naming standard
if ($TargetGroupName.StartsWith($NamingPrefix)) { Add-Check 'Naming standard' 'Matches' 'GREEN' }
else                                            { Add-Check 'Naming standard' 'Does not match' 'AMBER' }

# Existing policies (informational)
$cp = Get-MgDeviceManagementDeviceCompliancePolicy
Add-Check 'Existing compliance policies' "$($cp.Count)" 'GREEN'

$ap = Get-MgDeviceManagementWindowsAutopilotDeviceIdentity
Add-Check 'Existing Autopilot devices' "$($ap.Count)" 'GREEN'

$overall = if ($results.RAG -contains 'RED') { 'RED' }
           elseif ($results.RAG -contains 'AMBER') { 'AMBER' }
           else { 'GREEN' }

$results | Format-Table -AutoSize
"Overall readiness: $overall"
