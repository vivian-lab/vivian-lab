# Endpoint Enrolment Agent

> A governed AI agent that prepares Microsoft 365 tenants for Windows device enrolment and Autopilot — with a human approving every change.

![Copilot Studio](https://img.shields.io/badge/Copilot%20Studio-agent-0078D4)
![Power Automate](https://img.shields.io/badge/Power%20Automate-approvals-0066FF)
![Microsoft Graph](https://img.shields.io/badge/Microsoft%20Graph-API-5E5E5E)
![Intune](https://img.shields.io/badge/Intune-Autopilot-00A4EF)
![PowerShell](https://img.shields.io/badge/PowerShell-7-5391FE)

## The problem

Getting a tenant ready for Autopilot is repetitive and error-prone: enrolment restrictions, device categories, deployment profiles, hardware hash imports, compliance policies and app packaging — all done by hand, tenant after tenant.

## The approach

An engineer asks the agent, in plain language, to prepare a tenant. The agent collects the requirements, checks readiness, prepares the configuration, and **asks for approval before it touches anything**. Each change is a deterministic Graph/PowerShell call with its own validation check and rollback step.

```
Intake → Store → Read-only check (RAG) → Approve → Execute → Validate → Log + rollback record
```

## Architecture

| Layer | Tool | Job |
| --- | --- | --- |
| Interaction | Copilot Studio (in Teams) | Guided intake via Adaptive Card; turns free text into structured fields |
| Orchestration | Power Automate | Reads the request, routes approvals, calls execution, writes logs |
| Reasoning (optional) | Azure AI Foundry Agent Service | Planning and interpreting validation output — never changes the tenant |
| Execution | Azure Automation + PowerShell 7 | Runs Graph calls, validation and rollback in a controlled runtime |
| Tenant APIs | Microsoft Graph / Intune | Device, profile, policy and app configuration |
| Security | Managed Identity, Entra apps, Key Vault, PIM | Least privilege, just-in-time admin, no plaintext secrets |
| Data & audit | SharePoint List, Log Analytics, Power BI | Request store, audit trail, pilot metrics |

See [docs/architecture.md](docs/architecture.md) for the full design.

## The 8 modules

| # | Module | Type | What it does |
| --- | --- | --- | --- |
| 1 | Input Collector | List write only | Adaptive Card intake → validated SharePoint request with an ID |
| 2 | Prerequisite Checker | Read-only | Red/Amber/Green readiness report from Graph |
| 3 | Intune Bootstrap | Write | Baseline settings (categories, scope tags, restrictions) from JSON templates |
| 4 | Autopilot Profile Generator | Write | Standard deployment profile + group assignment |
| 5 | Hardware Hash Importer | Write | CSV validation, duplicate detection, import, failure report |
| 6 | Compliance & Config Deployer | Write | Policy-as-template, scoped assignment, conflict detection |
| 7 | App Packaging & Assignment | Write | Win32 `.intunewin` packaging, assignment, install tracking |
| 8 | Validation & Rollback | Read + Write | Validation matrix, rollback records, success dashboard |

Modules 1–2 are built and proven first. Write modules (3–7) are only enabled once the readiness report is shown to be accurate.

## Governance built in

- **Approval gate** before every write — Power Automate waits for `ApprovalStatus = Approved`
- **Two identities:** `epagent-readonly` (Graph `*.Read.All`) and `epagent-write` (Managed Identity, `*.ReadWrite.All`)
- **No standing Global Admin** — Intune Administrator is PIM-eligible, time-boxed
- **Secrets only in Key Vault** — Managed Identity preferred so there's nothing to store
- **Audit log** for every action, including a rollback command ([sample](templates/log-record.sample.json))
- **Acceptance rule:** no request closes until validation evidence is attached

## Repository layout

```
docs/            architecture, module reference, governance
adaptive-cards/  intake and confirmation cards (Copilot Studio)
flows/           Power Automate flow logic and expressions
scripts/         PowerShell: readiness check, hash import, rollback
templates/       JSON templates: Autopilot profile, compliance policy, log record
```

## Targets

- Sandbox test: 10 devices → Pilot: up to 50 devices
- ≥ 95% successful enrolment, zero critical policy conflicts after QA

## Notes

All tenant IDs, names and customer details are removed. Scripts are reference implementations — confirm Graph endpoints, scopes and cmdlets against current Microsoft Learn documentation and test in a sandbox tenant before use.
