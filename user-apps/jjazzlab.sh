#!/bin/bash
#==============================================================================
# DESCRIPTION: Installs or updates JJazzLab backing track generator
#
# USAGE:       ./install-jjazzlab.sh
#
# REQUIREMENTS:
#   - curl or wget for downloading
#   - dpkg for checking installed version
#   - apt-get for installation
#   - Internet connection
#
# NOTES:
#   - Automatically detects system architecture (amd64, arm64, etc.)
#   - Compares installed version with latest GitHub release
#   - Skips installation if already up-to-date
#   - Downloads appropriate .deb package for your architecture
#   - FluidSynth (>=2.2.0) will be automatically installed if needed
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
GITHUB_REPO="jjazzboss/JJazzLab"                    # GitHub repository
DOWNLOAD_DIR="/tmp/jjazzlab_install"                # Temporary download directory
PACKAGE_NAME="jjazzlab"                             # Package name for version checking

# === HELPER FUNCTIONS ===
if [ -f "$HOME/.bash_utils" ]; then
    source "$HOME/.bash_utils"
else
    echo "Error: .bash_utils not found!"
    exit 1
fi

ICON_DOWNLOAD="⬇️"
ICON_CHECK="🔍"
ICON_PACKAGE="📦"
ICON_VERSION="🏷️"
ICON_SKIP="⏭️"
ICON_INSTALL="🚀"
ICON_WARN="⚠️"

# === HEADER ===
hr
log "$ICON_START" "JJazzLab Installer"
info "$ICON_PACKAGE" "Repository: $GITHUB_REPO"
hr
echo

# === VALIDATIONS ===
printf "Install $PACKAGE_NAME? [y/N]: "
read -r confirm
echo

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    log "$ICON_WARN" "Restore cancelled by user"
    exit 0
fi

log "$ICON_CHECK" "Checking system requirements..."

# Check for required commands
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    die "Neither curl nor wget found. Please install one of them."
fi

if ! command -v dpkg >/dev/null 2>&1; then
    die "dpkg not found. This script only works on Debian-based systems."
fi

if ! command -v apt-get >/dev/null 2>&1; then
    die "apt-get not found. This script requires apt-get for installation."
fi

success "$ICON_SUCCESS" "System requirements met"
echo

# Detect architecture
ARCH=$(dpkg --print-architecture)
log "$ICON_CHECK" "Detected architecture: $ARCH"
echo

# === GET INSTALLED VERSION ===
log "$ICON_VERSION" "Checking installed version..."

if dpkg -l | grep "^ii" | grep "$PACKAGE_NAME" > /dev/null 2>&1; then
    INSTALLED_VERSION=$(dpkg -l | grep "^ii" | grep "$PACKAGE_NAME" | awk '{print $3}' | head -n1)
    # Remove the -1 suffix and any other suffixes from version
    INSTALLED_VERSION_CLEAN=$(echo "$INSTALLED_VERSION" | sed 's/-[0-9]*$//')
    info "$ICON_VERSION" "Currently installed: v$INSTALLED_VERSION_CLEAN"
else
    INSTALLED_VERSION_CLEAN=""
    info "$ICON_VERSION" "JJazzLab is not currently installed"
fi
echo

# === FETCH LATEST RELEASE ===
log "$ICON_DOWNLOAD" "Fetching latest release information from GitHub..."

# Use curl or wget to get latest release info
if command -v curl >/dev/null 2>&1; then
    RELEASES_JSON=$(curl -fsSL "https://api.github.com/repos/$GITHUB_REPO/releases")
else
    RELEASES_JSON=$(wget -q --show-progress -O- "https://api.github.com/repos/$GITHUB_REPO/releases")
fi

# Parse releases to find the latest one with assets for our architecture
LATEST_VERSION=""
DOWNLOAD_URL=""

# Extract version tags and asset URLs
while IFS= read -r line; do
    if [[ "$line" =~ \"tag_name\":[[:space:]]*\"([^\"]+)\" ]]; then
        VERSION="${BASH_REMATCH[1]}"
        continue
    fi

    if [[ "$line" =~ \"browser_download_url\":[[:space:]]*\"([^\"]+${PACKAGE_NAME}_[^_]+_${ARCH}\.deb)\" ]]; then
        URL="${BASH_REMATCH[1]}"

        # Only accept if we haven't found a version yet (first match is latest)
        if [ -z "$LATEST_VERSION" ]; then
            LATEST_VERSION="$VERSION"
            DOWNLOAD_URL="$URL"
            break
        fi
    fi
done <<< "$RELEASES_JSON"

# Validate we found a release
if [ -z "$LATEST_VERSION" ] || [ -z "$DOWNLOAD_URL" ]; then
    die "Could not find a suitable release for architecture: $ARCH"
fi

success "$ICON_VERSION" "Latest version available: $LATEST_VERSION"
echo

# === VERSION COMPARISON ===
NEEDS_INSTALLATION=true

if [ -n "$INSTALLED_VERSION_CLEAN" ]; then
    if [ "$INSTALLED_VERSION_CLEAN" = "$LATEST_VERSION" ]; then
        success "$ICON_SKIP" "JJazzLab is already up-to-date (v$LATEST_VERSION)"
        NEEDS_INSTALLATION=false
    else
        log "$ICON_INSTALL" "Update available: v$INSTALLED_VERSION_CLEAN → $LATEST_VERSION"
    fi
else
    log "$ICON_INSTALL" "Preparing to install JJazzLab $LATEST_VERSION"
fi
echo

if [ "$NEEDS_INSTALLATION" = true ]; then
    # === DOWNLOAD ===
    log "$ICON_DOWNLOAD" "Downloading JJazzLab $LATEST_VERSION..."

    # Create download directory
    mkdir -p "$DOWNLOAD_DIR"

    # Extract filename from URL
    FILENAME=$(basename "$DOWNLOAD_URL")
    FILEPATH="$DOWNLOAD_DIR/$FILENAME"

    # Download the file
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL -o "$FILEPATH" "$DOWNLOAD_URL"; then
            success "$ICON_DOWNLOAD" "Downloaded: $FILENAME"
        else
            die "Failed to download package"
        fi
    else
        if wget -q --show-progress -O "$FILEPATH" "$DOWNLOAD_URL"; then
            success "$ICON_DOWNLOAD" "Downloaded: $FILENAME"
        else
            die "Failed to download package"
        fi
    fi
    echo

    # === INSTALLATION ===
    log "$ICON_INSTALL" "Installing JJazzLab..."
    info "$ICON_PACKAGE" "This will also install FluidSynth (>=2.2.0) if needed"
    echo

    # Install the package
    if sudo apt-get install -y "$FILEPATH"; then
        success "$ICON_SUCCESS" "Successfully installed JJazzLab $LATEST_VERSION"
    else
        die "Installation failed"
    fi
    echo

    # === CLEANUP ===
    log "$ICON_CLEAN" "Cleaning up temporary files..."
    rm -f "$FILEPATH"
    if [ -d "$DOWNLOAD_DIR" ] && [ -z "$(ls -A "$DOWNLOAD_DIR")" ]; then
        rmdir "$DOWNLOAD_DIR"
    fi
    success "$ICON_CLEAN" "Cleanup complete"
    echo
fi

# === DESKTOP SHORTCUT CONFIGURATION ===
log "$ICON_PACKAGE" "Configuring desktop shortcut and file associations..."

DESKTOP_FILE="/usr/share/applications/jjazzlab.desktop"

if [ -f "$DESKTOP_FILE" ]; then
    # Create a temporary file for the updated desktop entry
    TEMP_DESKTOP=$(mktemp)

    # Custom MIME types for JJazzLab
    BIAB_MIME_TYPE="application/x-band-in-a-box"                    # Band-in-a-Box files (.sgu/.mgu)
    IMPROVISOR_MIME_TYPE="application/x-impro-visor"                # Impro-Visor files (.ls)
    MUSICXML_MIME_TYPE="application/vnd.recordare.musicxml+xml"     # MusicXML (.mxl/.musicxml)

    # Read the existing desktop file and update it
    while IFS= read -r line; do
        if [[ "$line" =~ ^Exec= ]]; then
            echo "Exec=/usr/bin/jjazzlab %f"
        elif [[ "$line" =~ ^MimeType= ]]; then
            # Append our MIME types to existing ones if any
            existing_mimes=$(echo "$line" | sed 's/^MimeType=//')
            # Remove trailing semicolon if present
            existing_mimes=$(echo "$existing_mimes" | sed 's/;$//')

            # Build new MIME type list
            new_mimes="$existing_mimes"
            for mime in "$BIAB_MIME_TYPE" "$IMPROVISOR_MIME_TYPE" "$MUSICXML_MIME_TYPE"; do
                if [[ ! "$existing_mimes" =~ $mime ]]; then
                    if [ -n "$new_mimes" ]; then
                        new_mimes="$new_mimes;$mime"
                    else
                        new_mimes="$mime"
                    fi
                fi
            done
            echo "MimeType=$new_mimes;"
        else
            echo "$line"
        fi
    done < "$DESKTOP_FILE" > "$TEMP_DESKTOP"

    # Check if MimeType line exists, if not add it before the last line
    if ! grep -q "^MimeType=" "$TEMP_DESKTOP"; then
        # Insert MimeType line before the last line
        sed -i "\$i MimeType=$BIAB_MIME_TYPE;$IMPROVISOR_MIME_TYPE;$MUSICXML_MIME_TYPE;" "$TEMP_DESKTOP"
    fi

    # Replace the original desktop file
    if sudo cp "$TEMP_DESKTOP" "$DESKTOP_FILE"; then
        success "$ICON_PACKAGE" "Updated desktop shortcut with file associations"
    else
        warn "Failed to update desktop shortcut"
    fi

    rm -f "$TEMP_DESKTOP"

    # Update desktop database to recognize new MIME types
    if command -v update-desktop-database >/dev/null 2>&1; then
        sudo update-desktop-database /usr/share/applications/ 2>/dev/null || true
        success "$ICON_PACKAGE" "Desktop database updated"
    fi

    # Update MIME database if available
    if command -v update-mime-database >/dev/null 2>&1; then
        sudo update-mime-database /usr/share/mime/ 2>/dev/null || true
    fi
else
    warn "Desktop file not found at $DESKTOP_FILE"
    info "💡" "You may need to create it manually"
fi
echo

# === FOOTER ===
hr
success "$ICON_SUCCESS" "JJazzLab installation complete!"
info "🎵" "Supported file types:"
info "   " "• Band-in-a-Box (.sgu, .mgu)"
info "   " "• Impro-Visor (.ls)"
info "   " "• MusicXML (.mxl, .musicxml)"
hr
