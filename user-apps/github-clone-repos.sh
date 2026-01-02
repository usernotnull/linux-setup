#!/bin/bash
#==============================================================================
# DESCRIPTION: Clones a list of Git repositories into a specified directory.
#              Skips repositories that already exist and are not empty.
#
# USAGE:       ./git-downloader.sh [base_directory]
#
# REQUIREMENTS:
#   - git
#   - Internet connection
#   - SSH keys configured for GitHub
#
# NOTES:
#   - Defaults to $HOME/GitHub if no directory is provided.
#   - Set DRY_RUN=true to preview actions without cloning.
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
# Default base directory for cloning
DEFAULT_BASE_DIR="$HOME/GitHub"

# List of repositories to clone
# Using an array allows for easy expansion and handling of spaces in URLs if necessary
GIT_REPOS=(
    "git@github.com:usernotnull/coding.git"
    "git@github.com:usernotnull/linux-setup.git"
    "git@github.com:usernotnull/vaults.git"
)

DRY_RUN=false  # Set to true for testing

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/../" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
    exit 1
fi

# Define script-specific icons
ICON_GIT="🐙"
ICON_SKIP="⏭️"
ICON_DOWN="📥"

# === HEADER ===
hr
log "$ICON_START" "Git Repository Downloader"
if [ "$DRY_RUN" = true ]; then
    warn "DRY RUN MODE - No repositories will be cloned"
fi
hr
echo

# === VALIDATIONS ===
# Check for git availability
command -v git >/dev/null 2>&1 || die "git command not found. Please install git."

# === USER INPUT & SETUP ===
# Allow passing directory as argument, or prompt user with default
if [ -n "${1:-}" ]; then
    TARGET_BASE="$1"
else
    # Interactive prompt pattern from guidelines
    read -r -p "Enter the target directory [default: $DEFAULT_BASE_DIR]: " input_dir
    TARGET_BASE="${input_dir:-$DEFAULT_BASE_DIR}"
fi

# Expand tilde and resolve to absolute path
TARGET_BASE="${TARGET_BASE/#\~/$HOME}"
TARGET_BASE="$(cd "$(dirname "$TARGET_BASE")" 2>/dev/null && pwd)/$(basename "$TARGET_BASE")" || TARGET_BASE="$TARGET_BASE"

# Create base directory if it doesn't exist
if [ ! -d "$TARGET_BASE" ]; then
    if [ "$DRY_RUN" = true ]; then
        log "$ICON_FOLDER" "Would create directory: $TARGET_BASE"
    else
        read -r -p "Directory does not exist. Create $TARGET_BASE? [Y/n]: " create_choice
        create_choice="${create_choice:-Y}"
        if [[ "$create_choice" =~ ^[Yy] ]]; then
            mkdir -p "$TARGET_BASE" || die "Failed to create directory: $TARGET_BASE"
            success "$ICON_FOLDER" "Created directory: $TARGET_BASE"
        else
            die "Cannot proceed without target directory"
        fi
    fi
fi

info "$ICON_FOLDER" "Target location: $TARGET_BASE"
info "$ICON_GIT" "Repositories to process: ${#GIT_REPOS[@]}"
echo

# === MAIN LOGIC ===

# Trap SIGINT for graceful exit during network operations
trap 'echo; warn "Interrupted by user after processing $total_cloned/$((total_cloned + total_skipped)) repos"; exit 130' INT

total_cloned=0
total_skipped=0
total_failed=0
repo_count=0

for repo_url in "${GIT_REPOS[@]}"; do
    repo_count=$((repo_count + 1))

    # Extract repo name (e.g., 'coding' from '.../coding.git')
    # Using bash string manipulation instead of sed for performance/safety
    repo_name=$(basename "$repo_url" .git)

    clone_dir="$TARGET_BASE/$repo_name"

    # Progress indicator
    printf "${CYAN}[%d/%d]${NC} Processing: %s\n" "$repo_count" "${#GIT_REPOS[@]}" "$repo_name"

    # Check if directory exists
    if [ -d "$clone_dir" ]; then
        # Check if directory is empty
        # Using ls -A is safer than grep in set -e context for checking emptiness
        if [ -n "$(ls -A "$clone_dir" 2>/dev/null)" ]; then
            # Directory exists and is NOT empty - check if it's a git repo
            if [ -d "$clone_dir/.git" ]; then
                info "$ICON_SKIP" "Skipping $repo_name: Git repository already exists"
            else
                info "$ICON_SKIP" "Skipping $repo_name: Directory exists but is not a git repository"
            fi
            total_skipped=$((total_skipped + 1))
            continue
        else
            # Directory exists but is empty - we can clone into it
            warn "Directory exists but is empty: $clone_dir"
        fi
    fi

    # Perform Clone
    if [ "$DRY_RUN" = true ]; then
        log "$ICON_DOWN" "Would clone $repo_name from $repo_url"
        total_cloned=$((total_cloned + 1))
    else
        log "$ICON_DOWN" "Cloning $repo_name..."

        # We use || true logic or if statements to handle potential git errors gracefully
        if git clone --quiet "$repo_url" "$clone_dir" 2>&1; then
            success "$ICON_SUCCESS" "Successfully cloned $repo_name"
            total_cloned=$((total_cloned + 1))
        else
            warn "Failed to clone $repo_name. Check SSH keys, network, or repository access."
            total_failed=$((total_failed + 1))
            # We don't 'die' here so other repos can still attempt to download
        fi
    fi

    echo  # Blank line between repos for readability

done

# === FOOTER ===
hr
if [ "$DRY_RUN" = true ]; then
    success "$ICON_SUCCESS" "Dry run complete."
    info "📊" "Summary: $total_cloned would be cloned, $total_skipped skipped"
else
    success "$ICON_SUCCESS" "Operation complete."
    info "📊" "Summary: $total_cloned cloned, $total_skipped skipped, $total_failed failed"
fi

# Exit with non-zero if any repos failed to clone (but only in actual run)
if [ "$DRY_RUN" = false ] && [ "$total_failed" -gt 0 ]; then
    exit 1
fi
