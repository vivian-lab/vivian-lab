#Requires -Version 5.1
<#
.SYNOPSIS
    Batch pre-provisioning of OneDrive sites ahead of a tenant-to-tenant migration.

.DESCRIPTION
    A OneDrive site is only created when a user first opens it. Migration tools
    need the destination site to exist before they can copy data, so the sites
    have to be requested up front. SharePoint Online accepts at most 200 users
    per request, which makes a large migration wave a batching problem.

    This module validates and de-duplicates the input, splits it into batches,
    retries transient failures with exponential backoff, and returns one result
    row per user so the run can be audited.
#>

Set-StrictMode -Version Latest

function Invoke-OneDrivePreProvisioning {
    <#
    .SYNOPSIS
        Requests OneDrive sites for a list of users, in batches.
    .PARAMETER RequestAction
        The call that submits one batch. It defaults to Request-SPOPersonalSite
        and is a parameter so the batching and retry logic can be unit tested
        without a tenant.
    .EXAMPLE
        Invoke-OneDrivePreProvisioning -UserPrincipalName (Import-Csv users.csv).UserPrincipalName -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$UserPrincipalName,
        [ValidateRange(1, 200)][int]$BatchSize = 200,
        [ValidateRange(0, 10)][int]$MaxRetry = 3,
        [ValidateRange(0, 600)][int]$RetryDelaySeconds = 5,
        [scriptblock]$RequestAction = { param($Batch) Request-SPOPersonalSite -UserEmails $Batch -NoWait }
    )

    $seen = [System.Collections.Generic.HashSet[string]]::new()
    $valid = [System.Collections.Generic.List[string]]::new()

    foreach ($raw in $UserPrincipalName) {
        $upn = ([string]$raw).Trim().ToLowerInvariant()
        if (-not $upn) { continue }

        if ($upn -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
            New-ResultRow -User $upn -Status 'Invalid' -Detail 'Not a valid user principal name'
            continue
        }
        if (-not $seen.Add($upn)) {
            New-ResultRow -User $upn -Status 'Duplicate' -Detail 'Already queued in this run'
            continue
        }
        $valid.Add($upn)
    }

    $batchNumber = 0
    for ($offset = 0; $offset -lt $valid.Count; $offset += $BatchSize) {
        $batchNumber++
        $batch = $valid.GetRange($offset, [Math]::Min($BatchSize, $valid.Count - $offset)).ToArray()

        if (-not $PSCmdlet.ShouldProcess("batch $batchNumber ($($batch.Count) users)", 'Request OneDrive sites')) {
            $batch | ForEach-Object { New-ResultRow -User $_ -Status 'Skipped' -Batch $batchNumber -Detail 'WhatIf' }
            continue
        }

        $attempt = 0
        $succeeded = $false
        $lastError = $null
        while (-not $succeeded -and $attempt -le $MaxRetry) {
            $attempt++
            try {
                & $RequestAction $batch | Out-Null
                $succeeded = $true
            }
            catch {
                $lastError = $_.Exception.Message
                Write-Warning "Batch $batchNumber attempt $attempt failed: $lastError"
                if ($attempt -le $MaxRetry -and $RetryDelaySeconds -gt 0) {
                    Start-Sleep -Seconds ($RetryDelaySeconds * [Math]::Pow(2, $attempt - 1))
                }
            }
        }

        $status = if ($succeeded) { 'Requested' } else { 'Failed' }
        $detail = if ($succeeded) { $null } else { $lastError }
        $batch | ForEach-Object {
            New-ResultRow -User $_ -Status $status -Batch $batchNumber -Attempts $attempt -Detail $detail
        }
    }
}

function New-ResultRow {
    param([string]$User, [string]$Status, [int]$Batch = 0, [int]$Attempts = 0, [string]$Detail)

    [pscustomobject]@{
        UserPrincipalName = $User
        Status            = $Status
        Batch             = $Batch
        Attempts          = $Attempts
        Detail            = $Detail
    }
}

Export-ModuleMember -Function Invoke-OneDrivePreProvisioning
