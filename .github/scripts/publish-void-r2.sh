#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "usage: $0 download|publish" >&2
    exit 2
}

require_env() {
    local name
    for name in "$@"; do
        if [[ -z "${!name:-}" ]]; then
            echo "error: $name is required" >&2
            exit 2
        fi
    done
}

require_env R2_BUCKET R2_ENDPOINT R2_PREFIX REPOSITORY_DIR

aws_r2() {
    aws --endpoint-url "$R2_ENDPOINT" "$@"
}

download() {
    mkdir -p "$REPOSITORY_DIR/current" "$REPOSITORY_DIR/previous-current"

    aws_r2 s3 sync \
        "s3://${R2_BUCKET}/${R2_PREFIX}/current/" \
        "$REPOSITORY_DIR/current/" \
        --only-show-errors

    cp -a "$REPOSITORY_DIR/current/." "$REPOSITORY_DIR/previous-current/"
}

build_manifest() {
    local packages='[]'
    local file filename pkgver name version revision sha size

    for file in "$REPOSITORY_DIR"/current/*.xbps; do
        filename="$(basename "$file")"
        pkgver="$(xbps-uhelper binpkgver "$filename")"
        name="$(xbps-uhelper getpkgname "$pkgver")"
        version="$(xbps-uhelper getpkgversion "$pkgver")"
        revision="$(xbps-uhelper getpkgrevision "$pkgver")"
        version="${version%_"${revision}"}"
        sha="$(sha256sum "$file" | cut -d' ' -f1)"
        size="$(stat -c '%s' "$file")"
        packages="$(jq \
            --arg name "$name" \
            --arg version "$version" \
            --arg revision "$revision" \
            --arg filename "$filename" \
            --arg sha256 "$sha" \
            --argjson size "$size" \
            '. + [{name: $name, version: $version, revision: $revision, filename: $filename, sha256: $sha256, size: $size}]' \
            <<<"$packages")"
    done

    jq -n \
        --arg repository "$R2_PREFIX" \
        --arg source_commit "$SOURCE_COMMIT" \
        --arg published_at "$PUBLISHED_AT" \
        --argjson packages "$packages" \
        '{schema: 1, repository: $repository, source_commit: $source_commit, published_at: $published_at, packages: $packages}' \
        > "$REPOSITORY_DIR/current/manifest.json"
}

verify_immutable_packages() {
    local file previous

    for file in "$REPOSITORY_DIR"/current/*.xbps "$REPOSITORY_DIR"/current/*.sig2; do
        previous="$REPOSITORY_DIR/previous-current/$(basename "$file")"
        if [[ -f "$previous" ]] && ! cmp -s "$previous" "$file"; then
            echo "error: refusing to replace immutable object $(basename "$file")" >&2
            echo "bump the XBPS revision or version before publishing a changed build" >&2
            exit 1
        fi
    done
}

archive_retired() {
    local old filename
    local archive_prefix="archive/${R2_PREFIX}/${PUBLISHED_AT//:/-}"

    shopt -s nullglob
    for old in "$REPOSITORY_DIR"/previous-current/*.xbps "$REPOSITORY_DIR"/previous-current/*.sig2; do
        filename="$(basename "$old")"
        if [[ ! -e "$REPOSITORY_DIR/current/$filename" ]]; then
            aws_r2 s3 cp \
                "$old" \
                "s3://${R2_BUCKET}/${archive_prefix}/${filename}" \
                --cache-control 'private,no-store' \
                --only-show-errors
        fi
    done
}

upload_current() {
    local file filename old

    # Versioned package objects must exist before repodata can reference them.
    for file in "$REPOSITORY_DIR"/current/*.xbps "$REPOSITORY_DIR"/current/*.sig2; do
        filename="$(basename "$file")"
        aws_r2 s3 cp \
            "$file" \
            "s3://${R2_BUCKET}/${R2_PREFIX}/current/${filename}" \
            --cache-control 'public,max-age=31536000,immutable' \
            --only-show-errors
    done

    aws_r2 s3 cp \
        "$REPOSITORY_DIR/current/x86_64-repodata" \
        "s3://${R2_BUCKET}/${R2_PREFIX}/current/x86_64-repodata" \
        --cache-control 'no-cache' \
        --only-show-errors

    # The manifest is the publication marker and is always uploaded last.
    aws_r2 s3 cp \
        "$REPOSITORY_DIR/current/manifest.json" \
        "s3://${R2_BUCKET}/${R2_PREFIX}/current/manifest.json" \
        --cache-control 'no-cache' \
        --only-show-errors

    # Once the new index and marker are live, remove objects no longer referenced.
    shopt -s nullglob
    for old in "$REPOSITORY_DIR"/previous-current/*; do
        filename="$(basename "$old")"
        if [[ ! -e "$REPOSITORY_DIR/current/$filename" ]]; then
            aws_r2 s3 rm \
                "s3://${R2_BUCKET}/${R2_PREFIX}/current/${filename}" \
                --only-show-errors
        fi
    done
}

publish() {
    require_env SOURCE_COMMIT
    PUBLISHED_AT="${PUBLISHED_AT:-$(date -u +'%Y-%m-%dT%H:%M:%SZ')}"
    export PUBLISHED_AT

    shopt -s nullglob
    local packages=("$REPOSITORY_DIR"/current/*.xbps)
    if (( ${#packages[@]} == 0 )); then
        echo "error: refusing to publish an empty XBPS repository" >&2
        exit 1
    fi
    [[ -s "$REPOSITORY_DIR/current/x86_64-repodata" ]] || {
        echo "error: x86_64-repodata is missing or empty" >&2
        exit 1
    }
    for file in "${packages[@]}"; do
        [[ -s "${file}.sig2" ]] || {
            echo "error: signature is missing for $(basename "$file")" >&2
            exit 1
        }
    done

    verify_immutable_packages
    build_manifest
    archive_retired
    upload_current
}

case "${1:-}" in
    download) download ;;
    publish) publish ;;
    *) usage ;;
esac
