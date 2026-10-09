# Shadow AI prevention runbook

How to stop sensitive data leaving managed Windows devices through unsanctioned AI tools, using Microsoft Purview Endpoint DLP and Microsoft Defender for Cloud Apps.

This is a sanitised version of a runbook I wrote for client delivery. Portal labels change; check them against current Microsoft documentation before use.

## Objective

Staff paste or upload confidential content into consumer AI tools that the organisation has not approved. The goal is to block that for sensitive content while leaving approved tools usable, and to have evidence the control works.

## Control design

Three layers, because each one alone has a gap.

| Layer | Control | Covers | Gap it leaves |
|---|---|---|---|
| 1 | Endpoint DLP: sensitive service domains | Upload and paste to AI websites in supported browsers | Desktop apps |
| 2 | Endpoint DLP: restricted app groups | AI desktop apps opening or reading sensitive files | Content typed from memory |
| 3 | Defender for Cloud Apps: unsanctioned apps | Network access to the service from onboarded devices | Unmanaged devices |

## Prerequisites

- Devices onboarded to Microsoft Purview Endpoint DLP and Microsoft Defender for Endpoint.
- Sensitivity labels or sensitive information types already identify the content to protect.
- Defender for Cloud Apps integrated with Defender for Endpoint, with enforcement of app access turned on.
- A pilot group of devices and a named business owner for exceptions.

## Procedure

### Phase 1: Discover

1. In Defender for Cloud Apps, open cloud discovery and filter the app catalogue to the generative AI category.
2. Export the apps in use, with user and traffic counts.
3. Agree with the business owner which are approved. Everything else is in scope for blocking.

### Phase 2: Block web upload and paste

1. In Endpoint DLP settings, create a sensitive service domain group containing the unapproved AI domains.
2. Add any browsers that do not support Endpoint DLP to the unallowed browsers list, so the control cannot be sidestepped by switching browser.
3. Create a DLP policy scoped to Devices. Condition: content contains the target labels or information types. Action: restrict upload and paste to the sensitive service domain group.
4. Start in audit mode for the pilot group.

### Phase 3: Restrict desktop apps

1. Identify the executable names of the AI desktop apps found in Phase 1.
2. Create a restricted app group containing them.
3. In the same DLP policy, add a file activity restriction for that app group.
4. Keep audit mode.

### Phase 4: Block the service

1. In Defender for Cloud Apps, tag the unapproved apps as unsanctioned.
2. Confirm the corresponding indicators appear in Defender for Endpoint.

### Phase 5: Validate, then enforce

Run every test below on a pilot device in audit mode, confirm the events appear in Activity Explorer, then switch to block and run them again.

| # | Test | Expected in block mode |
|---|---|---|
| 1 | Paste labelled text into an unapproved AI site | Blocked, user notification shown |
| 2 | Upload a labelled file to an unapproved AI site | Blocked |
| 3 | Paste unlabelled, non-sensitive text into the same site | Allowed (until Phase 4 blocks the site itself) |
| 4 | Open a labelled file from an AI desktop app | Blocked |
| 5 | Repeat test 1 in an unallowed browser | Blocked |
| 6 | Repeat test 1 on an approved AI tool | Allowed |
| 7 | Browse to an unsanctioned AI app | Blocked by Defender for Endpoint |

Tests 3 and 6 matter as much as the others: a control that blocks everything gets switched off.

## Rollback

1. Set the DLP policy back to audit mode. This takes effect without removing configuration.
2. Remove the unsanctioned tag from affected apps.
3. Record what triggered the rollback before changing anything else.

## Known issues

- **Policy sync delay.** Devices can take time to receive a changed policy. Check the policy sync status on the device before concluding a rule does not work.
- **Restricted app group validation.** In one deployment the portal rejected a valid app group with a GUID validation error. It was documented and escalated to Microsoft. Layers 1 and 3 still apply to an app affected this way.
- **App updates change executables.** Review the restricted app group whenever a blocked app releases a major update.

## Evidence for audit

- Exported DLP policy configuration.
- Activity Explorer export showing each validation test in audit and block mode.
- The approved and unsanctioned app list, signed off by the business owner.

## Licence

MIT
