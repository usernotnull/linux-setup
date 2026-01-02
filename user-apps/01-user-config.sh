#!/bin/bash
#==============================================================================
# DESCRIPTION: Configure default file associations for media, text, email,
#              and directory handling in KDE/Linux desktop environments
#
# USAGE:       ./setup-mime-associations.sh
#
# REQUIREMENTS:
#   - xdg-utils (xdg-mime, xdg-settings)
#   - gio command (typically from glib2)
#   - /usr/share/mime/types file must exist
#   - Applications: Haruna (media), VS Code (text), Betterbird (email)
#
# NOTES:
#   - Modifies ~/.config/mimeapps.list
#   - Sets system-wide default applications
#   - Requires the target applications to be installed
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
MIME_TYPES_FILE="/usr/share/mime/types"  # System MIME types database
MIMEAPPS_FILE="$HOME/.config/mimeapps.list"  # User MIME associations config
VIDEO_PLAYER="org.kde.haruna.desktop"    # Default video/audio player
TEXT_EDITOR="code.desktop"               # Default text editor
EMAIL_CLIENT="eu.betterbird.Betterbird.desktop"  # Default email client
DIR_HANDLERS="code.desktop;org.kde.haruna.desktop;"  # Apps for opening directories

# === HELPER FUNCTIONS ===
if [ -f "$HOME/.bash_utils" ]; then
    source "$HOME/.bash_utils"
else
    echo "Error: .bash_utils not found!"
    exit 1
fi

ICON_MEDIA="🎬"
ICON_TEXT="📝"
ICON_EMAIL="✉️"
ICON_LINK="🔗"

# === HEADER ===
hr
log "$ICON_START" "Configuring MIME Type Associations"
info "$ICON_MEDIA" "Media player: $VIDEO_PLAYER"
info "$ICON_TEXT" "Text editor: $TEXT_EDITOR"
info "$ICON_EMAIL" "Email client: $EMAIL_CLIENT"
hr
echo

# === VALIDATIONS ===
# Check for required commands
command -v xdg-mime >/dev/null 2>&1 || die "xdg-mime command not found (install xdg-utils)"
command -v xdg-settings >/dev/null 2>&1 || die "xdg-settings command not found (install xdg-utils)"
command -v gio >/dev/null 2>&1 || die "gio command not found (install glib2)"

# Check for MIME types file
[ -f "$MIME_TYPES_FILE" ] || die "MIME types file not found: $MIME_TYPES_FILE"

# Verify applications are installed
for desktop_file in "$VIDEO_PLAYER" "$TEXT_EDITOR" "$EMAIL_CLIENT"; do
    app_name="${desktop_file%.desktop}"
    if ! locate=$(find /usr/share/applications ~/.local/share/applications -name "$desktop_file" 2>/dev/null | head -1); then
        warn "Application not found: $desktop_file"
        warn "Associations will be configured, but application must be installed to work"
    fi
done

# === MAIN LOGIC ===

# 1. Configure Media Files (Audio/Video)
log "$ICON_MEDIA" "Setting media file associations…"
media_count=0
while IFS= read -r mime_type; do
    if xdg-mime default "$VIDEO_PLAYER" "$mime_type" 2>/dev/null; then
        media_count=$((media_count + 1))
    fi
done < <(grep -E '^(audio/|video/)' "$MIME_TYPES_FILE" 2>/dev/null || true)

if [ "$media_count" -gt 0 ]; then
    success "$ICON_MEDIA" "Configured $media_count media file associations"
else
    warn "No media MIME types found or configured"
fi

# 2. Configure Text Files
log "$ICON_TEXT" "Setting text file associations…"
text_count=0
while IFS= read -r mime_type; do
    if xdg-mime default "$TEXT_EDITOR" "$mime_type" 2>/dev/null; then
        text_count=$((text_count + 1))
    fi
done < <(grep -E '^(text/|application/(javascript|json|xml|x-shellscript|x-yaml|x-python|x-php|x-perl|x-ruby))' "$MIME_TYPES_FILE" 2>/dev/null || true)

if [ "$text_count" -gt 0 ]; then
    success "$ICON_TEXT" "Configured $text_count text file associations"
else
    warn "No text MIME types found or configured"
fi

# 3. Configure Email and Calendar (Betterbird)
log "$ICON_EMAIL" "Setting email and calendar associations…"
email_types=(
    "x-scheme-handler/mailto"
    "text/vcard"
    "text/directory"
    "text/calendar"
    "application/ics"
)

email_count=0
for mime_type in "${email_types[@]}"; do
    if gio mime "$mime_type" "$EMAIL_CLIENT" >/dev/null 2>&1; then
        email_count=$((email_count + 1))
    fi
done

# Set mailto URL handler (try multiple methods)
mailto_success=false

# Method 1: xdg-settings (works in some desktop environments)
if xdg-settings set default-url-scheme-handler mailto "$EMAIL_CLIENT" 2>/dev/null; then
    mailto_success=true
fi

# Method 2: xdg-mime (more universal)
if [ "$mailto_success" = false ]; then
    if xdg-mime default "$EMAIL_CLIENT" x-scheme-handler/mailto 2>/dev/null; then
        mailto_success=true
    fi
fi

# Method 3: Direct mimeapps.list modification (fallback)
if [ "$mailto_success" = false ]; then
    if ! grep -q "^\[Default Applications\]" "$MIMEAPPS_FILE" 2>/dev/null; then
        echo -e "\n[Default Applications]" >> "$MIMEAPPS_FILE"
    fi

    mailto_mime="x-scheme-handler/mailto"
    if grep -q "^${mailto_mime}=" "$MIMEAPPS_FILE" 2>/dev/null; then
        sed -i "s|^${mailto_mime}=.*|${mailto_mime}=${EMAIL_CLIENT}|" "$MIMEAPPS_FILE"
    else
        sed -i "/^\[Default Applications\]/a ${mailto_mime}=${EMAIL_CLIENT}" "$MIMEAPPS_FILE"
    fi
    mailto_success=true
fi

if [ "$mailto_success" = true ]; then
    success "$ICON_EMAIL" "Configured email client ($email_count associations + mailto handler)"
else
    warn "Failed to set mailto URL handler (configured $email_count other associations)"
fi

# 4. Configure Directory Handlers
log "$ICON_FOLDER" "Setting directory associations…"

# Create mimeapps.list if it doesn't exist
touch "$MIMEAPPS_FILE" || die "Failed to create/access $MIMEAPPS_FILE"

# Ensure [Added Associations] section exists
if ! grep -q "^\[Added Associations\]" "$MIMEAPPS_FILE" 2>/dev/null; then
    echo -e "\n[Added Associations]" >> "$MIMEAPPS_FILE"
fi

# Add or update directory associations
dir_mime="inode/directory"
if grep -q "^${dir_mime}=" "$MIMEAPPS_FILE" 2>/dev/null; then
    # Line exists - append apps if not already present
    if ! grep "^${dir_mime}=" "$MIMEAPPS_FILE" | grep -q "$DIR_HANDLERS" 2>/dev/null; then
        sed -i "s|^${dir_mime}=.*|&${DIR_HANDLERS}|" "$MIMEAPPS_FILE"
        success "$ICON_FOLDER" "Updated directory associations"
    else
        info "$ICON_FOLDER" "Directory associations already configured"
    fi
else
    # Line doesn't exist - add it under [Added Associations]
    sed -i "/^\[Added Associations\]/a ${dir_mime}=${DIR_HANDLERS}" "$MIMEAPPS_FILE"
    success "$ICON_FOLDER" "Added directory associations"
fi

# Clean up any double semicolons
sed -i 's/;;/;/g' "$MIMEAPPS_FILE"

# === FOOTER ===
echo
hr
success "$ICON_SUCCESS" "MIME type associations configured successfully"
info "$ICON_LINK" "Configuration file: $MIMEAPPS_FILE"
hr
