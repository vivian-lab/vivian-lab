# ADR 002: Keep every remaining secret in Azure Key Vault

**Status:** Accepted

## Context

Managed identity removes the Graph credential, but some secrets remain: function keys used by the orchestration layer, and credentials for third-party services that do not support Microsoft Entra authentication.

## Decision

Store all of them in Azure Key Vault. Application settings hold Key Vault references only, never values. The function's managed identity is granted read access to secrets in that vault and nothing more.

## Reasons

- Secrets stay out of source control, deployment templates and exported app settings.
- Access is logged per secret, which gives an audit trail for who or what read a credential.
- Rotation happens in one place without redeploying the function.

## Consequences

- The vault is now a dependency: if it is unreachable, the function cannot start. Soft delete and purge protection are enabled.
- Access uses role-based access control scoped to the vault, reviewed with the rest of the identity's permissions.
