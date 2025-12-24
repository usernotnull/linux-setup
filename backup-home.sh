#!/bin/bash
#==============================================================================
# DESCRIPTION: Creates compressed backups of specified directories using zstd.
#              Generates a self-contained SQLite metadata database for each
#              backup and manages retention of old archives.
#
# USAGE:       ./backup.sh [--dry-run]
#
# REQUIREMENTS:
#   - Tools: tar, zstd, sqlite3, sha256sum, pv (optional, for progress bars)
#   - .bash_utils helper library
#
# NOTES:
#   - Reads paths from $HOME/.backups/backup-paths.txt
#   - Creates a template config file if one does not exist
#   - Uses zstd level 3 by default (sweet spot for speed/ratio)
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
BACKUP_ROOT="${HOME}/.backups"           # Root directory for all backups
CONFIG_FILE="${BACKUP_ROOT}/paths.txt"   # File containing paths to backup
MAX_BACKUPS=5                            # Number of historical backups to keep
COMPRESSION_LEVEL=3                      # zstd level (1-19). 3 is standard.
DRY_RUN=false                            # Set to true via flag to preview

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
    exit 1
fi

# Additional Icons
ICON_DB="🗄️"
ICON_ZIP="🗜️"
ICON_TIME="⏱️"

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Convert bytes to human readable format
human_size() {
    local bytes="${1:-0}"
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes} B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$((bytes / 1024)) KB"
    elif [ "$bytes" -lt 1073741824 ]; then
        echo "$((bytes / 1048576)) MB"
    else
        echo "$((bytes / 1073741824)) GB"
    fi
}

# Get directory size in bytes (portable)
get_dir_size() {
    local dir="${1:-}"
    if [ -d "$dir" ]; then
        du -sb "$dir" 2>/dev/null | cut -f1 || echo "0"
    else
        echo "0"
    fi
}

# Cleanup function for interruptions
cleanup() {
    if [ -n "${CURRENT_BACKUP_DIR:-}" ] && [ -d "$CURRENT_BACKUP_DIR" ]; then
        if [ "$DRY_RUN" = false ]; then
            warn "Interrupted. Cleaning up incomplete backup..."
            rm -rf "$CURRENT_BACKUP_DIR"
        fi
    fi
    exit 130
}

# === HEADER ===
hr
log "$ICON_START" "System Backup Utility"
info "$ICON_FOLDER" "Backup Root: $BACKUP_ROOT"
info "$ICON_ZIP" "Compression: zstd (Level $COMPRESSION_LEVEL)"

# Parse arguments
for arg in "$@"; do
    if [ "$arg" == "--dry-run" ]; then
        DRY_RUN=true
        warn "DRY RUN MODE ENABLED"
    fi
done
hr
echo

# === VALIDATIONS ===
# Check dependencies
command_exists tar || die "tar command not found"
command_exists zstd || die "zstd not found. Install: sudo apt install zstd"
command_exists sqlite3 || die "sqlite3 not found. Install: sudo apt install sqlite3"

# Create root directory
if [ ! -d "$BACKUP_ROOT" ]; then
    mkdir -p "$BACKUP_ROOT" || die "Failed to create backup root: $BACKUP_ROOT"
    success "$ICON_FOLDER" "Created backup root directory"
fi

# Handle Config File
if [ ! -f "$CONFIG_FILE" ]; then
    warn "Configuration file not found."
    cat > "$CONFIG_FILE" <<EOF
# Add paths to backup (one per line)
# Lines starting with # are ignored
# Example:
# /home/$USER/Documents
# /home/$USER/.ssh
EOF
    log "$ICON_SEARCH" "Created template at: $CONFIG_FILE"
    die "Please edit the configuration file and run the script again."
fi

# Validate Config File Content
if [ ! -s "$CONFIG_FILE" ]; then
    die "Configuration file is empty: $CONFIG_FILE"
fi

# === MAIN LOGIC ===

# 1. Read and Validate Source Paths
# ---------------------------------
log "$ICON_SEARCH" "Scanning backup paths..."
VALID_PATHS=()
TOTAL_SOURCE_SIZE=0
FILE_COUNT=0

while IFS= read -r line || [ -n "$line" ]; do
    # Trim whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # Skip comments and empty lines
    if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
        continue
    fi

    # Expand tilde if present
    line="${line/#\~/$HOME}"

    if [ -d "$line" ] || [ -f "$line" ]; then
        size=$(get_dir_size "$line")
        TOTAL_SOURCE_SIZE=$((TOTAL_SOURCE_SIZE + size))
        VALID_PATHS+=("$line")
        info "  ✓ Found: $line ($(human_size "$size"))"
    else
        warn "  ✕ Path not found (skipping): $line"
    fi
done < "$CONFIG_FILE"

if [ ${#VALID_PATHS[@]} -eq 0 ]; then
    die "No valid paths found to backup."
fi

echo
info "📊" "Total size to process: $(human_size "$TOTAL_SOURCE_SIZE")"
echo

# 2. Prepare Backup Directory
# ---------------------------
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CURRENT_BACKUP_DIR="$BACKUP_ROOT/backup_$TIMESTAMP"
ARCHIVE_FILE="$CURRENT_BACKUP_DIR/backup.tar.zst"
DB_FILE="$CURRENT_BACKUP_DIR/metadata.db"
MANIFEST_FILE="$CURRENT_BACKUP_DIR/manifest.txt"

# Register trap for cleanup only after we define the directory variable
trap cleanup INT TERM

if [ "$DRY_RUN" = true ]; then
    log "$ICON_FOLDER" "[DRY RUN] Would create directory: $CURRENT_BACKUP_DIR"
else
    mkdir -p "$CURRENT_BACKUP_DIR" || die "Failed to create backup directory"
fi

# 3. Perform Backup (Compression)
# -------------------------------
START_TIME=$(date +%s)

if [ "$DRY_RUN" = true ]; then
    log "$ICON_ZIP" "[DRY RUN] Would compress ${#VALID_PATHS[@]} paths to $ARCHIVE_FILE"
else
    log "$ICON_ZIP" "Starting compression..."

    # Create Manifest
    printf "%s\n" "${VALID_PATHS[@]}" > "$MANIFEST_FILE"

    # Prepare tar command arguments (handle absolute paths safely)
    # We use -P (absolute names) cautiously, or -C / and strip leading slash.
    # Here we use -C / and strip leading slash for safety/portability.
    TAR_ARGS=()
    for path in "${VALID_PATHS[@]}"; do
        TAR_ARGS+=("${path#/}") # Strip leading slash
    done

    # Execute Pipeline
    # tar -> pv (if exists) -> zstd -> disk
    if command_exists pv; then
        if ! tar -C / -cf - "${TAR_ARGS[@]}" 2>/dev/null | \
             pv -s "$TOTAL_SOURCE_SIZE" | \
             zstd -"$COMPRESSION_LEVEL" -T0 -q -o "$ARCHIVE_FILE"; then
            die "Backup pipeline failed"
        fi
    else
        log "$ICON_WARN" "pv not installed - progress bar disabled"
        if ! tar -C / -cf - "${TAR_ARGS[@]}" 2>/dev/null | \
             zstd -"$COMPRESSION_LEVEL" -T0 -q -o "$ARCHIVE_FILE"; then
            die "Backup pipeline failed"
        fi
    fi

    success "$ICON_SUCCESS" "Compression complete"
fi

DURATION=$(( $(date +%s) - START_TIME ))

# 4. Generate Metadata & Checksums
# --------------------------------
if [ "$DRY_RUN" = true ]; then
    log "$ICON_DB" "[DRY RUN] Would generate SQLite database and checksums"
else
    log "$ICON_DB" "Generating metadata..."

    # Calculate Archive Checksum
    ARCHIVE_HASH=$(sha256sum "$ARCHIVE_FILE" | cut -d' ' -f1)
    ARCHIVE_SIZE=$(stat -c%s "$ARCHIVE_FILE" 2>/dev/null || stat -f%z "$ARCHIVE_FILE")

    # Initialize SQLite DB
    sqlite3 "$DB_FILE" <<EOF
    CREATE TABLE backup_info (
        id INTEGER PRIMARY KEY,
        timestamp TEXT,
        duration_seconds INTEGER,
        total_size_bytes INTEGER,
        archive_size_bytes INTEGER,
        archive_hash TEXT
    );
    CREATE TABLE files (
        id INTEGER PRIMARY KEY,
        path TEXT,
        type TEXT
    );
    INSERT INTO backup_info (timestamp, duration_seconds, total_size_bytes, archive_size_bytes, archive_hash)
    VALUES ('$TIMESTAMP', $DURATION, $TOTAL_SOURCE_SIZE, $ARCHIVE_SIZE, '$ARCHIVE_HASH');
EOF

    # Insert paths into DB
    for path in "${VALID_PATHS[@]}"; do
        # Escape single quotes for SQL
        safe_path="${path//\'/\'\'}"
        sqlite3 "$DB_FILE" "INSERT INTO files (path, type) VALUES ('$safe_path', 'source_root');"
    done

    success "$ICON_DB" "Metadata saved to database"
fi

# 5. Rotate Old Backups
# ---------------------
log "$ICON_CLEAN" "Checking retention policy (Keep: $MAX_BACKUPS)..."

# Find backup directories, sort reverse by name (timestamp), skip first N
# We use a safe while-read loop with process substitution
BACKUPS_REMOVED=0

# Get list of backup directories sorted by name (timestamp) descending
# We use 'ls -d' here cautiously as we control the directory names
# A safer approach using find and sort:
while IFS= read -r backup_dir; do
    # Skip if we haven't exceeded the limit
    # We need a counter.
    if [ -z "${BACKUP_COUNT:-}" ]; then BACKUP_COUNT=0; fi
    BACKUP_COUNT=$((BACKUP_COUNT + 1))

    if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
        if [ "$DRY_RUN" = true ]; then
            warn "[DRY RUN] Would delete old backup: $(basename "$backup_dir")"
        else
            rm -rf "$backup_dir"
            warn "Deleted old backup: $(basename "$backup_dir")"
            BACKUPS_REMOVED=$((BACKUPS_REMOVED + 1))
        fi
    fi
done < <(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "backup_*" | sort -r)

if [ "$BACKUPS_REMOVED" -eq 0 ]; then
    info "$ICON_CLEAN" "No old backups needed removal."
fi

# === FOOTER ===
echo
hr
if [ "$DRY_RUN" = true ]; then
    success "$ICON_SUCCESS" "Dry run completed successfully"
else
    success "$ICON_SUCCESS" "Backup completed successfully"
    info "$ICON_TIME" "Time taken: ${DURATION}s"
    info "$ICON_ZIP" "Archive: $(basename "$ARCHIVE_FILE") ($(human_size "$ARCHIVE_SIZE"))"
    info "$ICON_DB" "Metadata: $(basename "$DB_FILE")"
fi
hr
