#Requires -Version 7.0
<#
.SYNOPSIS
    Helpers for an Azure Function that an AI agent calls to read device
    enrolment status from Microsoft Graph.

.DESCRIPTION
    The agent's input ultimately comes from a chat user, so it is treated as
    untrusted: validated against an allowlist before it goes anywhere near a
    Graph query. The function authenticates with its managed identity, so there
    is no client secret to store, rotate or leak.
#>

Set-StrictMode -Version Latest

$script:GraphBase = 'https://graph.microsoft.com/v1.0'
$script:DeviceFields = 'id,deviceName,serialNumber,operatingSystem,complianceState,managementState,enrolledDateTime,lastSyncDateTime'

function Test-SerialNumber {
    <#
    .SYNOPSIS
        Allowlist check: 4-32 letters, digits or hyphens. Anything else is rejected.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Position = 0)][AllowNull()][AllowEmptyString()][string]$SerialNumber)

    [bool]($SerialNumber -cmatch '^[A-Za-z0-9-]{4,32}$')
}

function New-ManagedDeviceQueryUri {
    <#
    .SYNOPSIS
        Builds the Graph query for one device. Throws on input that fails validation.
    .DESCRIPTION
        The serial number is placed inside an OData string literal, so a quote in
        the input would let a caller rewrite the filter (for example to return
        every device in the tenant). Validation rejects it before the URI is built.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$SerialNumber)

    if (-not (Test-SerialNumber $SerialNumber)) {
        throw [System.ArgumentException]::new('serialNumber must be 4-32 letters, digits or hyphens.')
    }

    $filter = [uri]::EscapeDataString("serialNumber eq '$SerialNumber'")
    "$script:GraphBase/deviceManagement/managedDevices?`$filter=$filter&`$select=$script:DeviceFields"
}

function Get-ManagedIdentityToken {
    <#
    .SYNOPSIS
        Gets a Graph access token from the function app's system-assigned managed identity.
    #>
    [CmdletBinding()]
    param([string]$Resource = 'https://graph.microsoft.com')

    if (-not $env:IDENTITY_ENDPOINT -or -not $env:IDENTITY_HEADER) {
        throw 'Managed identity is not available. Enable the system-assigned identity on the function app.'
    }

    $uri = "$($env:IDENTITY_ENDPOINT)?resource=$([uri]::EscapeDataString($Resource))&api-version=2019-08-01"
    (Invoke-RestMethod -Method Get -Uri $uri -Headers @{ 'X-IDENTITY-HEADER' = $env:IDENTITY_HEADER }).access_token
}

function ConvertTo-AgentResponse {
    <#
    .SYNOPSIS
        Reduces a Graph device object to the fields the agent needs to answer.
    .DESCRIPTION
        Data minimisation: whatever is returned here can end up in a chat
        transcript, so user names, email addresses and hardware identifiers
        other than the serial number are deliberately left out.
    #>
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][AllowNull()]$Device)

    process {
        if ($null -eq $Device) { return }
        [ordered]@{
            deviceName      = $Device.deviceName
            serialNumber    = $Device.serialNumber
            operatingSystem = $Device.operatingSystem
            enrolled        = ($Device.managementState -eq 'managed')
            complianceState = $Device.complianceState
            enrolledOn      = $Device.enrolledDateTime
            lastSync        = $Device.lastSyncDateTime
        }
    }
}

Export-ModuleMember -Function Test-SerialNumber, New-ManagedDeviceQueryUri, Get-ManagedIdentityToken, ConvertTo-AgentResponse
