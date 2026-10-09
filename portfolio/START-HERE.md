# Publishing your GitHub portfolio

Five folders. Each one becomes one GitHub repository.

| Folder | Repository name on GitHub |
|---|---|
| `profile-readme` | Exactly your GitHub username (this makes it show on your profile page) |
| `purview-custom-sit-patterns` | `purview-custom-sit-patterns` |
| `m365-agent-security-architecture` | `m365-agent-security-architecture` |
| `onedrive-preprovisioning` | `onedrive-preprovisioning` |
| `shadow-ai-prevention-runbook` | `shadow-ai-prevention-runbook` |

## Before you publish

1. **Read every file and run the code.** You will be asked about it. Change anything that does not match how you actually did the work.
2. **Check your employer's policy** on publishing work-related material. Nothing here contains client names or data, but the runbook and architecture draw on delivery work.
3. **Swap in your own scripts** where you have them (your real OneDrive script, your real regex patterns), with client details removed. Your own code is always the stronger evidence.
4. **Replace the placeholders:** search all files for `YOUR-USERNAME` and `YOUR-LINKEDIN-URL`.

## Steps

1. Create an account at github.com. Use a professional username (for example `vivianokpala`).
2. Install Git (git-scm.com) and sign in when prompted.
3. For each folder, create an empty **public** repository on GitHub with the name from the table (no README, no licence), then run in that folder:

   ```
   git init -b main
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/YOUR-USERNAME/REPO-NAME.git
   git push -u origin main
   ```

   Use Git rather than drag-and-drop upload: the browser upload skips the hidden `.github` folder that runs the tests.
4. On each code repository, open the **Actions** tab and confirm the test run is green.
5. On your profile page, choose **Customize your pins** and pin the four project repositories.
6. Add a short description and topics to each repository (for example `powershell`, `microsoft-purview`, `dlp`, `security`).

## Run the tests locally

In PowerShell 7, from any of the three code folders:

```
Invoke-Pester ./tests
```
