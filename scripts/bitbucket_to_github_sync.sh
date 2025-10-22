#!/bin/bash
set -e

# ===== CONFIGURATION =====
BITBUCKET_REPO="https://x-token-auth:${BITBUCKET_TOKEN}@bitbucket.org/cisconian/sample-project.git"
GITHUB_REPO="https://x-access-token:${GITHUB_TOKEN}@github.com/AmeyGirkar/bitbucket-mirroring-test.git"
WORK_DIR="/tmp/repo_sync"
SLEEP_INTERVAL=120  # seconds (2 minutes between syncs)

# ===== SETUP =====
#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-/tmp/sync}"
BITBUCKET_REPO="${BITBUCKET_REPO:?BITBUCKET_REPO must be set}"
GITHUB_REPO="${GITHUB_REPO:?GITHUB_REPO must be set}"
SLEEP_INTERVAL="${SLEEP_INTERVAL:-120}"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# ===== CONTINUOUS SYNC LOOP =====
while true; do
    if [ ! -d "$WORK_DIR/repo" ]; then
        echo "[INIT] Cloning Bitbucket repository..."
        git clone --mirror "$BITBUCKET_REPO" repo
        cd repo
        echo "[INIT] Pushing initial mirror to GitHub..."
        git push --mirror "$GITHUB_REPO"
        cd "$WORK_DIR"
    else
        cd repo
        echo "[SYNC] Fetching latest changes from Bitbucket..."
        # update all remotes, tags and prune deleted refs
        git fetch --all --prune --tags

        # Detect default branch on the Bitbucket remote (origin)
        BB_DEFAULT=$(git remote show origin | sed -n 's/.*HEAD branch: //p' || true)
        BB_DEFAULT="${BB_DEFAULT:-main}"
        echo "[SYNC] Detected Bitbucket default branch: $BB_DEFAULT"

        # Local hash (as fetched from origin)
        BITBUCKET_HASH=$(git rev-parse --verify "refs/remotes/origin/$BB_DEFAULT" 2>/dev/null || echo "")
        if [ -z "$BITBUCKET_HASH" ]; then
            echo "[WARN] Could not resolve refs/remotes/origin/$BB_DEFAULT. Falling back to checking any refs."
            # When the default branch isn't present in the bare mirror, use latest ref list fingerprint
            BITBUCKET_HASH=$(git for-each-ref --format='%(objectname) %(refname)' | sha1sum | awk '{print $1}')
        fi

        # Remote hash on GitHub for the same branch name (may be empty if branch doesn't exist yet)
        GITHUB_HASH=$(git ls-remote "$GITHUB_REPO" "refs/heads/$BB_DEFAULT" 2>/dev/null | awk '{print $1}' || echo "")
        if [ -z "$GITHUB_HASH" ]; then
            echo "[SYNC] Branch $BB_DEFAULT does not exist on GitHub or could not be resolved."
        else
            echo "[SYNC] GitHub $BB_DEFAULT hash: $GITHUB_HASH"
        fi

        if [ "$BITBUCKET_HASH" != "$GITHUB_HASH" ]; then
            echo "[SYNC] New changes detected in Bitbucket (or branch mismatch). Pushing mirror to GitHub..."
            # Push everything (refs and tags). --mirror ensures exact mirror.
            git push --mirror "$GITHUB_REPO"
            echo "[SYNC] Push completed ✅"
        else
            echo "[SYNC] No new changes found."
        fi

        cd "$WORK_DIR"
    fi

    echo "[WAIT] Sleeping for $SLEEP_INTERVAL seconds before next check..."
    sleep "$SLEEP_INTERVAL"
done
