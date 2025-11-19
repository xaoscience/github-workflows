# GitHub Workflows

Centralized reusable workflows for xaoscience repositories.

## Dependabot Auto-merge

Automatically merge Dependabot pull requests across multiple repositories.

### Setup (Personal Account Scenario)

1. **Create a Personal Access Token (PAT)**
   - URL: https://github.com/settings/tokens (classic) or fine-grained token creation page.
   - Classic scope: select ONLY `repo` (avoid unnecessary scopes).
   - Fine-grained alternative: grant your targeted repos "Contents: Read & write" and "Pull requests: Read & write".
   - Copy the token (starts with `ghp_` or fine-grained prefix). Store it in a password manager—not a plain file.

2. **Seed the PAT across your repositories** (personal accounts lack org-level shared secrets):
   - Use bulk script: `./scripts/seed-automerge-secret.sh` from this folder.
   - Secret name expected by the workflow: `AUTOMERGE_PAT`.
   - Example manual single-repo add:
     ```bash
     printf '%s' "$AUTOMERGE_PAT_VALUE" | gh secret set AUTOMERGE_PAT --repo YOUR_USER/REPO_NAME --body -
     ```

3. **Add caller workflow to each repo** (or copy/paste):
   Create `.github/workflows/dependabot-automerge.yml` in the consuming repo:
   ```yaml
   name: Dependabot Auto-merge

   on:
     pull_request_target:
       types: [opened, reopened, labeled, synchronize]

   jobs:
     automerge:
       uses: xaoscience/github-workflows/.github/workflows/dependabot-automerge-reusable/dependabot-automerge-reusable.yml@main
       secrets:
         AUTOMERGE_PAT: ${{ secrets.AUTOMERGE_PAT }}
       # Optional customization
       with:
         merge_method: squash
         require_label: true
   ```

4. **Configure Dependabot to add the automerge label**:
   `.github/dependabot.yml` example:
   ```yaml
   version: 2
   updates:
     - package-ecosystem: "npm"
       directory: "/"
       schedule:
         interval: "weekly"
       labels:
         - dependencies
         - automerge
   ```

### Options

- `merge_method`: `merge`, `squash` (default), or `rebase`
- `require_label`: whether to require the `automerge` label (default: `true`)

### Security

- The PAT should have minimal scope (`repo` for private repos)
- Store the PAT only in GitHub secrets (never in code)
- Rotate the PAT periodically (every 6-12 months)
- The workflow validates that PRs are from `dependabot[bot]` to prevent spoofing

#### Fine-Grained vs Classic PAT
Fine-grained tokens reduce blast radius by scoping to select repositories and specific permissions. Prefer them if you regularly audit access.

#### Bulk Seeding & Rotation
Scripts provided:
- `scripts/seed-automerge-secret.sh` – initial distribution (supports `--match` and `--dry-run`).
- `scripts/rotate-automerge-secret.sh` – replace secret across same set of repos.

Examples:
```bash
./scripts/seed-automerge-secret.sh --dry-run
./scripts/seed-automerge-secret.sh --match service-
./scripts/rotate-automerge-secret.sh --match lib-
```

Both scripts prompt securely (hidden input) if env vars are not set. They never write the PAT to disk.

#### Why Not a GitHub App (Yet)?
For a solo workflow, a single PAT is simpler than maintaining private keys and installation IDs. You can migrate later if you want fine-grained app permissions or cross-account distribution.

#### Reusable Workflow Secret Behavior
Secrets always come from the calling repository context. This reusable workflow declares `AUTOMERGE_PAT` as required; it does not expose or share secrets outward.

### Example: Disable label requirement

If you trust all Dependabot PRs and want to auto-merge without the label:

```yaml
jobs:
  automerge:
    uses: xaoscience/github-workflows/.github/workflows/dependabot-automerge-reusable/dependabot-automerge-reusable.yml@main
    secrets:
      AUTOMERGE_PAT: ${{ secrets.AUTOMERGE_PAT }}
    with:
      require_label: false
```
