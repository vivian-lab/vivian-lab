# Threat model

Scope: the path from a chat message to a Microsoft Graph call.

| # | Threat | Example | Mitigation |
|---|---|---|---|
| 1 | Prompt injection drives an unintended action | A user or a document tells the agent to "wipe all devices" | The function exposes narrow, single-purpose operations. Write operations need approval in the orchestration layer. The identity lacks permissions the agent was never meant to use. |
| 2 | Query injection through agent-supplied parameters | A serial number containing `' or 1 eq 1` | Allowlist validation before the query is built; tested with injection strings. |
| 3 | Credential theft | A client secret copied from app settings or a pipeline | No client secret exists. Managed identity for Graph; Key Vault references for everything else. |
| 4 | Over-broad permissions | Agent identity holds `Directory.ReadWrite.All` "to be safe" | One permission per capability, separate identity per agent, reviewed on change. |
| 5 | Sensitive data in chat transcripts | Graph returns user email and the agent repeats it | The function selects only required fields and strips the rest before responding. |
| 6 | Direct calls that bypass the agent | Someone calls the function URL themselves | Function-level key held in Key Vault; network restrictions where the plan allows; all calls logged. |
| 7 | Error messages leak internals | Stack trace or tenant ID returned to the caller | Detailed errors go to the log; the caller gets a generic message. |

## Residual risk

App-only Graph permissions are tenant-wide. A fault inside the function itself is therefore the highest-impact failure, which is why the function is kept small, validated at its boundary, and covered by tests.
