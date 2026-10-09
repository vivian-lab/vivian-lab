# All identifiers in this file are synthetic.

BeforeAll {
    Import-Module "$PSScriptRoot/../src/SitPatterns.psm1" -Force
}

Describe 'Test-LuhnChecksum' {
    It 'accepts the public test number <Number>' -TestCases @(
        @{ Number = '4111111111111111' }
        @{ Number = '5555 5555 5555 4444' }
        @{ Number = '4111-1111-1111-1111' }
    ) {
        param($Number)
        Test-LuhnChecksum $Number | Should -BeTrue
    }

    It 'rejects <Number>' -TestCases @(
        @{ Number = '4111111111111112' }
        @{ Number = '1234567' }
        @{ Number = '' }
    ) {
        param($Number)
        Test-LuhnChecksum $Number | Should -BeFalse
    }

    It 'round-trips with Get-LuhnCheckDigit' {
        $partial = '999999000000000'
        $number = $partial + (Get-LuhnCheckDigit $partial)
        Test-LuhnChecksum $number | Should -BeTrue
    }
}

Describe 'Find-SensitiveData' {
    It 'finds a card number without a keyword at confidence 65' {
        $hits = @(Find-SensitiveData -Text 'ref 4111 1111 1111 1111 processed' -Pattern (Get-SitPattern -Id PaymentCard))
        $hits | Should -HaveCount 1
        $hits[0].Confidence | Should -Be 65
    }

    It 'raises confidence to 85 when a keyword is nearby' {
        $hits = @(Find-SensitiveData -Text 'Card number: 4111111111111111' -Pattern (Get-SitPattern -Id PaymentCard))
        $hits[0].Confidence | Should -Be 85
    }

    It 'ignores a 16-digit number that fails the checksum' {
        $hits = @(Find-SensitiveData -Text 'Card number: 4111111111111112' -Pattern (Get-SitPattern -Id PaymentCard))
        $hits | Should -HaveCount 0
    }

    It 'masks the value unless -IncludeValue is used' {
        $hit = @(Find-SensitiveData -Text 'card 4111111111111111' -Pattern (Get-SitPattern -Id PaymentCard))[0]
        $hit.Masked | Should -Be '************1111'
        $hit.PSObject.Properties.Name -contains 'Value' | Should -BeFalse
    }

    It 'matches <Id> only when a keyword is present' -TestCases @(
        @{ Id = 'KE-NationalId'; With = 'National ID 12345678 on file'; Without = 'Invoice 12345678 on file' }
        @{ Id = 'KE-Passport'; With = 'Passport no AK0123456'; Without = 'Order AK0123456 shipped' }
        @{ Id = 'BW-Omang'; With = 'Omang: 123419876'; Without = 'Ticket 123419876 closed' }
        @{ Id = 'BW-Imsi'; With = 'IMSI 652010123456789'; Without = 'Trace 652010123456789' }
        @{ Id = 'BW-Msisdn'; With = 'CDR calling number +267 71 234 567'; Without = 'Dial +267 71 234 567' }
    ) {
        param($Id, $With, $Without)
        $pattern = Get-SitPattern -Id $Id
        @(Find-SensitiveData -Text $With -Pattern $pattern) | Should -HaveCount 1
        @(Find-SensitiveData -Text $Without -Pattern $pattern) | Should -HaveCount 0
    }

    It 'does not treat an Omang-length number with the wrong fifth digit as a match' {
        @(Find-SensitiveData -Text 'Omang: 123459876' -Pattern (Get-SitPattern -Id BW-Omang)) | Should -HaveCount 0
    }

    It 'ignores a keyword outside the proximity window' {
        $text = 'passport' + (' x' * 400) + ' AK0123456'
        @(Find-SensitiveData -Text $text -Pattern (Get-SitPattern -Id KE-Passport)) | Should -HaveCount 0
    }

    It 'returns nothing for empty input' {
        @(Find-SensitiveData -Text '') | Should -HaveCount 0
    }
}

Describe 'New-BinScopedCardPattern' {
    It 'matches only cards that start with the supplied BIN' {
        $inScope = '999999000000000'
        $inScope += Get-LuhnCheckDigit $inScope
        $pattern = New-BinScopedCardPattern -BinPrefix '999999'

        @(Find-SensitiveData -Text "debit card $inScope" -Pattern $pattern) | Should -HaveCount 1
        @(Find-SensitiveData -Text 'debit card 4111111111111111' -Pattern $pattern) | Should -HaveCount 0
    }

    It 'matches when separators fall inside the BIN' {
        $number = '999999000000000'
        $number += Get-LuhnCheckDigit $number
        $spaced = ($number -replace '(\d{4})(?=\d)', '$1 ')
        $pattern = New-BinScopedCardPattern -BinPrefix '999999'
        @(Find-SensitiveData -Text "card $spaced" -Pattern $pattern) | Should -HaveCount 1
    }

    It 'rejects a BIN that is not 6-8 digits' {
        { New-BinScopedCardPattern -BinPrefix '12ab' } | Should -Throw
    }
}

Describe 'Get-SitPattern' {
    It 'throws on an unknown id' {
        { Get-SitPattern -Id 'Nope' } | Should -Throw
    }

    It 'uses a unique entity GUID for every pattern' {
        $guids = @((Get-SitPattern).EntityGuid)
        @($guids | Sort-Object -Unique) | Should -HaveCount $guids.Count
    }
}

Describe 'Export-SitRulePackage' {
    It 'writes well-formed UTF-16 XML with one entity per pattern' {
        $path = Join-Path ([System.IO.Path]::GetTempPath()) "sit-$([guid]::NewGuid()).xml"
        try {
            Export-SitRulePackage -Path $path | Out-Null

            $bytes = [System.IO.File]::ReadAllBytes($path)
            $bytes[0] | Should -Be 0xFF
            $bytes[1] | Should -Be 0xFE

            $xml = [xml][System.IO.File]::ReadAllText($path)
            @($xml.RulePackage.Rules.Entity) | Should -HaveCount @(Get-SitPattern).Count
            @($xml.RulePackage.Rules.LocalizedStrings.Resource) | Should -HaveCount @(Get-SitPattern).Count
        }
        finally {
            Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue
        }
    }
}
