# Flow: Store-Intake-Request

Called from the Copilot Studio intake topic after the user confirms the Adaptive Card. Validates the request, checks the target group exists, and writes one row to SharePoint.

**Trigger:** When Copilot Studio (Power Virtual Agents) calls a flow
**Inputs (text):** `tenantId`, `licensingContext`, `deviceOwnership`, `windowsVersion`, `targetGroupId`, `complianceProfile`, `appList`, `requesterEmail`

## Steps

1. **Required fields present**

   ```
   and(
     not(empty(triggerBody()?['tenantId'])),
     not(empty(triggerBody()?['deviceOwnership'])),
     not(empty(triggerBody()?['windowsVersion'])),
     not(empty(triggerBody()?['targetGroupId']))
   )
   ```
   No → return `status = "missing"`

2. **Tenant ID is GUID-shaped** — `length(triggerBody()?['tenantId'])` equals `36`
   No → return `status = "invalid_tenant"`

3. **Group exists** (read-only Graph call)
   - Key Vault → Get secret → token request → Parse JSON
   - `GET https://graph.microsoft.com/v1.0/groups/@{triggerBody()?['targetGroupId']}`
   - Status ≠ 200 → return `status = "group_not_found"`

4. **Write the row** — SharePoint *Create item* in `IntakeRequests`
   - `Title = concat('IR-', utcNow('yyyyMMddHHmmss'))`
   - `TargetGroupName` from the Graph response
   - `Status = Submitted`
   - Return `status = "ok"`, `itemId`

## Bot handling of the result

| status | Agent behaviour |
| --- | --- |
| `ok` | "Request filed as {itemId}." |
| `missing` | Re-show the pre-filled card, ask for the blank fields |
| `invalid_tenant` | Explain the tenant ID looks wrong, re-show the card |
| `group_not_found` | Explain the group wasn't found, re-show the card |

The card keeps its values, so the user only fixes the wrong field — intake never restarts.
