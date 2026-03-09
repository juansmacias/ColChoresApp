#!/bin/sh
# Installs the pre-commit hook into .git/hooks/.
# Run once after cloning: sh scripts/setup_hooks.sh

cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
echo "Pre-commit hook installed successfully."
