# ADR 001: Authenticate to Microsoft Graph with a system-assigned managed identity

**Status:** Accepted

## Context

The function needs to call Microsoft Graph without a signed-in user. The usual options are an app registration with a client secret, an app registration with a certificate, or a managed identity.

## Decision

Use the function app's system-assigned managed identity. Treat this as a fixed requirement, not a preference.

## Reasons

- **Nothing to leak.** There is no secret or certificate in code, configuration or a deployment pipeline.
- **Nothing to rotate.** Expired client secrets are a common cause of outages in automation.
- **Lifecycle is tied to the resource.** Deleting the function app removes the identity, so no orphaned credential keeps working.
- **Tokens cannot be requested from outside Azure.** A stolen app ID is useless on its own.

## Consequences

- Graph application permissions cannot be granted to a managed identity in the portal; they are assigned with PowerShell or the Graph API. This step is scripted and documented.
- Local development needs a different credential, so the code path that obtains the token is isolated in one function.
- A system-assigned identity cannot be shared. Each function app gets its own, which also keeps permissions separate per agent.
