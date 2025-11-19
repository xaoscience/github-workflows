gh repo list --limit 500 --json name --jq '.[].name' | while read repo; do
  if gh api "repos/$(gh api user -q .login)/$repo/contents/.github/dependabot.yml" >/dev/null 2>&1; then
    echo "$repo"
  fi
done