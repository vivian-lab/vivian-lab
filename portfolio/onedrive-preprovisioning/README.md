# onedrive-preprovisioning

![tests](https://github.com/YOUR-USERNAME/onedrive-preprovisioning/actions/workflows/tests.yml/badge.svg)

Batch pre-provisioning of OneDrive sites ahead of a Microsoft 365 tenant-to-tenant migration.

## The problem

A OneDrive site does not exist until its owner opens it for the first time. Migration tools need the destination site in place before they can copy data, so every user in a migration wave has to be provisioned in advance. SharePoint Online accepts at most 200 users per request, input lists from HR or a source tenant are rarely clean, and throttling makes some requests fail on the first attempt.

## What it does

1. Trims, lower-cases and validates each user principal name.
2. Flags invalid and duplicate entries without submitting them.
3. Splits the remainder into batches of up to 200.
4. Retries a failed batch with exponential backoff.
5. Returns one result row per user (`Requested`, `Failed`, `Invalid`, `Duplicate`, `Skipped`) and writes them to CSV as an audit trail.

## Usage

```powershell
# Dry run: shows the batches, changes nothing
./Start-OneDrivePreProvisioning.ps1 -AdminUrl https://contoso-admin.sharepoint.com -CsvPath ./wave1.csv -WhatIf

# Real run
./Start-OneDrivePreProvisioning.ps1 -AdminUrl https://contoso-admin.sharepoint.com -CsvPath ./wave1.csv
```

The CSV needs one column, `UserPrincipalName`. Requires the `Microsoft.Online.SharePoint.PowerShell` module and the SharePoint Administrator role.

## Design decisions

- **Interactive sign-in only.** No credentials in parameters, files or environment variables.
- **`-WhatIf` support.** A migration wave can be rehearsed before anything changes in the tenant.
- **Injectable request action.** The call to SharePoint is a parameter, so batching, retry and error handling are unit tested without a tenant.
- **Per-user results.** After a wave of several thousand users, the question is always "which ones failed and why". The output answers it directly.

## Tests

```powershell
Invoke-Pester ./tests
```

7 tests cover batch sizing, the 200-user ceiling, validation and de-duplication, retry behaviour, failure reporting and `-WhatIf`.

## Licence

MIT
