# ADR 003: App-only Graph permissions, one per capability

**Status:** Accepted

## Context

An agent that can act on a tenant is only as safe as the permissions behind it. A language model can be talked into attempting things its designers did not intend, so the permission boundary has to hold even if the agent misbehaves.

## Decision

- Use application (app-only) permissions granted to the managed identity.
- Grant the narrowest permission that supports each capability: read-only unless the capability writes.
- Separate agents use separate identities. The endpoint agent cannot touch mailboxes; the Exchange agent cannot touch devices.
- Anything that changes tenant state goes through an approval step in the orchestration layer before the function is called.

## Reasons

- The blast radius of a prompt-injection or logic fault is limited to what one identity can do.
- Permissions map one-to-one to documented capabilities, so an access review is a short list.
- Read and write paths are distinct functions, which makes it obvious in code review when a change adds write access.

## Consequences

- Adding a capability means a deliberate permission change and an admin consent, which is slower than granting a broad permission once. That friction is intended.
- App-only permissions are tenant-wide by nature. Where the workload supports scoping (for example, restricting an application to specific mailboxes), it is applied.
