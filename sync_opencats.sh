#!/bin/bash

REPO_DIR="/home/nour/Desktop/myFiles/IBC/official"
SOURCE_DIR="/var/www/html/opencats"

echo "Syncing from $SOURCE_DIR to $REPO_DIR..."

# Delete everything except .git and this script
find "$REPO_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' ! -name 'sync_opencats.sh' -exec rm -rf {} +

echo "Cleared repo folder."

# Copy opencats contents excluding .git
rsync -a --exclude='.git' "$SOURCE_DIR"/ "$REPO_DIR"/

echo "Done. Now run: git add . && git commit -m 'your message' && git push"
