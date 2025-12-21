#!/bin/bash
# Runs as non-root user.

set -euo pipefail

# --- CONFIGURATION ---

# 1. Define the array of repository SSH URLs.
git_repos=(
    "git@github.com:usernotnull/coding.git"
    # "git@github.com:usernotnull/dotfiles.git"
    "git@github.com:usernotnull/linux-setup.git"
    "git@github.com:usernotnull/vaults.git"
)

# Define the default base directory for cloning.
# All repos will default to being cloned inside: $default_base_dir/REPO_NAME
default_base_dir="$HOME/GitHub"

# --- SCRIPT START ---

echo "--- Git Repository Downloader Script ---"
echo "Total repositories to process: ${#git_repos[@]}"
echo "Default parent location: $default_base_dir"
echo "----------------------------------------"

# Ensure the default base directory exists
mkdir -p "$default_base_dir"

# Loop through each repository URL defined in the array
for repo_url in "${git_repos[@]}"; do

    # 1. Extract the clean repository name (e.g., 'coding' from the URL)
    # This sed command strips the user/host part and the .git extension.
    repo_name=$(echo "$repo_url" | sed -E 's/.*[:/]([^/]+)\.git$/\1/')

    # 2. Determine the full clone path using the default base directory
    clone_dir="$default_base_dir/$repo_name"

    echo ""
    echo "--> Processing repository: $repo_name (URL: $repo_url)"

    # 3. Check the state of the target directory

    if [[ -d "$clone_dir" ]]; then
        # Directory exists. Now check if it's NOT empty (find depth 1 skips . and ..)
        # We redirect errors (2>/dev/null) in case of permissions issues.
        if find "$clone_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
            # Directory exists and is NOT empty (contains files/folders)
            echo "   [SKIP] Directory '$clone_dir' exists and is NOT empty."
            echo "          To update this repo, run 'git fetch --quiet' or 'git pull --quiet' inside it."
            continue # Skip to the next repository in the loop
        else
            # Directory exists but IS empty. We can proceed with clone.
            echo "   [INFO] Directory '$clone_dir' exists but is EMPTY. Proceeding with clone."
            # Ensure the parent directory exists before cloning
            mkdir -p "$(dirname "$clone_dir")"

            echo "   Cloning into: $clone_dir..."
            # git clone with --quiet
            if git clone --quiet "$repo_url" "$clone_dir"; then
                echo "   [SUCCESS] Cloned $repo_name successfully."
            else
                echo "   [ERROR] Failed to clone $repo_name. Check SSH keys and network connectivity."
            fi
        fi
    else
        # Directory does not exist. Proceed with cloning.
        echo "   [INFO] Target directory '$clone_dir' does not exist. Creating and cloning..."

        # Ensure the parent directory exists before cloning
        mkdir -p "$(dirname "$clone_dir")"

        # git clone with --quiet
        if git clone --quiet "$repo_url" "$clone_dir"; then
            echo "   [SUCCESS] Cloned $repo_name successfully."
        else
            echo "   [ERROR] Failed to clone $repo_name. Check SSH keys and network connectivity."
        fi
    fi
done

echo ""
echo "--- Script execution complete. ---"
