#Requires -Version 5.1
<#
.SYNOPSIS
    Pre-provisions OneDrive sites for every user in a CSV file.
.EXAMPLE
    ./Start-OneDrivePreProvisioning.ps1 -AdminUrl https://contoso-admin.sharepoint.com -CsvPath ./wave1.csv -WhatIf
.NOTES
    Requires the Microsoft.Online.SharePoint.PowerShell module and the
    SharePoint Administrator role. The CSV needs a UserPrincipalName column.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidatePattern('^https://[a-z0-9-]+-admin\.sharepoint\.com/?$')][string]$AdminUrl,
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$CsvPath,
    [string]$ResultPath = "./onedrive-provisioning-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/src/OneDrivePreProvisioning.psm1" -Force

$rows = @(Import-Csv -LiteralPath $CsvPath)
if ($rows.Count -eq 0) { throw "No rows found in $CsvPath" }
if ($rows[0].PSObject.Properties.Name -notcontains 'UserPrincipalName') {
    throw 'The CSV must have a UserPrincipalName column.'
}

# Interactive sign-in. No credentials are stored or passed on the command line.
Connect-SPOService -Url $AdminUrl

$results = @(Invoke-OneDrivePreProvisioning -UserPrincipalName $rows.UserPrincipalName -WhatIf:$WhatIfPreference)
$results | Export-Csv -LiteralPath $ResultPath -NoTypeInformation -WhatIf:$false

$results | Group-Object Status | Select-Object Name, Count | Format-Table -AutoSize
Write-Host "Results written to $ResultPath"
