BeforeAll {
    Import-Module "$PSScriptRoot/../src/OneDrivePreProvisioning.psm1" -Force
}

Describe 'Invoke-OneDrivePreProvisioning' {
    It 'splits 450 users into batches of 200, 200 and 50' {
        $script:sizes = @()
        $users = 1..450 | ForEach-Object { "user$_@contoso.com" }

        $rows = @(Invoke-OneDrivePreProvisioning -UserPrincipalName $users -RequestAction {
                param($Batch) $script:sizes += $Batch.Count
            })

        $script:sizes -join ',' | Should -Be '200,200,50'
        @($rows | Where-Object Status -eq 'Requested') | Should -HaveCount 450
    }

    It 'never sends more than the batch size in one request' {
        $script:largest = 0
        $users = 1..25 | ForEach-Object { "user$_@contoso.com" }

        Invoke-OneDrivePreProvisioning -UserPrincipalName $users -BatchSize 10 -RequestAction {
            param($Batch) if ($Batch.Count -gt $script:largest) { $script:largest = $Batch.Count }
        } | Out-Null

        $script:largest | Should -Be 10
    }

    It 'flags invalid and duplicate entries and does not submit them' {
        $script:sent = @()
        $rows = @(Invoke-OneDrivePreProvisioning -UserPrincipalName @(
                'a@contoso.com', ' A@Contoso.com ', 'not-an-address', '', 'b@contoso.com'
            ) -RequestAction { param($Batch) $script:sent += $Batch })

        $script:sent -join ',' | Should -Be 'a@contoso.com,b@contoso.com'
        @($rows | Where-Object Status -eq 'Invalid') | Should -HaveCount 1
        @($rows | Where-Object Status -eq 'Duplicate') | Should -HaveCount 1
    }

    It 'retries a transient failure and then succeeds' {
        $script:calls = 0
        $rows = @(Invoke-OneDrivePreProvisioning -UserPrincipalName 'a@contoso.com' -RetryDelaySeconds 0 -WarningAction SilentlyContinue -RequestAction {
                param($Batch)
                $script:calls++
                if ($script:calls -lt 3) { throw 'throttled' }
            })

        $script:calls | Should -Be 3
        $rows[0].Status | Should -Be 'Requested'
        $rows[0].Attempts | Should -Be 3
    }

    It 'reports Failed with the error after retries are exhausted' {
        $rows = @(Invoke-OneDrivePreProvisioning -UserPrincipalName 'a@contoso.com' -MaxRetry 1 -RetryDelaySeconds 0 -WarningAction SilentlyContinue -RequestAction {
                param($Batch) throw 'access denied'
            })

        $rows[0].Status | Should -Be 'Failed'
        $rows[0].Attempts | Should -Be 2
        $rows[0].Detail | Should -Be 'access denied'
    }

    It 'submits nothing under -WhatIf' {
        $script:called = $false
        $rows = @(Invoke-OneDrivePreProvisioning -UserPrincipalName 'a@contoso.com' -WhatIf -RequestAction {
                param($Batch) $script:called = $true
            })

        $script:called | Should -BeFalse
        $rows[0].Status | Should -Be 'Skipped'
    }

    It 'returns nothing for an empty list' {
        @(Invoke-OneDrivePreProvisioning -UserPrincipalName @() -RequestAction { param($Batch) }) | Should -HaveCount 0
    }
}
