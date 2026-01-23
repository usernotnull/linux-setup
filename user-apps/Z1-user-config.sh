#!/bin/bash
#==============================================================================
# DESCRIPTION: Configure default file associations for media, text, email,
#              directory handling, and custom MIME types in KDE/Linux desktop
#              environments
#
# USAGE:       ./01-user-config.sh
#
# REQUIREMENTS:
#   - xdg-utils (xdg-mime, xdg-settings)
#   - gio command (typically from glib2)
#   - update-mime-database (from shared-mime-info)
#   - /usr/share/mime/types file must exist
#   - Applications: Haruna (media), VS Code (text), Betterbird (email),
#                   JJazzLab (Band-in-a-Box, Impro-Visor, MusicXML files)
#
# NOTES:
#   - Modifies ~/.config/mimeapps.list
#   - Creates custom MIME types for Band-in-a-Box (.sgu/.mgu) and Impro-Visor (.ls)
#   - Associates MusicXML files (.mxl/.musicxml) with JJazzLab
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
JJAZZLAB_APP="jjazzlab.desktop"   # JJazzLab application handler

# Custom MIME types for JJazzLab
BIAB_MIME_TYPE="application/x-band-in-a-box"      # Band-in-a-Box files (.sgu/.mgu)
IMPROVISOR_MIME_TYPE="application/x-impro-visor"  # Impro-Visor files (.ls)
MUSICXML_MIME_TYPE="application/vnd.recordare.musicxml+xml"  # MusicXML (.mxl/.musicxml)

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
ICON_MUSIC="🎵"

# === HEADER ===
hr
log "$ICON_START" "Configuring MIME Type Associations"
info "$ICON_MEDIA" "Media player: $VIDEO_PLAYER"
info "$ICON_TEXT" "Text editor: $TEXT_EDITOR"
info "$ICON_EMAIL" "Email client: $EMAIL_CLIENT"
info "$ICON_MUSIC" "Music file handler: $JJAZZLAB_APP"
hr
echo

# === VALIDATIONS ===
# Check for required commands
command -v xdg-mime >/dev/null 2>&1 || die "xdg-mime command not found (install xdg-utils)"
command -v xdg-settings >/dev/null 2>&1 || die "xdg-settings command not found (install xdg-utils)"
command -v gio >/dev/null 2>&1 || die "gio command not found (install glib2)"
command -v update-mime-database >/dev/null 2>&1 || die "update-mime-database command not found (install shared-mime-info)"

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

# 5. Configure Custom MIME Types for Music Files
log "$ICON_MUSIC" "Registering music file types for JJazzLab…"

# Create user MIME packages directory
MIME_PACKAGES_DIR="$HOME/.local/share/mime/packages"
MUSIC_MIME_FILE="$MIME_PACKAGES_DIR/jjazzlab-music.xml"

mkdir -p "$MIME_PACKAGES_DIR" || die "Failed to create MIME packages directory"

# Create comprehensive MIME type definition for all JJazzLab-supported formats
cat > "$MUSIC_MIME_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <!-- Band-in-a-Box Files -->
  <mime-type type="application/x-band-in-a-box">
    <comment>Band-in-a-Box Song File</comment>
    <glob pattern="*.sgu"/>
    <glob pattern="*.SGU"/>
    <glob pattern="*.mgu"/>
    <glob pattern="*.MGU"/>
  </mime-type>

  <!-- Impro-Visor Files -->
  <mime-type type="application/x-impro-visor">
    <comment>Impro-Visor Leadsheet</comment>
    <glob pattern="*.ls"/>
    <glob pattern="*.LS"/>
  </mime-type>

  <!-- MusicXML Files -->
  <mime-type type="application/vnd.recordare.musicxml+xml">
    <comment>MusicXML Document</comment>
    <glob pattern="*.musicxml"/>
    <glob pattern="*.MUSICXML"/>
    <glob pattern="*.mxl"/>
    <glob pattern="*.MXL"/>
    <sub-class-of type="application/xml"/>
  </mime-type>
</mime-info>
EOF

if [ $? -eq 0 ]; then
    success "$ICON_MUSIC" "Created MIME type definitions: $MUSIC_MIME_FILE"
else
    die "Failed to create MIME type definitions"
fi

# Update MIME database
log "$ICON_MUSIC" "Updating MIME database…"
if update-mime-database "$HOME/.local/share/mime" 2>/dev/null; then
    success "$ICON_MUSIC" "MIME database updated successfully"
else
    warn "Failed to update MIME database (associations may not work immediately)"
fi

# Associate all MIME types with JJazzLab
music_associations=0
for mime_type in "$BIAB_MIME_TYPE" "$IMPROVISOR_MIME_TYPE" "$MUSICXML_MIME_TYPE"; do
    if xdg-mime default "$JJAZZLAB_APP" "$mime_type" 2>/dev/null; then
        music_associations=$((music_associations + 1))
    else
        warn "Failed to associate $mime_type with $JJAZZLAB_APP"
    fi
done

if [ "$music_associations" -gt 0 ]; then
    success "$ICON_MUSIC" "Associated $music_associations music file type(s) with JJazzLab"
    info "$ICON_MUSIC" "Supported formats: .sgu/.mgu (BIAB), .ls (Impro-Visor), .mxl/.musicxml (MusicXML)"
else
    warn "Failed to associate music files with $JJAZZLAB_APP"
    warn "Ensure $JJAZZLAB_APP is installed in /usr/share/applications or ~/.local/share/applications"
fi

# === FOOTER ===
echo
hr
success "$ICON_SUCCESS" "MIME type associations configured successfully"
info "$ICON_LINK" "Configuration file: $MIMEAPPS_FILE"
info "$ICON_MUSIC" "Music MIME types: $MUSIC_MIME_FILE"
echo
info "📋" "Summary of configured associations:"
info "   • Media files: $media_count types → $VIDEO_PLAYER"
info "   • Text files: $text_count types → $TEXT_EDITOR"
info "   • Email/Calendar: $email_count types → $EMAIL_CLIENT"
info "   • Music files: $music_associations types → $JJAZZLAB_APP"
hr
