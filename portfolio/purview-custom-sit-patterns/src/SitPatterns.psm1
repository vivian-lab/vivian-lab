#Requires -Version 5.1
<#
.SYNOPSIS
    Custom sensitive information type (SIT) patterns for Microsoft Purview DLP,
    with a local test harness and a rule-package exporter.

.DESCRIPTION
    Writing a custom SIT directly in the Purview portal makes it slow to test:
    every change needs a publish, a wait, and a document upload. This module
    keeps the patterns in source control, lets you test them locally against
    synthetic data in milliseconds, and then exports the same definitions as a
    Purview rule package XML.

    All sample data used with this module must be synthetic. Never commit real
    identifiers.
#>

Set-StrictMode -Version Latest

# Entity GUIDs are fixed on purpose. Purview identifies a SIT by its GUID, so
# regenerating them on every export would create duplicates instead of updates.
$script:SitPatterns = @(
    [pscustomobject]@{
        Id             = 'KE-NationalId'
        EntityGuid     = 'd3dfe313-a843-4335-9b69-d9bdbf0a6600'
        Name           = 'Kenya National ID Number'
        Description    = 'Kenya national identity card number (7-8 digits). Digits alone are too generic, so supporting evidence is mandatory.'
        Regex          = '\b\d{7,8}\b'
        Keywords       = @('national id', 'id number', 'id no', 'identity card', 'kitambulisho')
        RequireKeyword = $true
        Validator      = $null
        PurviewIdMatch = $null
    }
    [pscustomobject]@{
        Id             = 'KE-Passport'
        EntityGuid     = 'd5e837b2-807c-4e29-919b-fd5a532d86ae'
        Name           = 'Kenya Passport Number'
        Description    = 'Kenya passport number (one or two letters followed by 6-7 digits).'
        Regex          = '\b[A-Z]{1,2}\d{6,7}\b'
        Keywords       = @('passport', 'passport number', 'passport no', 'travel document')
        RequireKeyword = $true
        Validator      = $null
        PurviewIdMatch = $null
    }
    [pscustomobject]@{
        Id             = 'PaymentCard'
        EntityGuid     = 'd321155b-566b-4004-ba06-5bc909f01273'
        Name           = 'Payment Card Number (Luhn validated)'
        Description    = 'Payment card PAN, 13-19 digits with optional space or hyphen separators, validated with the Luhn checksum.'
        Regex          = '\b(?:\d[ -]?){12,18}\d\b'
        Keywords       = @('card', 'card number', 'card no', 'pan', 'visa', 'mastercard', 'verve', 'expiry', 'cvv')
        RequireKeyword = $false
        Validator      = 'Luhn'
        # In Purview the built-in function does the checksum, so the export
        # references it instead of the raw regex.
        PurviewIdMatch = 'Func_credit_card'
    }
    [pscustomobject]@{
        Id             = 'BW-Omang'
        EntityGuid     = '8bafb3e5-12db-4061-82c6-c7b2f0b6c854'
        Name           = 'Botswana National ID (Omang)'
        Description    = 'Botswana Omang number: 9 digits where the fifth digit is 1 or 2.'
        Regex          = '\b\d{4}[12]\d{4}\b'
        Keywords       = @('omang', 'national id', 'id number', 'identity number')
        RequireKeyword = $true
        Validator      = $null
        PurviewIdMatch = $null
    }
    [pscustomobject]@{
        Id             = 'BW-Imsi'
        EntityGuid     = 'cdce08e0-b692-4e59-b4e8-1f9c0fa08943'
        Name           = 'IMSI (Botswana MCC 652)'
        Description    = 'International Mobile Subscriber Identity: 15 digits beginning with mobile country code 652.'
        Regex          = '\b652\d{12}\b'
        Keywords       = @('imsi', 'subscriber identity', 'sim')
        RequireKeyword = $true
        Validator      = $null
        PurviewIdMatch = $null
    }
    [pscustomobject]@{
        Id             = 'BW-Msisdn'
        EntityGuid     = 'dcb5003c-b816-43c2-a75d-72fae67462c2'
        Name           = 'MSISDN (Botswana mobile)'
        Description    = 'Botswana mobile subscriber number in international format (+267 followed by 8 digits starting with 7).'
        Regex          = '(?:\+|\b00|\b)267[ -]?7\d[ -]?\d{3}[ -]?\d{3}\b'
        Keywords       = @('msisdn', 'mobile number', 'subscriber', 'cdr', 'calling number', 'called number')
        RequireKeyword = $true
        Validator      = $null
        PurviewIdMatch = $null
    }
)

function Get-LuhnTotal {
    param([Parameter(Mandatory)][string]$Digits)

    $sum = 0
    $double = $false
    for ($i = $Digits.Length - 1; $i -ge 0; $i--) {
        $d = [int][string]$Digits[$i]
        if ($double) {
            $d *= 2
            if ($d -gt 9) { $d -= 9 }
        }
        $sum += $d
        $double = -not $double
    }
    $sum
}

function Test-LuhnChecksum {
    <#
    .SYNOPSIS
        Returns $true when the digits in the input pass the Luhn (mod 10) check.
    .EXAMPLE
        Test-LuhnChecksum '4111 1111 1111 1111'   # True (public test number)
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$Number)

    $digits = $Number -replace '\D', ''
    if ($digits.Length -lt 12 -or $digits.Length -gt 19) { return $false }
    ((Get-LuhnTotal -Digits $digits) % 10) -eq 0
}

function Get-LuhnCheckDigit {
    <#
    .SYNOPSIS
        Calculates the Luhn check digit for a partial number. Used to build
        synthetic, checksum-valid test data without touching real card numbers.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param([Parameter(Mandatory, Position = 0)][ValidatePattern('^\d+$')][string]$Partial)

    $total = Get-LuhnTotal -Digits ($Partial + '0')
    (10 - ($total % 10)) % 10
}

function Get-SitPattern {
    <#
    .SYNOPSIS
        Returns the pattern catalogue, optionally filtered by Id.
    #>
    [CmdletBinding()]
    param([string[]]$Id)

    if ($Id) {
        $found = @($script:SitPatterns | Where-Object { $_.Id -in $Id })
        $missing = @($Id | Where-Object { $_ -notin $found.Id })
        if ($missing.Count -gt 0) { throw "Unknown pattern id: $($missing -join ', ')" }
        return $found
    }
    $script:SitPatterns
}

function New-BinScopedCardPattern {
    <#
    .SYNOPSIS
        Builds a card pattern limited to specific issuer BIN prefixes.
    .DESCRIPTION
        A generic card rule fires on every card in the estate. A bank usually
        cares most about its own cards, so this scopes detection to the BINs it
        issues. Supply the BINs from the issuer; none are hard-coded here.
    .EXAMPLE
        New-BinScopedCardPattern -BinPrefix '999999' -Name 'Contoso Debit Card'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidatePattern('^\d{6,8}$')][string[]]$BinPrefix,
        [string]$Name = 'Issuer Debit Card (BIN scoped)',
        [guid]$EntityGuid = [guid]::NewGuid()
    )

    $alternatives = foreach ($bin in ($BinPrefix | Sort-Object -Unique)) {
        # Separators can fall inside the BIN ("9999 99.."), so allow one between every digit.
        $prefix = ($bin.ToCharArray() -join '[ -]?')
        $minRest = 16 - $bin.Length
        $maxRest = 19 - $bin.Length
        "$prefix(?:[ -]?\d){$minRest,$maxRest}"
    }

    [pscustomobject]@{
        Id             = 'BinScopedCard'
        EntityGuid     = $EntityGuid.ToString()
        Name           = $Name
        Description    = "Payment card numbers starting with issuer BIN(s): $($BinPrefix -join ', ')."
        Regex          = '\b(?:' + ($alternatives -join '|') + ')\b'
        Keywords       = @('card', 'card number', 'debit', 'pan', 'expiry', 'cvv')
        RequireKeyword = $false
        Validator      = 'Luhn'
        PurviewIdMatch = $null
    }
}

function Test-KeywordProximity {
    param(
        [string]$Text, [int]$Index, [int]$Length, [string[]]$Keywords, [int]$Proximity
    )

    $start = [Math]::Max(0, $Index - $Proximity)
    $end = [Math]::Min($Text.Length, $Index + $Length + $Proximity)
    $window = $Text.Substring($start, $end - $start)

    foreach ($keyword in $Keywords) {
        $pattern = '(?i)(?<!\w)' + [regex]::Escape($keyword) + '(?!\w)'
        if ([regex]::IsMatch($window, $pattern)) { return $true }
    }
    $false
}

function Protect-Value {
    param([string]$Value)

    if ($Value.Length -le 4) { return ('*' * $Value.Length) }
    ('*' * ($Value.Length - 4)) + $Value.Substring($Value.Length - 4)
}

function Find-SensitiveData {
    <#
    .SYNOPSIS
        Scans text with the pattern catalogue and returns matches with a
        confidence level, mirroring how Purview scores a SIT.
    .DESCRIPTION
        Confidence 85 = primary match plus a keyword within the proximity window.
        Confidence 65 = primary match that passed its checksum, no keyword.
        Patterns marked RequireKeyword never match on digits alone.

        Matched values are masked by default so results are safe to log.
    .EXAMPLE
        Get-Content .\samples\synthetic.txt -Raw | Find-SensitiveData
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][AllowEmptyString()][string]$Text,
        [object[]]$Pattern = (Get-SitPattern),
        [ValidateRange(1, 5000)][int]$Proximity = 300,
        [switch]$IncludeValue
    )

    process {
        foreach ($p in $Pattern) {
            foreach ($match in [regex]::Matches($Text, $p.Regex)) {
                if ($p.Validator -eq 'Luhn' -and -not (Test-LuhnChecksum $match.Value)) { continue }

                $hasKeyword = Test-KeywordProximity -Text $Text -Index $match.Index -Length $match.Length `
                    -Keywords $p.Keywords -Proximity $Proximity
                if ($p.RequireKeyword -and -not $hasKeyword) { continue }

                $result = [ordered]@{
                    PatternId  = $p.Id
                    Name       = $p.Name
                    Masked     = Protect-Value $match.Value
                    Index      = $match.Index
                    Confidence = if ($hasKeyword) { 85 } else { 65 }
                }
                if ($IncludeValue) { $result.Value = $match.Value }
                [pscustomobject]$result
            }
        }
    }
}

function Export-SitRulePackage {
    <#
    .SYNOPSIS
        Writes the pattern catalogue as a Microsoft Purview rule package XML.
    .DESCRIPTION
        Upload the result with:
            New-DlpSensitiveInformationTypeRulePackage -FileData ([IO.File]::ReadAllBytes($Path))
        Always upload to a test tenant first.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [object[]]$Pattern = (Get-SitPattern),
        [string]$PublisherName = 'Security Engineering',
        [string]$PackageName = 'Custom SIT Patterns',
        [guid]$RulePackId = '5ccc84f5-a1ad-4067-b44d-ccee41245f1c',
        [guid]$PublisherId = '7561ce76-2c65-4697-85b1-bdab57f7beea',
        [version]$Version = '1.0.0.0',
        [ValidateRange(1, 5000)][int]$Proximity = 300
    )

    $esc = { param($s) [System.Security.SecurityElement]::Escape([string]$s) }
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-16"?>')
    [void]$sb.AppendLine('<RulePackage xmlns="http://schemas.microsoft.com/office/2011/mce">')
    [void]$sb.AppendLine("  <RulePack id=`"$RulePackId`">")
    [void]$sb.AppendLine("    <Version major=`"$($Version.Major)`" minor=`"$($Version.Minor)`" build=`"$($Version.Build)`" revision=`"$($Version.Revision)`"/>")
    [void]$sb.AppendLine("    <Publisher id=`"$PublisherId`"/>")
    [void]$sb.AppendLine('    <Details defaultLangCode="en-us">')
    [void]$sb.AppendLine('      <LocalizedDetails langcode="en-us">')
    [void]$sb.AppendLine("        <PublisherName>$(& $esc $PublisherName)</PublisherName>")
    [void]$sb.AppendLine("        <Name>$(& $esc $PackageName)</Name>")
    [void]$sb.AppendLine("        <Description>$(& $esc "$PackageName generated from source control")</Description>")
    [void]$sb.AppendLine('      </LocalizedDetails>')
    [void]$sb.AppendLine('    </Details>')
    [void]$sb.AppendLine('  </RulePack>')
    [void]$sb.AppendLine('  <Rules>')

    foreach ($p in $Pattern) {
        $token = $p.Id -replace '[^A-Za-z0-9]', '_'
        $idMatch = if ($p.PurviewIdMatch) { $p.PurviewIdMatch } else { "Regex_$token" }

        [void]$sb.AppendLine("    <Entity id=`"$($p.EntityGuid)`" patternsProximity=`"$Proximity`" recommendedConfidence=`"85`">")
        [void]$sb.AppendLine('      <Pattern confidenceLevel="85">')
        [void]$sb.AppendLine("        <IdMatch idRef=`"$idMatch`"/>")
        [void]$sb.AppendLine("        <Match idRef=`"Keyword_$token`"/>")
        [void]$sb.AppendLine('      </Pattern>')
        if (-not $p.RequireKeyword) {
            [void]$sb.AppendLine('      <Pattern confidenceLevel="65">')
            [void]$sb.AppendLine("        <IdMatch idRef=`"$idMatch`"/>")
            [void]$sb.AppendLine('      </Pattern>')
        }
        [void]$sb.AppendLine('    </Entity>')
    }

    foreach ($p in $Pattern) {
        $token = $p.Id -replace '[^A-Za-z0-9]', '_'
        if (-not $p.PurviewIdMatch) {
            [void]$sb.AppendLine("    <Regex id=`"Regex_$token`">$(& $esc $p.Regex)</Regex>")
        }
        [void]$sb.AppendLine("    <Keyword id=`"Keyword_$token`">")
        [void]$sb.AppendLine('      <Group matchStyle="word">')
        foreach ($keyword in $p.Keywords) {
            [void]$sb.AppendLine("        <Term>$(& $esc $keyword)</Term>")
        }
        [void]$sb.AppendLine('      </Group>')
        [void]$sb.AppendLine('    </Keyword>')
    }

    [void]$sb.AppendLine('    <LocalizedStrings>')
    foreach ($p in $Pattern) {
        [void]$sb.AppendLine("      <Resource idRef=`"$($p.EntityGuid)`">")
        [void]$sb.AppendLine("        <Name default=`"true`" langcode=`"en-us`">$(& $esc $p.Name)</Name>")
        [void]$sb.AppendLine("        <Description default=`"true`" langcode=`"en-us`">$(& $esc $p.Description)</Description>")
        [void]$sb.AppendLine('      </Resource>')
    }
    [void]$sb.AppendLine('    </LocalizedStrings>')
    [void]$sb.AppendLine('  </Rules>')
    [void]$sb.AppendLine('</RulePackage>')

    # Purview requires the rule package to be Unicode (UTF-16) encoded.
    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    [System.IO.File]::WriteAllText($fullPath, $sb.ToString(), [System.Text.Encoding]::Unicode)
    Get-Item -LiteralPath $fullPath
}

Export-ModuleMember -Function Test-LuhnChecksum, Get-LuhnCheckDigit, Get-SitPattern,
    New-BinScopedCardPattern, Find-SensitiveData, Export-SitRulePackage
