#!/bin/bash
#==============================================================================
# DESCRIPTION: Install all NerdFonts from local repository
#
# USAGE:       ./nerd-fonts-install.sh [options]
#              Examples:
#                ./nerd-fonts-install.sh           # Installs all fonts, all variants
#                ./nerd-fonts-install.sh -s        # Installs all fonts, mono variant only
#                ./nerd-fonts-install.sh -p        # Installs all fonts, propo variant only
#
# OPTIONS:
#   -s, --mono     Install only mono variant (single-width glyphs)
#   -p, --propo    Install only proportional variant
#   -a, --all      Install all variants (regular, mono, propo) [default]
#
# REQUIREMENTS:
#   - NerdFonts submodule with patched-fonts directory
#   - fc-cache (optional, for Linux font cache refresh)
#
# NOTES:
#   - Installs ALL fonts found in the patched-fonts directory
#   - Installs to ~/.local/share/fonts/NerdFonts on Linux
#   - Installs to ~/Library/Fonts/NerdFonts on macOS
#   - This may take a while if you have many fonts
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
VARIANT="all"  # Which variant to install: all, mono, propo

# Parse options
while [ $# -gt 0 ]; do
    case "$1" in
        -s|--mono)
            VARIANT="mono"
            shift
            ;;
        -p|--propo)
            VARIANT="propo"
            shift
            ;;
        -a|--all)
            VARIANT="all"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# === HELPER FUNCTIONS ===
if [ -f "$HOME/.bash_utils" ]; then
    source "$HOME/.bash_utils"
else
    # Fallback minimal helpers
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    NC='\033[0m'

    log() { echo -e "${CYAN}$*${NC}"; }
    success() { echo -e "${GREEN}$*${NC}"; }
    warn() { echo -e "${YELLOW}⚠️  $*${NC}" >&2; }
    die() { echo -e "${RED}❌ $*${NC}" >&2; }
    info() { echo -e "${CYAN}$*${NC}"; }
    hr() { echo -e "${BLUE}$(printf '─%.0s' {1..80})${NC}"; }

    ICON_START="🚀"
    ICON_FOLDER="📂"
    ICON_SUCCESS="✅"
fi

ICON_FONT="🔤"
ICON_PACKAGE="📦"
ICON_CHECK="🔍"

# === HEADER ===
hr
log "$ICON_START" "NerdFonts Batch Installer"
info "🎯" "Installing: ALL fonts"
info "📝" "Variant: $VARIANT"
hr
echo

# === VALIDATIONS ===
SHOULD_EXIT=false

# Determine the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NERDFONTS_DIR="$SCRIPT_DIR/nerd-fonts"
PATCHED_FONTS_DIR="$NERDFONTS_DIR"

# Determine target font directory
if [ "$(uname)" = "Darwin" ]; then
    # macOS
    FONT_TARGET_DIR="$HOME/Library/Fonts/NerdFonts"
else
    # Linux
    FONT_TARGET_DIR="$HOME/.local/share/fonts/NerdFonts"
fi

info "$ICON_FOLDER" "Source: $PATCHED_FONTS_DIR"
info "📍" "Target: $FONT_TARGET_DIR"
echo

# Check if the NerdFonts directory exists
if [ ! -d "$NERDFONTS_DIR" ]; then
    die "NerdFonts directory not found at: $NERDFONTS_DIR"
    echo
    warn "Please initialize the submodule with:"
    echo "  git submodule update --init --recursive"
    SHOULD_EXIT=true
fi

if [ "$SHOULD_EXIT" = false ]; then
    # Check if patched-fonts directory exists
    if [ ! -d "$PATCHED_FONTS_DIR" ]; then
        die "patched-fonts directory not found at: $PATCHED_FONTS_DIR"
        echo
        warn "This installer requires fonts to be present in the repository."
        warn "Consider downloading fonts manually from: https://www.nerdfonts.com/font-downloads"
        SHOULD_EXIT=true
    fi
fi

if [ "$SHOULD_EXIT" = false ]; then
    # Count available font families
    font_family_count=$(find "$PATCHED_FONTS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)

    if [ "$font_family_count" -eq 0 ]; then
        die "No font families found in: $PATCHED_FONTS_DIR"
        SHOULD_EXIT=true
    else
        info "$ICON_CHECK" "Found $font_family_count font families to install"
        echo
    fi
fi

if [ "$SHOULD_EXIT" = false ]; then
    # Build find pattern based on variant
    case "$VARIANT" in
        mono)
            FIND_PATTERN="*NerdFontMono*"
            ;;
        propo)
            FIND_PATTERN="*NerdFontPropo*"
            ;;
        all)
            FIND_PATTERN="*NerdFont*"
            ;;
    esac

    # Count total font files that will be installed
    total_font_files=$(find "$PATCHED_FONTS_DIR" -type f \( -iname "${FIND_PATTERN}.ttf" -o -iname "${FIND_PATTERN}.otf" \) | wc -l)

    if [ "$total_font_files" -eq 0 ]; then
        die "No font files found matching pattern: $FIND_PATTERN"
        echo
        warn "Available font files:"
        find "$PATCHED_FONTS_DIR" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -exec basename "{}" \; | head -10
        SHOULD_EXIT=true
    else
        info "📊" "Found $total_font_files font files to install"
        echo
    fi
fi

# === MAIN LOGIC ===
if [ "$SHOULD_EXIT" = false ]; then
    # Confirm installation if large number of fonts
    if [ "$total_font_files" -gt 100 ]; then
        warn "You are about to install $total_font_files font files"
        read -r -p "Continue? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            info "Installation cancelled by user"
            SHOULD_EXIT=true
        fi
        echo
    fi
fi

if [ "$SHOULD_EXIT" = false ]; then
    log "$ICON_PACKAGE" "Installing fonts..."
    echo

    # Create target directory
    if ! mkdir -p "$FONT_TARGET_DIR" 2>/dev/null; then
        die "Failed to create target directory: $FONT_TARGET_DIR"
        SHOULD_EXIT=true
    fi
fi

if [ "$SHOULD_EXIT" = false ]; then
    # Copy font files with progress indication
    installed_count=0
    failed_count=0
    current_family=""

    # Set up trap for Ctrl+C
    trap 'echo; warn "Interrupted by user. Exiting..."; exit 130' INT

    while IFS= read -r -d $'\0' font_file; do
        # Get font family directory name
        font_family=$(basename "$(dirname "$font_file")")

        # Print family header when we encounter a new family
        if [ "$font_family" != "$current_family" ]; then
            current_family="$font_family"
            echo
            log "📁" "Installing: $font_family"
        fi

        font_name=$(basename "$font_file")
        if cp "$font_file" "$FONT_TARGET_DIR/" 2>/dev/null; then
            info "  ✓ $font_name"
            installed_count=$((installed_count + 1))
        else
            warn "  ✗ Failed: $font_name"
            failed_count=$((failed_count + 1))
        fi

        # Show progress every 10 files
        if [ $((installed_count % 10)) -eq 0 ]; then
            printf "\r  Progress: %d/%d files installed..." "$installed_count" "$total_font_files"
        fi
    done < <(find "$PATCHED_FONTS_DIR" -type f \( -iname "${FIND_PATTERN}.ttf" -o -iname "${FIND_PATTERN}.otf" \) -print0 | sort -z)

    echo
    echo

    if [ "$installed_count" -eq 0 ]; then
        die "No fonts were installed"
        SHOULD_EXIT=true
    else
        hr
        success "$ICON_SUCCESS" "Installed $installed_count font file(s)"
        if [ "$failed_count" -gt 0 ]; then
            warn "Failed to install $failed_count font file(s)"
        fi
        hr
    fi
fi

if [ "$SHOULD_EXIT" = false ]; then
    # Refresh font cache (Linux only)
    if command -v fc-cache >/dev/null 2>&1; then
        echo
        log "🔄" "Refreshing font cache..."
        if fc-cache -fv "$FONT_TARGET_DIR" >/dev/null 2>&1; then
            success "✓ Font cache updated"
        else
            warn "Font cache update failed (this is usually not critical)"
        fi
    fi

    echo
    hr
    success "$ICON_SUCCESS" "Installation complete!"
    hr
    echo
    info "$ICON_FONT" "All NerdFonts are now available on your system"
    info "💡" "You may need to restart applications to see the new fonts"

    if [ "$(uname)" = "Darwin" ]; then
        info "🍎" "On macOS, you may need to restart Font Book or your terminal"
    else
        info "🐧" "On Linux, the fonts should be immediately available"
    fi

    echo
    info "📂" "Fonts installed to: $FONT_TARGET_DIR"
fi

# === FOOTER ===
if [ "$SHOULD_EXIT" = true ]; then
    echo
    warn "Installation failed or was cancelled"
    echo
    info "💡" "Press Enter to close this window..."
    read -r
fi
