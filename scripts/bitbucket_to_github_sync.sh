#!/bin/bash
set -e

# ===== CONFIGURATION =====
BITBUCKET_REPO="https://x-token-auth:${BITBUCKET_TOKEN}@bitbucket.org/cisconian/sample-project.git"
GITHUB_REPO="https://x-access-token:${GITHUB_TOKEN}@github.com/AmeyGirkar/bitbucket-mirroring-.git"
WORK_DIR="/tmp/repo_sync"
SLEEP_INTERVAL=120  # seconds (2 minutes between syncs)

# ===== SETUP =====
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# ===== CONTINUOUS SYNC LOOP =====
while true; do
    if [ ! -d "$WORK_DIR/repo" ]; then
        echo "[INIT] Cloning Bitbucket repository..."
        git clone --mirror "$BITBUCKET_REPO" repo
        cd repo
        echo "[INIT] Pushing initial code to GitHub..."
        git push --mirror "$GITHUB_REPO"
        cd "$WORK_DIR"
    else
        cd repo
        echo "[SYNC] Fetching latest changes from Bitbucket..."
        git fetch --all

        # Compare latest commit hashes between Bitbucket and GitHub
        BITBUCKET_HASH=$(git rev-parse refs/remotes/origin/master)
        GITHUB_HASH=$(git ls-remote "$GITHUB_REPO" refs/heads/master | awk '{print $1}')

        if [ "$BITBUCKET_HASH" != "$GITHUB_HASH" ]; then
            echo "[SYNC] New changes detected in Bitbucket. Pushing to GitHub..."
            git push --mirror "$GITHUB_REPO"
            echo "[SYNC] Push completed ✅"
        else
            echo "[SYNC] No new changes found."
        fi

        cd "$WORK_DIR"
    fi

    echo "[WAIT] Sleeping for $SLEEP_INTERVAL seconds before next check..."
    sleep $SLEEP_INTERVAL
done
