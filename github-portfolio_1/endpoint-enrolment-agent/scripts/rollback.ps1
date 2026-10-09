<#
.SYNOPSIS
  Module 8 - Rollback. Reverses logged objects in safe order.
.NOTES
  Rollback is a write action and requires approval (except pre-approved emergency rollback).
  Input: an array of log records (see templates/log-record.sample.json).
  Order: apps -> config/compliance -> hashes -> Autopilot profile -> bootstrap.
#>
param(
  [Parameter(Mandatory)] [string] $LogPath
)

$order = @(
  'mobileApp',
  'deviceConfiguration', 'deviceCompliancePolicy',
  'windowsAutopilotDeviceIdentity',
  'windowsAutopilotDeploymentProfile',
  'deviceCategory'
)

$records = Get-Content $LogPath -Raw | ConvertFrom-Json |
           Where-Object { $_.action -eq 'create' -and $_.status -eq 'success' }

foreach ($type in $order) {
  foreach ($r in $records | Where-Object objectType -eq $type) {
    Write-Host "Rolling back $type $($r.objectId) ($($r.requestId))"
    switch ($type) {
      'mobileApp'                         { Remove-MgDeviceAppManagementMobileApp -MobileAppId $r.objectId }
      'deviceConfiguration'               { Remove-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $r.objectId }
      'deviceCompliancePolicy'            { Remove-MgDeviceManagementDeviceCompliancePolicy -DeviceCompliancePolicyId $r.objectId }
      'windowsAutopilotDeviceIdentity'    { Remove-MgDeviceManagementWindowsAutopilotDeviceIdentity -WindowsAutopilotDeviceIdentityId $r.objectId }
      'windowsAutopilotDeploymentProfile' { Remove-MgDeviceManagementWindowsAutopilotDeploymentProfile -WindowsAutopilotDeploymentProfileId $r.objectId }
      'deviceCategory'                    { Remove-MgDeviceManagementDeviceCategory -DeviceCategoryId $r.objectId }
    }
  }
}
