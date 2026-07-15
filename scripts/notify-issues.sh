#!/usr/bin/env bash
# Comment on open issues referenced by commits shipped in a release,
# asking reporters to retest.
#
# Usage: notify-issues.sh <prev-tag> <tag> [--dry-run]
#
# Scans commit messages in <prev-tag>..<tag> for "related/fixes/closes/
# resolves/ref #N", keeps refs that are open issues (PRs and closed issues
# are skipped), and posts one comment per issue linking the release.
# Re-runs are safe: issues already carrying a comment that mentions the
# tag are skipped. Requires gh auth (GH_TOKEN).
set -euo pipefail

PREV="${1:?usage: notify-issues.sh <prev-tag> <tag> [--dry-run]}"
TAG="${2:?usage: notify-issues.sh <prev-tag> <tag> [--dry-run]}"
DRY=0
[ "${3:-}" = "--dry-run" ] && DRY=1

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
RELEASE_URL="https://github.com/${REPO}/releases/tag/${TAG}"

# Allow "related #N", "related: #N", "fixes #N", "Closes #N", etc.
refs=$(git log --no-merges --format=%B "${PREV}..${TAG}" |
  { grep -oiE '(related([ -]to)?|ref(erence[sd]?)?|fix(es|ed)?|close[sd]?|resolve[sd]?|see)[-: ]*#[0-9]+' || true; } |
  grep -oE '[0-9]+' | sort -un)

[ -n "$refs" ] || { echo "no issue references found in ${PREV}..${TAG}"; exit 0; }

for n in $refs; do
  info=$(gh api "repos/${REPO}/issues/${n}" \
    --jq '{state: .state, pr: (.pull_request != null), title: .title}' 2>/dev/null) || {
    echo "skip #${n}: not found"; continue; }
  [ "$(jq -r .pr <<<"$info")" = "false" ] || { echo "skip #${n}: is a PR"; continue; }
  [ "$(jq -r .state <<<"$info")" = "open" ] || { echo "skip #${n}: closed"; continue; }

  # don't double-post if a comment for this tag already exists
  if gh api "repos/${REPO}/issues/${n}/comments" --paginate \
      --jq ".[].body" 2>/dev/null | grep -q "$TAG"; then
    echo "skip #${n}: already notified for ${TAG}"
    continue
  fi

  title=$(jq -r .title <<<"$info")
  if [ "$DRY" = 1 ]; then
    echo "DRY-RUN: would comment on #${n} — ${title}"
    continue
  fi
  gh issue comment "$n" --repo "$REPO" --body "$(cat <<EOF
:package: A fix referencing this issue shipped in [**${TAG}**](${RELEASE_URL}).

A New Release has been deployed! Please retest when you get a chance. If it's resolved, this issue can be closed. ~ Cheers, the DMS Team!
EOF
)"
  echo "notified #${n} — ${title}"
done
