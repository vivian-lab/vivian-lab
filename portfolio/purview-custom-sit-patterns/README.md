# purview-custom-sit-patterns

![tests](https://github.com/YOUR-USERNAME/purview-custom-sit-patterns/actions/workflows/tests.yml/badge.svg)

Custom sensitive information type (SIT) patterns for Microsoft Purview data loss prevention, kept in source control with a local test harness and a rule-package exporter.

## The problem

Microsoft Purview ships with built-in detectors for many identifiers, but not for most African national IDs or for telecom identifiers such as IMSI and MSISDN. Writing custom patterns in the portal is slow to test: each change needs a publish, a wait, and a document upload. Patterns that are too loose flood the security team with false positives; patterns that are too tight miss real leaks.

This module lets you define a pattern once, test it locally in milliseconds against synthetic data, and export the same definition as a Purview rule package.

## What's included

| Pattern | Primary match | Needs a keyword nearby? |
|---|---|---|
| Kenya National ID | 7-8 digits | Yes |
| Kenya passport | 1-2 letters + 6-7 digits | Yes |
| Payment card | 13-19 digits, Luhn checksum | No (keyword raises confidence) |
| Issuer debit card | Same, limited to BIN prefixes you supply | No |
| Botswana Omang | 9 digits, fifth digit 1 or 2 | Yes |
| IMSI (Botswana) | 15 digits starting 652 | Yes |
| MSISDN (Botswana) | +267 and 8 digits starting 7 | Yes |

Scoring mirrors Purview: **85** when a keyword sits within 300 characters of the match, **65** for a checksum-valid match with no keyword. Short numeric identifiers never match on digits alone.

## Usage

```powershell
Import-Module ./src/SitPatterns.psm1

# Scan text. Values are masked by default so output is safe to log.
Get-Content ./samples/synthetic.txt -Raw | Find-SensitiveData

# Scope card detection to an issuer's own BINs
$pattern = New-BinScopedCardPattern -BinPrefix '999999' -Name 'Contoso Debit Card'
Find-SensitiveData -Text $text -Pattern $pattern

# Export for Purview, then upload to a TEST tenant first
Export-SitRulePackage -Path ./rulepack.xml -PublisherName 'Contoso Security'
New-DlpSensitiveInformationTypeRulePackage -FileData ([IO.File]::ReadAllBytes('./rulepack.xml'))
```

## Design decisions

- **Keyword required for generic numbers.** An eight-digit number is an ID, an invoice or a phone extension. Requiring supporting evidence is what keeps the false-positive rate workable.
- **Checksum before reporting.** Card candidates that fail Luhn are dropped, which removes most random digit runs.
- **Separators inside the BIN.** Cards are usually written in groups of four, so a six-digit BIN is split by a space. The BIN-scoped pattern allows a separator between every digit.
- **Masked output.** A scanner that prints what it finds becomes a leak itself.
- **Fixed entity GUIDs.** Purview identifies a SIT by GUID. Stable GUIDs mean a re-export updates the existing SIT instead of creating a duplicate.
- **Built-in function for cards in the export.** The exported card entity references Purview's `Func_credit_card` so the checksum is enforced by the platform.

## Tests

```powershell
Invoke-Pester ./tests
```

25 tests cover checksum validation, keyword proximity, positive and negative cases for every pattern, BIN scoping, masking and XML export. They run on every push through GitHub Actions.

## Limitations

- Identifier formats change. Confirm each pattern against the issuing authority's current specification before production use.
- The local scanner approximates Purview's matching; it does not replace testing the uploaded SIT in a test tenant.
- All sample data is synthetic. Do not commit real identifiers.

## Licence

MIT
