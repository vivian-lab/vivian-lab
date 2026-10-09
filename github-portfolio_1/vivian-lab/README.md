# Hi, I'm Vivian 👋

**Modern Work & Endpoint Automation** · Microsoft 365 · Intune · Copilot Studio · Power Automate · Microsoft Graph

I design **governed agentic automation** for Microsoft 365 — AI agents that do the tedious tenant work, while a human engineer stays in control of every change.

My rule: *the agent recommends and orchestrates; it never makes an uncontrolled production change.*

---

## 🔧 What I work with

| Area | Tools |
| --- | --- |
| Agents & conversation | Microsoft Copilot Studio, Adaptive Cards, Teams |
| Workflow & approvals | Power Automate (cloud + agent flows), Approvals |
| Endpoint management | Microsoft Intune, Windows Autopilot, Win32 app packaging |
| APIs & scripting | Microsoft Graph, PowerShell 7, Graph PowerShell SDK |
| Azure | Azure Automation, Managed Identity, Key Vault, Azure AI Foundry |
| Identity & security | Microsoft Entra ID, PIM, least-privilege app registrations |
| Data & reporting | SharePoint Lists, Log Analytics, Power BI |

---

## 📌 Featured project

### [Endpoint Enrolment Agent](https://github.com/vivian-lab/endpoint-enrolment-agent)

A Copilot Studio agent that prepares a Microsoft 365 tenant for Windows device enrolment and Autopilot — from intake to validated, rollback-ready configuration.

- **8 modules:** Input Collector → Prerequisite Checker → Intune Bootstrap → Autopilot Profile Generator → Hardware Hash Importer → Compliance & Config Deployer → App Packaging → Validation & Rollback
- **Human-in-the-loop:** every write action is approval-gated in Power Automate
- **Least privilege:** separate read-only and write identities, secrets in Key Vault, admin access via PIM
- **Auditable:** every change is logged with old value, new value, approver and a rollback command

`Copilot Studio` `Power Automate` `Microsoft Graph` `Intune` `Autopilot` `PowerShell` `Azure Automation`

---

## 🧭 How I build

1. **Read before write** — prove the readiness checks are accurate before enabling any change.
2. **Templates over hard-coding** — configuration lives in versioned JSON, captured from a clean reference tenant.
3. **Every write has a validation and a rollback** — no task closes without evidence.
4. **AI stays advisory** — real changes are deterministic Graph/PowerShell calls.

---

## 📫 Connect

- LinkedIn: *add your link*
- Email: *add your preferred contact*
