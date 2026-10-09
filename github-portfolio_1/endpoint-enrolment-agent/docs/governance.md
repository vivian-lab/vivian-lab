# Governance & Security

These controls are part of the build, not added afterwards.

## Approval gates

A write action never runs without a recorded approval: policy/profile deployment, app assignment, Autopilot assignment, hash import, device-group change and rollback. Power Automate blocks execution until `ApprovalStatus = Approved`; reject reasons are captured on the request.

## Least privilege

| Identity | Type | Rights | Use |
| --- | --- | --- | --- |
| `epagent-readonly` | Entra app | Graph `*.Read.All` only | Checks and reporting |
| `epagent-write` | Managed Identity | Graph `*.ReadWrite.All` only | Write modules, after approval |
| Engineers | User + PIM | Intune Administrator, eligible / just-in-time | Build and operate, time-boxed |

No standing Global Administrator. The read-only identity is structurally incapable of changing the tenant.

## Secrets

All secrets live in Azure Key Vault — never in scripts, flows, SharePoint or documents. Managed Identity is preferred so there is no secret at all.

## Audit log

Every action writes one record:

```
requestId, timestamp, engineer, tenantId, module, objectType, objectId,
action, oldValue, newValue, status, approver, rollback
```

Logs go to Log Analytics; run history, exceptions and success rate surface in Power BI.

## Definition of done

- All 8 modules built and demonstrated in the sandbox
- ≥ 95% enrolment success in the 10-device test
- Every write action has a tested validation and rollback
- Approvals enforced; least-privilege identities, Key Vault and PIM in place
- Dashboard populated with real run data
- Runbook v1.0 published
