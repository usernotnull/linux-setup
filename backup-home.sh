#!/bin/bash
#==============================================================================
# DESCRIPTION: Creates compressed backups of specified directories with
#              timestamp, checksum verification, and metadata tracking.
#              Uses zstd for optimal compression speed/ratio balance.
#
# USAGE:       ./backup.sh [--dry-run]
#
# FEATURES:    - Incremental timestamp-based backups
#              - SQLite metadata tracking with checksums
#              - Parallel compression for performance
#              - Progress indicators
#              - Automatic backup rotation (keeps last N backups)
#
# OUTPUT:      Creates backups in BACKUP_ROOT_DIR with structure:
#              backup_YYYYMMDD_HHMMSS/
#                ├── backup.tar.zst (compressed archive)
#                ├── manifest.txt (file list)
#                └── metadata.db (SQLite database)
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===

# Root directory where all backups will be stored
BACKUP_ROOT_DIR="$HOME/.backups/home"

# Configuration file containing paths to backup (one per line)
BACKUP_PATHS_FILE="$BACKUP_ROOT_DIR/backup-paths.txt"

# Number of backups to keep (older ones will be deleted)
MAX_BACKUPS=5

# Compression level (1-19, higher = better compression but slower)
# 3 is recommended for speed/size balance, 10+ for maximum compression
COMPRESSION_LEVEL=3

# Dry run mode - set to true to see what would be backed up without doing it
DRY_RUN=false

# === Helper Functions ===

if [ -f "$HOME/.bash_utils" ]; then
    source "$HOME/.bash_utils"
else
    echo "Error: .bash_utils not found!"
    exit 1
fi

# Additional icons
ICON_BACKUP="💾"
ICON_COMPRESS="🗜️"
ICON_DATABASE="🗄️"
ICON_CLOCK="⏱️"
ICON_SELECT="👆"

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes}B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$(( bytes / 1024 ))KB"
    elif [ "$bytes" -lt 1073741824 ]; then
        echo "$(( bytes / 1048576 ))MB"
    else
        echo "$(( bytes / 1073741824 ))GB"
    fi
}

# Calculate directory size
get_dir_size() {
    local path="$1"
    if [ -e "$path" ]; then
        du -sb "$path" 2>/dev/null | cut -f1 || echo "0"
    else
        echo "0"
    fi
}

# === Parse Arguments ===

for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        *)
            die "Unknown argument: $arg"
            ;;
    esac
done

# === Header ===

hr
log "$ICON_START" "Starting System Backup"
info "$ICON_BACKUP" "Backup destination: $BACKUP_ROOT_DIR"
info "$ICON_COMPRESS" "Compression level:  $COMPRESSION_LEVEL"
[ "$DRY_RUN" = true ] && warn "DRY RUN MODE - No files will be backed up"
hr
echo

# === Validations ===

# Check for required commands
command_exists tar || die "tar is not installed"
command_exists zstd || die "zstd is not installed. Install with: sudo apt install zstd"
command_exists sqlite3 || die "sqlite3 is not installed. Install with: sudo apt install sqlite3"
command_exists sha256sum || die "sha256sum is not installed"

# Create backup root directory if it doesn't exist
if [ ! -d "$BACKUP_ROOT_DIR" ]; then
    mkdir -p "$BACKUP_ROOT_DIR"
    log "$ICON_FOLDER" "Created backup root directory: $BACKUP_ROOT_DIR"
fi

# Create backup root directory if it doesn't exist
if [ ! -d "$BACKUP_ROOT_DIR" ]; then
    mkdir -p "$BACKUP_ROOT_DIR"
    log "$ICON_FOLDER" "Created backup root directory: $BACKUP_ROOT_DIR"
fi

# Check if backup paths file exists, create template and wait for user
while [ ! -f "$BACKUP_PATHS_FILE" ] || [ ! -s "$BACKUP_PATHS_FILE" ] || ! grep -qv '^[[:space:]]*\(#\|$\)' "$BACKUP_PATHS_FILE" 2>/dev/null; do
    if [ ! -f "$BACKUP_PATHS_FILE" ]; then
        log "$ICON_WARN" "Backup paths file not found. Creating template..."

        cat > "$BACKUP_PATHS_FILE" <<EOF
# Backup Paths Configuration
# Add one path per line (lines starting with # are ignored)
# Example paths:
# $HOME/.var/app/org.gnome.Rhythmbox3
# $HOME/Docker
# $HOME/Pictures/Exported
# $HOME/.config/obsidian

EOF
        success "$ICON_SUCCESS" "Created template: $BACKUP_PATHS_FILE"
    elif [ ! -s "$BACKUP_PATHS_FILE" ] || ! grep -qv '^[[:space:]]*\(#\|$\)' "$BACKUP_PATHS_FILE" 2>/dev/null; then
        warn "Backup paths file is empty or contains no valid paths"
    fi

    hr
    echo
    printf "${YELLOW}%b${NC} Please add paths to backup in:\n" "$ICON_WARN"
    printf "   ${CYAN}%s${NC}\n" "$BACKUP_PATHS_FILE"
    echo
    printf "${YELLOW}%b${NC} Options:\n" "$ICON_WARN"
    printf "   ${CYAN}1)${NC} Open file in nano editor\n"
    printf "   ${CYAN}2)${NC} Retry (after editing manually)\n"
    printf "   ${CYAN}3)${NC} Quit\n"
    echo
    printf "${CYAN}%b${NC} Choose option [1-3]: " "$ICON_SELECT"
    read -r option </dev/tty
    echo

    case "$option" in
        1)
            if command_exists nano; then
                nano "$BACKUP_PATHS_FILE"
            else
                warn "nano is not installed"
            fi
            ;;
        2)
            # Just retry - will check file again
            ;;
        3|q|Q)
            log "$ICON_WARN" "Backup cancelled by user"
            exit 0
            ;;
        *)
            warn "Invalid option: $option"
            ;;
    esac
    echo
done

success "$ICON_SUCCESS" "Found valid backup paths configuration"
echo

# Read backup paths from file
BACKUP_PATHS=()
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Add to array
    BACKUP_PATHS+=("$line")
done < "$BACKUP_PATHS_FILE"

# Check if we have any paths
if [ ${#BACKUP_PATHS[@]} -eq 0 ]; then
    die "No paths configured in $BACKUP_PATHS_FILE"
fi

# Validate backup paths
VALID_PATHS=()
TOTAL_SIZE=0

log "$ICON_SEARCH" "Validating backup paths from: $BACKUP_PATHS_FILE"
echo

for path in "${BACKUP_PATHS[@]}"; do
    # Expand tilde
    expanded_path="${path/#\~/$HOME}"

    if [ -e "$expanded_path" ]; then
        # Count files for better progress estimation
        file_count=$(find "$expanded_path" -type f 2>/dev/null | wc -l)
        size=$(get_dir_size "$expanded_path")
        TOTAL_SIZE=$((TOTAL_SIZE + size))
        VALID_PATHS+=("$expanded_path")
        info "  ✓" "$(basename "$expanded_path") - $(format_bytes "$size") ($file_count files)"
    else
        warn "Path does not exist (skipping): $path"
    fi
done

echo

if [ ${#VALID_PATHS[@]} -eq 0 ]; then
    die "No valid paths to backup!"
fi

info "$ICON_FOLDER" "Total data to backup: $(format_bytes "$TOTAL_SIZE")"
echo

# Confirm backup before proceeding (if not dry run and interactive terminal)
if [ "$DRY_RUN" = false ] && [ -t 0 ]; then
    hr
    log "$ICON_BACKUP" "Ready to backup ${#VALID_PATHS[@]} paths ($(format_bytes "$TOTAL_SIZE"))"
    printf "${CYAN}%b${NC} Continue with backup? [Y/n]: " "$ICON_SELECT"
    read -r confirm
    echo

    if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
        log "$ICON_WARN" "Backup cancelled by user"
        exit 0
    fi
fi

# === Setup Backup Directory ===

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_ROOT_DIR/backup_$TIMESTAMP"
ARCHIVE_NAME="backup.tar.zst"
MANIFEST_NAME="manifest.txt"
DB_NAME="metadata.db"

if [ "$DRY_RUN" = false ]; then
    mkdir -p "$BACKUP_DIR"
    log "$ICON_FOLDER" "Created backup directory: $BACKUP_DIR"
else
    log "$ICON_FOLDER" "Would create: $BACKUP_DIR"
fi

# === Create Metadata Database ===

create_metadata_db() {
    local db_path="$1"

    sqlite3 "$db_path" <<EOF
CREATE TABLE IF NOT EXISTS backup_metadata (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    hostname TEXT NOT NULL,
    username TEXT NOT NULL,
    backup_size INTEGER NOT NULL,
    compressed_size INTEGER,
    compression_ratio REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS backup_paths (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    backup_id INTEGER NOT NULL,
    original_path TEXT NOT NULL,
    size INTEGER NOT NULL,
    file_count INTEGER,
    checksum TEXT,
    FOREIGN KEY (backup_id) REFERENCES backup_metadata(id)
);

CREATE INDEX IF NOT EXISTS idx_timestamp ON backup_metadata(timestamp);
CREATE INDEX IF NOT EXISTS idx_backup_id ON backup_paths(backup_id);
EOF
}

# === Create Backup ===

if [ "$DRY_RUN" = false ]; then
    log "$ICON_COMPRESS" "Creating compressed archive..."

    ARCHIVE_PATH="$BACKUP_DIR/$ARCHIVE_NAME"
    MANIFEST_PATH="$BACKUP_DIR/$MANIFEST_NAME"
    DB_PATH="$BACKUP_DIR/$DB_NAME"

    # Create manifest
    printf "" > "$MANIFEST_PATH"
    for path in "${VALID_PATHS[@]}"; do
        echo "$path" >> "$MANIFEST_PATH"
    done

    # Create tar archive with progress
    START_TIME=$(date +%s)

    # Build tar command with proper path handling
    TAR_PATHS=()
    for path in "${VALID_PATHS[@]}"; do
        # Remove leading slash for tar -C option
        TAR_PATHS+=("${path#/}")
    done

    # Use tar with zstd compression, preserving permissions and timestamps
    if command_exists pv && [ "$TOTAL_SIZE" -gt 0 ]; then
        tar -cf - \
            --preserve-permissions \
            --numeric-owner \
            -C / \
            "${TAR_PATHS[@]}" 2>/dev/null | \
            pv -s "$TOTAL_SIZE" -N "Compressing" | \
            zstd -"$COMPRESSION_LEVEL" -T0 -q -o "$ARCHIVE_PATH" 2>/dev/null
    else
        # Fallback without progress bar
        tar -cf - \
            --preserve-permissions \
            --numeric-owner \
            -C / \
            "${TAR_PATHS[@]}" 2>/dev/null | \
            zstd -"$COMPRESSION_LEVEL" -T0 -q -o "$ARCHIVE_PATH" 2>/dev/null
    fi

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    success "$ICON_SUCCESS" "Archive created in ${DURATION}s"

    # Get archive size
    COMPRESSED_SIZE=$(stat -c%s "$ARCHIVE_PATH" 2>/dev/null || stat -f%z "$ARCHIVE_PATH")
    COMPRESSION_RATIO=$(awk "BEGIN {printf \"%.2f\", $TOTAL_SIZE / $COMPRESSED_SIZE}")

    info "$ICON_COMPRESS" "Original size:    $(format_bytes "$TOTAL_SIZE")"
    info "$ICON_COMPRESS" "Compressed size:  $(format_bytes "$COMPRESSED_SIZE")"
    info "$ICON_COMPRESS" "Compression ratio: ${COMPRESSION_RATIO}x"
    echo

    # Calculate checksum
    log "$ICON_DATABASE" "Calculating checksums..."
    ARCHIVE_CHECKSUM=$(sha256sum "$ARCHIVE_PATH" | cut -d' ' -f1)

    # Create metadata database
    create_metadata_db "$DB_PATH"

    # Insert backup metadata
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO backup_metadata (timestamp, hostname, username, backup_size, compressed_size, compression_ratio)
VALUES ('$TIMESTAMP', '$(hostname)', '$(whoami)', $TOTAL_SIZE, $COMPRESSED_SIZE, $COMPRESSION_RATIO);
EOF

    BACKUP_ID=$(sqlite3 "$DB_PATH" "SELECT last_insert_rowid();")

    # Insert path metadata
    for path in "${VALID_PATHS[@]}"; do
        size=$(get_dir_size "$path")
        file_count=$(find "$path" -type f 2>/dev/null | wc -l || echo "0")

        sqlite3 "$DB_PATH" <<EOF
INSERT INTO backup_paths (backup_id, original_path, size, file_count, checksum)
VALUES ($BACKUP_ID, '$path', $size, $file_count, '$ARCHIVE_CHECKSUM');
EOF
    done

    success "$ICON_DATABASE" "Metadata database created"
    echo
else
    log "$ICON_COMPRESS" "Would create archive with ${#VALID_PATHS[@]} paths"
    log "$ICON_DATABASE" "Would create metadata database"
    echo
fi

# === Cleanup Old Backups ===

log "$ICON_CLEAN" "Managing backup retention..."

if [ "$DRY_RUN" = false ]; then
    EXISTING_BACKUPS=($(find "$BACKUP_ROOT_DIR" -maxdepth 1 -type d -name "backup_*" | sort -r))

    if [ ${#EXISTING_BACKUPS[@]} -gt "$MAX_BACKUPS" ]; then
        BACKUPS_TO_DELETE=("${EXISTING_BACKUPS[@]:$MAX_BACKUPS}")

        for backup in "${BACKUPS_TO_DELETE[@]}"; do
            rm -rf "$backup"
            info "$ICON_TRASH" "Removed old backup: $(basename "$backup")"
        done
    else
        info "$ICON_CLEAN" "No old backups to remove (${#EXISTING_BACKUPS[@]}/$MAX_BACKUPS)"
    fi
else
    log "$ICON_CLEAN" "Would check for old backups to remove"
fi

echo

# === Summary ===

hr
success "$ICON_SUCCESS" "Backup completed successfully!"
if [ "$DRY_RUN" = false ]; then
    info "$ICON_BACKUP" "Backup location: $BACKUP_DIR"
    info "$ICON_CLOCK" "Timestamp: $TIMESTAMP"
    info "$ICON_DATABASE" "Paths backed up: ${#VALID_PATHS[@]}"
fi
hr
