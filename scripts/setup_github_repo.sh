#!/usr/bin/env bash
set -euo pipefail

# EdgeBar - Automated GitHub Repository Creator & Pusher
# Usage: ./scripts/setup_github_repo.sh [repo-name] [--public|--private]

REPO_NAME="${1:-EdgeBar}"
VISIBILITY="${2:---public}"

echo "=================================================="
echo "         EdgeBar GitHub Repository Setup          "
echo "=================================================="

# Check for git
if ! command -v git &> /dev/null; then
    echo "❌ Error: 'git' is not installed or not in PATH."
    exit 1
fi

# Check for gh CLI
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI ('gh') is not installed."
    echo "Install it via Homebrew: brew install gh"
    exit 1
fi

# Check GitHub auth status
echo "==> Checking GitHub CLI authentication..."
if ! gh auth status &> /dev/null; then
    echo "⚠️ You are not logged into GitHub CLI."
    echo "==> Starting interactive sign-in with 'gh auth login'..."
    gh auth login
fi

# Ensure git is initialized
if [ ! -d ".git" ]; then
    echo "==> Initializing git repository..."
    git init
    git branch -M main
fi

# Stage and commit if there are uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "==> Creating initial commit..."
    git add .
    git commit -m "Initial commit: EdgeBar native macOS trackpad hardware strips"
fi

# Check if remote origin already exists
if git remote get-url origin &> /dev/null; then
    echo "==> Remote 'origin' already configured: $(git remote get-url origin)"
    echo "==> Pushing code to GitHub..."
    git push -u origin main
else
    echo "==> Creating repository '$REPO_NAME' on GitHub ($VISIBILITY)..."
    gh repo create "$REPO_NAME" "$VISIBILITY" --source=. --remote=origin --push
fi

echo ""
echo "🎉 Successfully published EdgeBar to GitHub!"
gh repo view --web || true
