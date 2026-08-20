#!/usr/bin/env bash
# Prunes retired XBPS packages from the R2 bucket so it stays inside the
# Cloudflare free tier. Only objects under ARCHIVE_PREFIX are eligible; live
# repositories (<repo>/current/) are never touched.
#
# publish-void-r2.sh writes retired packages to archive/<repo>/<published_at>/.
# Snapshots are dropped oldest first:
#   1. snapshots older than KEEP_DAYS, keeping KEEP_MIN_SNAPSHOTS per repo
#   2. then more until the whole bucket is <= MAX_BUCKET_GB

set -euo pipefail

require_env() {
    local name
    for name in "$@"; do
        if [[ -z "${!name:-}" ]]; then
            echo "error: $name is required" >&2
            exit 2
        fi
    done
}

require_env R2_BUCKET R2_ENDPOINT

ARCHIVE_PREFIX="${ARCHIVE_PREFIX:-archive/}"
MAX_BUCKET_GB="${MAX_BUCKET_GB:-8}"
KEEP_DAYS="${KEEP_DAYS:-30}"
KEEP_MIN_SNAPSHOTS="${KEEP_MIN_SNAPSHOTS:-2}"
DRY_RUN="${DRY_RUN:-false}"

case "$ARCHIVE_PREFIX" in
    */) ;;
    *) echo "error: ARCHIVE_PREFIX must end with /" >&2; exit 2 ;;
esac

aws_r2() {
    aws --endpoint-url "$R2_ENDPOINT" "$@"
}

human() {
    numfmt --to=iec-i --suffix=B "$1"
}

objects="$(aws_r2 s3api list-objects-v2 \
    --bucket "$R2_BUCKET" \
    --output json \
    --query 'Contents[].{key:Key,size:Size}')"
[[ -n "$objects" && "$objects" != null ]] || objects='[]'

total="$(jq 'map(.size) | add // 0' <<<"$objects")"
budget="$(awk -v g="$MAX_BUCKET_GB" 'BEGIN { printf "%d", g * 1073741824 }')"
now="$(date -u +%s)"

snapshots="$(jq -c --arg p "$ARCHIVE_PREFIX" '
    map(select(.key | startswith($p)))
    | map(.rel = (.key[($p | length):] | split("/")))
    | map(select((.rel | length) >= 3))
    | group_by(.rel[0:2])
    | map({
        repo: .[0].rel[0],
        stamp: .[0].rel[1],
        prefix: ($p + (.[0].rel[0:2] | join("/")) + "/"),
        size: (map(.size) | add),
        count: length
      })
    | sort_by(.stamp)
' <<<"$objects")"

to_delete="$(jq -c \
    --argjson now "$now" \
    --argjson keepDays "$KEEP_DAYS" \
    --argjson keepMin "$KEEP_MIN_SNAPSHOTS" \
    --argjson total "$total" \
    --argjson budget "$budget" '
    def epoch:
        .stamp
        | sub("T(?<h>[0-9]{2})-(?<m>[0-9]{2})-(?<s>[0-9]{2})Z$"; "T\(.h):\(.m):\(.s)Z")
        | try fromdateiso8601 catch null;
    (group_by(.repo) | map({key: .[0].repo, value: length}) | from_entries) as $perRepo
    | reduce .[] as $s ({kept: $perRepo, total: $total, delete: []};
        ($s | epoch) as $e
        | (.kept[$s.repo] > $keepMin and $e != null and ($now - $e) > $keepDays * 86400) as $expired
        | (.total > $budget) as $over
        | if $expired or $over then
            .delete += [$s + {reason: (if $over then "budget" else "age" end)}]
            | .total -= $s.size
            | .kept[$s.repo] -= 1
          else . end)
    | .delete
' <<<"$snapshots")"

echo "bucket:    $R2_BUCKET ($(human "$total") in $(jq length <<<"$objects") objects)"
echo "budget:    $(human "$budget") (MAX_BUCKET_GB=$MAX_BUCKET_GB)"
echo "archive:   $(jq length <<<"$snapshots") snapshots, $(human "$(jq 'map(.size) | add // 0' <<<"$snapshots")")"
echo "policy:    KEEP_DAYS=$KEEP_DAYS KEEP_MIN_SNAPSHOTS=$KEEP_MIN_SNAPSHOTS DRY_RUN=$DRY_RUN"

deleted=0
freed=0
while IFS=$'\t' read -r prefix size count reason; do
    [[ -n "$prefix" ]] || continue
    # Belt and braces: never delete outside the archive or anything live.
    case "$prefix" in
        "$ARCHIVE_PREFIX"*) ;;
        *) echo "error: refusing to delete $prefix (outside $ARCHIVE_PREFIX)" >&2; exit 1 ;;
    esac
    case "$prefix" in
        */current/*) echo "error: refusing to delete live prefix $prefix" >&2; exit 1 ;;
    esac

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "would delete $prefix ($count objects, $(human "$size"), $reason)"
    else
        echo "deleting $prefix ($count objects, $(human "$size"), $reason)"
        aws_r2 s3 rm "s3://${R2_BUCKET}/${prefix}" --recursive --only-show-errors
    fi
    deleted=$((deleted + 1))
    freed=$((freed + size))
done < <(jq -r '.[] | [.prefix, .size, .count, .reason] | @tsv' <<<"$to_delete")

remaining=$((total - freed))
echo "pruned:    $deleted snapshots, $(human "$freed") freed, $(human "$remaining") remaining"

if (( remaining > budget )); then
    echo "::warning::bucket is still $(human "$remaining") after pruning (budget $(human "$budget")); live repositories exceed the budget"
fi

note=""
if [[ "$DRY_RUN" == "true" ]]; then
    note=" (dry run)"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        echo "### R2 prune: \`$R2_BUCKET\`"
        echo
        echo "| | |"
        echo "|---|---|"
        echo "| Before | $(human "$total") |"
        echo "| Budget | $(human "$budget") |"
        echo "| Snapshots pruned | $deleted$note |"
        echo "| Freed | $(human "$freed") |"
        echo "| After | $(human "$remaining") |"
        if (( deleted > 0 )); then
            echo
            echo "| Snapshot | Objects | Bytes | Reason |"
            echo "|---|---|---|---|"
            jq -r '.[] | "| `\(.prefix)` | \(.count) | \(.size) | \(.reason) |"' <<<"$to_delete"
        fi
    } >> "$GITHUB_STEP_SUMMARY"
fi
