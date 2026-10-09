BeforeAll {
    Import-Module "$PSScriptRoot/../function/Modules/AgentHelpers/AgentHelpers.psm1" -Force
}

Describe 'Test-SerialNumber' {
    It 'accepts <Value>' -TestCases @(
        @{ Value = 'ABC12345' }
        @{ Value = 'PF-3X9K2L' }
        @{ Value = '5CG1234XYZ' }
    ) {
        param($Value)
        Test-SerialNumber $Value | Should -BeTrue
    }

    It 'rejects <Value>' -TestCases @(
        @{ Value = '' }
        @{ Value = 'AB' }
        @{ Value = "X' or 1 eq 1 or serialNumber eq 'Y" }
        @{ Value = 'ABC 12345' }
        @{ Value = 'ABC123&$top=999' }
        @{ Value = ('A' * 33) }
    ) {
        param($Value)
        Test-SerialNumber $Value | Should -BeFalse
    }
}

Describe 'New-ManagedDeviceQueryUri' {
    It 'builds an encoded filter for a valid serial number' {
        $uri = New-ManagedDeviceQueryUri 'ABC12345'
        $uri.StartsWith('https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?') | Should -BeTrue
        $uri.Contains("serialNumber%20eq%20%27ABC12345%27") | Should -BeTrue
    }

    It 'requests only the fields the agent needs' {
        $uri = New-ManagedDeviceQueryUri 'ABC12345'
        $uri.Contains('userPrincipalName') | Should -BeFalse
        $uri.Contains('emailAddress') | Should -BeFalse
    }

    It 'throws on a filter injection attempt' {
        { New-ManagedDeviceQueryUri "X' or 1 eq 1 or serialNumber eq 'Y" } | Should -Throw
    }
}

Describe 'ConvertTo-AgentResponse' {
    It 'drops fields that identify the user' {
        $device = [pscustomobject]@{
            deviceName = 'LAPTOP-01'; serialNumber = 'ABC12345'; operatingSystem = 'Windows'
            managementState = 'managed'; complianceState = 'compliant'
            enrolledDateTime = '2026-01-01T00:00:00Z'; lastSyncDateTime = '2026-01-02T00:00:00Z'
            userPrincipalName = 'someone@contoso.com'; emailAddress = 'someone@contoso.com'
        }
        $out = $device | ConvertTo-AgentResponse

        $out.enrolled | Should -BeTrue
        $out.Contains('userPrincipalName') | Should -BeFalse
        $out.Contains('emailAddress') | Should -BeFalse
    }
}

Describe 'Get-ManagedIdentityToken' {
    It 'fails clearly when no managed identity is configured' {
        $savedEndpoint = $env:IDENTITY_ENDPOINT
        $env:IDENTITY_ENDPOINT = $null
        try { { Get-ManagedIdentityToken } | Should -Throw }
        finally { $env:IDENTITY_ENDPOINT = $savedEndpoint }
    }
}
