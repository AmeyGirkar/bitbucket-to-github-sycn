#!/bin/bash
set -euo pipefail

# ===== CONFIGURATION =====
WORK_DIR="${WORK_DIR:-/tmp/sync}"
BITBUCKET_REPO="${BITBUCKET_REPO:?BITBUCKET_REPO must be set}"
GITHUB_REPO="${GITHUB_REPO:?GITHUB_REPO must be set}"
SLEEP_INTERVAL=20  # seconds
ITERATIONS=5        # number of sync iterations

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# ===== SYNC LOOP =====
for ((i=1; i<=ITERATIONS; i++)); do
    echo "=== SYNC ITERATION $i/$ITERATIONS ==="
    
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
        git fetch --all --prune --tags

        BB_DEFAULT=$(git remote show origin | sed -n 's/.*HEAD branch: //p' || true)
        BB_DEFAULT="${BB_DEFAULT:-main}"
        echo "[SYNC] Detected Bitbucket default branch: $BB_DEFAULT"

        BITBUCKET_HASH=$(git rev-parse --verify "refs/remotes/origin/$BB_DEFAULT" 2>/dev/null || echo "")
        if [ -z "$BITBUCKET_HASH" ]; then
            echo "[WARN] Could not resolve refs/remotes/origin/$BB_DEFAULT. Using latest ref fingerprint."
            BITBUCKET_HASH=$(git for-each-ref --format='%(objectname) %(refname)' | sha1sum | awk '{print $1}')
        fi

        GITHUB_HASH=$(git ls-remote "$GITHUB_REPO" "refs/heads/$BB_DEFAULT" 2>/dev/null | awk '{print $1}' || echo "")
        if [ -z "$GITHUB_HASH" ]; then
            echo "[SYNC] Branch $BB_DEFAULT does not exist on GitHub or could not be resolved."
        else
            echo "[SYNC] GitHub $BB_DEFAULT hash: $GITHUB_HASH"
        fi

        if [ "$BITBUCKET_HASH" != "$GITHUB_HASH" ]; then
            echo "[SYNC] New changes detected in Bitbucket. Pushing mirror to GitHub..."
            git push --mirror "$GITHUB_REPO"
            echo "[SYNC] Push completed ✅"
        else
            echo "[SYNC] No new changes found."
        fi

        cd "$WORK_DIR"
    fi

    echo "[WAIT] Sleeping for $SLEEP_INTERVAL seconds before next iteration..."
    sleep "$SLEEP_INTERVAL"
done

echo "=== SYNC COMPLETE ==="
