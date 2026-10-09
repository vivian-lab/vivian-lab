using namespace System.Net

# HTTP-triggered Azure Function called by the Power Automate flow behind the agent.
# Input:  { "serialNumber": "ABC12345" }
# Output: enrolment and compliance status for that one device.
param($Request, $TriggerMetadata)

function Send-Response {
    param([HttpStatusCode]$Status, $Body)
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = $Status
            Body       = $Body
        })
}

$serialNumber = [string]$Request.Body.serialNumber

try {
    $uri = New-ManagedDeviceQueryUri -SerialNumber $serialNumber
}
catch [System.ArgumentException] {
    Send-Response -Status BadRequest -Body @{ error = $_.Exception.Message }
    return
}

try {
    $token = Get-ManagedIdentityToken
    $result = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Authorization = "Bearer $token" }
}
catch {
    # Log the detail for operators; return nothing internal to the caller.
    Write-Error "Graph lookup failed: $($_.Exception.Message)"
    Send-Response -Status BadGateway -Body @{ error = 'Device lookup failed.' }
    return
}

$devices = @($result.value | ConvertTo-AgentResponse)
if ($devices.Count -eq 0) {
    Send-Response -Status NotFound -Body @{ error = 'No managed device found for that serial number.' }
    return
}

Send-Response -Status OK -Body @{ devices = $devices }
