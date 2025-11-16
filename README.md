# GitHub Workflows

Centralized reusable workflows for xaoscience repositories.

## Dependabot Auto-merge

Automatically merge Dependabot pull requests across multiple repositories.

### Setup

1. **Create a Personal Access Token (PAT)**
   - Go to: https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Scopes: select `repo` (full control of private repositories)
   - Copy the token (starts with `ghp_`)

2. **Store the PAT as an organization secret** (recommended):
   - Organization Settings → Secrets and variables → Actions → New organization secret
   - Name: `AUTOMERGE_PAT`
   - Value: paste your PAT
   - Repository access: "All repositories" or select specific repos

   OR store per-repository:
   ```bash
   gh secret set AUTOMERGE_PAT --repo xaoscience/REPO_NAME
   ```

3. **Add the workflow to your repository**

   Create `.github/workflows/dependabot-automerge.yml`:
   ```yaml
   name: Dependabot Auto-merge

   on:
     pull_request_target:
       types: [opened, reopened, labeled, synchronize]

   jobs:
     automerge:
       uses: xaoscience/github-workflows/.github/workflows/dependabot-automerge-reusable.yml@main
       secrets:
         AUTOMERGE_PAT: ${{ secrets.AUTOMERGE_PAT }}
       # Optional: customize merge method (default: squash)
       # with:
       #   merge_method: squash
       #   require_label: true
   ```

4. **Configure Dependabot to add the automerge label**

   In your repository's `.github/dependabot.yml`:
   ```yaml
   version: 2
   updates:
     - package-ecosystem: "npm"  # or your ecosystem
       directory: "/"
       schedule:
         interval: "weekly"
       labels:
         - "dependencies"
         - "automerge"  # ← add this label
   ```

### Options

- `merge_method`: `merge`, `squash` (default), or `rebase`
- `require_label`: whether to require the `automerge` label (default: `true`)

### Security

- The PAT should have minimal scope (`repo` for private repos)
- Store the PAT only in GitHub secrets (never in code)
- Rotate the PAT periodically (every 6-12 months)
- The workflow validates that PRs are from `dependabot[bot]` to prevent spoofing

### Example: Disable label requirement

If you trust all Dependabot PRs and want to auto-merge without the label:

```yaml
jobs:
  automerge:
    uses: xaoscience/github-workflows/.github/workflows/dependabot-automerge-reusable.yml@main
    secrets:
      AUTOMERGE_PAT: ${{ secrets.AUTOMERGE_PAT }}
    with:
      require_label: false
```
