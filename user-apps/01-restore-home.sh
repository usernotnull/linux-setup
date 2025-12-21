#!/bin/bash
#==============================================================================
# DESCRIPTION: Restores files from compressed backups with verification,
#              checksum validation, and detailed progress reporting.
#
# USAGE:       ./restore.sh [backup_timestamp] [--dry-run] [--list] [--interactive]
#
# EXAMPLES:    ./restore.sh                    # Interactive mode: choose backup
#              ./restore.sh 20241221_143000    # Restore specific backup
#              ./restore.sh --list             # List available backups
#              ./restore.sh --dry-run          # Preview without restoring
#
# FEATURES:    - Interactive backup selection
#              - Checksum verification before restore
#              - Selective path restoration
#              - Progress indicators
#              - Conflict detection and handling
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===

# Root directory where backups are stored (must match backup.sh)
BACKUP_ROOT_DIR="$HOME/.backups/home"

# Restore behavior for existing files
# Options: "skip", "overwrite", "backup", "ask"
CONFLICT_RESOLUTION="ask"

# Dry run mode - preview actions without executing
DRY_RUN=false

# List mode - show available backups and exit
LIST_MODE=false

# Interactive mode - prompt for backup selection
INTERACTIVE_MODE=false

# Specific backup timestamp to restore (format: YYYYMMDD_HHMMSS)
BACKUP_TIMESTAMP=""

# === Helper Functions ===

if [ -f "$HOME/.bash_utils" ]; then
    source "$HOME/.bash_utils"
else
    echo "Error: .bash_utils not found!"
    exit 1
fi

# Additional icons
ICON_RESTORE="📦"
ICON_VERIFY="🔐"
ICON_EXTRACT="📂"
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

# List available backups with details
list_backups() {
    local backups=($(find "$BACKUP_ROOT_DIR" -maxdepth 1 -type d -name "backup_*" | sort -r))

    if [ ${#backups[@]} -eq 0 ]; then
        warn "No backups found in $BACKUP_ROOT_DIR"
        return 1
    fi

    hr
    log "$ICON_RESTORE" "Available Backups:"
    hr
    echo

    for i in "${!backups[@]}"; do
        local backup="${backups[$i]}"
        local timestamp=$(basename "$backup" | sed 's/backup_//')
        local archive="$backup/backup.tar.zst"
        local db="$backup/metadata.db"

        if [ -f "$archive" ]; then
            local size=$(stat -c%s "$archive" 2>/dev/null || stat -f%z "$archive")
            local date_formatted=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp")

            printf "${CYAN}%2d)${NC} ${GREEN}%s${NC}\n" "$((i+1))" "$timestamp"
            printf "    📅 Date: %s\n" "$date_formatted"
            printf "    💾 Size: %s\n" "$(format_bytes "$size")"

            # Show metadata if database exists
            if [ -f "$db" ]; then
                local path_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM backup_paths;" 2>/dev/null || echo "N/A")
                local compression=$(sqlite3 "$db" "SELECT compression_ratio FROM backup_metadata ORDER BY id DESC LIMIT 1;" 2>/dev/null || echo "N/A")
                printf "    📂 Paths: %s\n" "$path_count"
                [ "$compression" != "N/A" ] && printf "    🗜️  Ratio: %sx\n" "$compression"
            fi
            echo
        fi
    done

    return 0
}

# Interactive backup selection
select_backup() {
    local backups=($(find "$BACKUP_ROOT_DIR" -maxdepth 1 -type d -name "backup_*" | sort -r))

    if [ ${#backups[@]} -eq 0 ]; then
        die "No backups found in $BACKUP_ROOT_DIR"
    fi

    list_backups

    hr
    printf "${CYAN}%b${NC} Enter backup number (1-%d) or 'q' to quit: " "$ICON_SELECT" "${#backups[@]}"
    read -r selection

    if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
        log "$ICON_WARN" "Restore cancelled by user"
        exit 0
    fi

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#backups[@]}" ]; then
        die "Invalid selection: $selection"
    fi

    local selected_backup="${backups[$((selection-1))]}"
    BACKUP_TIMESTAMP=$(basename "$selected_backup" | sed 's/backup_//')

    echo
    success "$ICON_SUCCESS" "Selected backup: $BACKUP_TIMESTAMP"
    echo
}

# Verify backup integrity
verify_backup() {
    local backup_dir="$1"
    local archive="$backup_dir/backup.tar.zst"
    local db="$backup_dir/metadata.db"

    log "$ICON_VERIFY" "Verifying backup integrity..."

    # Check if archive exists
    if [ ! -f "$archive" ]; then
        die "Archive not found: $archive"
    fi

    # Test archive integrity
    if ! zstd -t "$archive" 2>/dev/null; then
        die "Archive is corrupted: $archive"
    fi

    success "$ICON_SUCCESS" "Archive integrity verified"

    # Verify checksum if database exists
    if [ -f "$db" ]; then
        local stored_checksum=$(sqlite3 "$db" "SELECT checksum FROM backup_paths LIMIT 1;" 2>/dev/null || echo "")

        if [ -n "$stored_checksum" ]; then
            log "$ICON_VERIFY" "Verifying checksum..."
            local current_checksum=$(sha256sum "$archive" | cut -d' ' -f1)

            if [ "$stored_checksum" = "$current_checksum" ]; then
                success "$ICON_SUCCESS" "Checksum verified"
            else
                die "Checksum mismatch! Archive may be corrupted."
            fi
        fi
    fi

    echo
}

# Show backup contents
show_backup_contents() {
    local backup_dir="$1"
    local manifest="$backup_dir/manifest.txt"

    if [ -f "$manifest" ]; then
        log "$ICON_FOLDER" "Backup contains the following paths:"
        echo
        while IFS= read -r path; do
            info "  •" "$path"
        done < "$manifest"
        echo
    fi
}

# Handle file conflicts
handle_conflict() {
    local file="$1"

    case "$CONFLICT_RESOLUTION" in
        skip)
            return 1
            ;;
        overwrite)
            return 0
            ;;
        backup)
            local backup_name="${file}.backup.$(date +%s)"
            mv "$file" "$backup_name"
            info "$ICON_WARN" "Backed up existing file: $backup_name"
            return 0
            ;;
        ask)
            printf "${YELLOW}%b${NC} File exists: %s\n" "$ICON_WARN" "$file"
            printf "   [o]verwrite, [s]kip, [b]ackup, [O]verwrite all, [S]kip all? " >&2
            read -r response </dev/tty

            case "$response" in
                o|O)
                    [ "$response" = "O" ] && CONFLICT_RESOLUTION="overwrite"
                    return 0
                    ;;
                s|S)
                    [ "$response" = "S" ] && CONFLICT_RESOLUTION="skip"
                    return 1
                    ;;
                b|B)
                    local backup_name="${file}.backup.$(date +%s)"
                    mv "$file" "$backup_name"
                    info "$ICON_WARN" "Backed up existing file: $backup_name"
                    return 0
                    ;;
                *)
                    return 1
                    ;;
            esac
            ;;
    esac
}

# Restore backup
restore_backup() {
    local backup_dir="$1"
    local archive="$backup_dir/backup.tar.zst"

    log "$ICON_EXTRACT" "Extracting archive..."

    if [ "$DRY_RUN" = true ]; then
        log "$ICON_FOLDER" "Would extract to: /"
        log "$ICON_FOLDER" "Archive contents:"
        tar -tf <(zstd -d -c "$archive") | head -20
        [ $(tar -tf <(zstd -d -c "$archive") | wc -l) -gt 20 ] && echo "... (more files)"
        return 0
    fi

    # Create temporary directory for extraction
    TEMP_EXTRACT_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_EXTRACT_DIR" EXIT

    # Extract archive
    START_TIME=$(date +%s)

    if command_exists pv; then
        zstd -d -c "$archive" 2>/dev/null | pv -N "Extracting" | tar -xf - -C "$TEMP_EXTRACT_DIR" 2>/dev/null
    else
        zstd -d -c "$archive" 2>/dev/null | tar -xf - -C "$TEMP_EXTRACT_DIR" 2>/dev/null
    fi

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    success "$ICON_SUCCESS" "Extraction completed in ${DURATION}s"
    echo

    # Move files to their original locations
    log "$ICON_RESTORE" "Restoring files to original locations..."
    echo

    local restored_count=0
    local skipped_count=0

    cd "$TEMP_EXTRACT_DIR"

    # Find all files and directories, excluding the temp dir itself
    while IFS= read -r -d '' item; do
        # Skip if it's just "."
        [ "$item" = "." ] && continue

        # Remove leading "./" if present
        item="${item#./}"

        local target="/$item"
        local source="$TEMP_EXTRACT_DIR/$item"

        if [ -d "$source" ]; then
            # Create directory if it doesn't exist
            if [ ! -d "$target" ]; then
                mkdir -p "$target"
            fi
        elif [ -f "$source" ]; then
            # Handle file conflicts
            if [ -e "$target" ]; then
                if ! handle_conflict "$target"; then
                    skipped_count=$((skipped_count + 1))
                    continue
                fi
            fi

            # Ensure parent directory exists
            mkdir -p "$(dirname "$target")"

            # Copy file
            cp -a "$source" "$target"
            restored_count=$((restored_count + 1))

            # Show progress every 10 files
            if [ $((restored_count % 10)) -eq 0 ]; then
                printf "\r  Restored: %d files..." "$restored_count"
            fi
        fi
    done < <(find . -print0)

    # Clear the progress line
    [ "$restored_count" -gt 0 ] && printf "\r%*s\r" 50 ""

    cd - > /dev/null

    echo
    success "$ICON_SUCCESS" "Restored $restored_count files"
    [ "$skipped_count" -gt 0 ] && warn "Skipped $skipped_count files due to conflicts"
}

# === Parse Arguments ===

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --list)
            LIST_MODE=true
            shift
            ;;
        --interactive|-i)
            INTERACTIVE_MODE=true
            shift
            ;;
        *)
            if [[ "$1" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
                BACKUP_TIMESTAMP="$1"
            else
                die "Invalid argument: $1"
            fi
            shift
            ;;
    esac
done

# === Header ===

hr
log "$ICON_START" "Starting System Restore"
info "$ICON_RESTORE" "Backup source: $BACKUP_ROOT_DIR"
[ "$DRY_RUN" = true ] && warn "DRY RUN MODE - No files will be restored"
hr
echo

# === Validations ===

# Check for required commands
command_exists tar || die "tar is not installed"
command_exists zstd || die "zstd is not installed. Install with: sudo apt install zstd"
command_exists sqlite3 || die "sqlite3 is not installed. Install with: sudo apt install sqlite3"
command_exists pv || log "$ICON_WARN" "pv not installed (progress bars disabled). Install with: sudo apt install pv"

# Check if backup root exists with retry option
while [ ! -d "$BACKUP_ROOT_DIR" ]; do
    hr
    warn "Backup directory does not exist: $BACKUP_ROOT_DIR"
    echo
    printf "${YELLOW}%b${NC} Options:\n" "$ICON_WARN"
    printf "   ${CYAN}1)${NC} Enter a different backup directory path\n"
    printf "   ${CYAN}2)${NC} Retry (if you just created it)\n"
    printf "   ${CYAN}3)${NC} Quit\n"
    echo
    printf "${CYAN}%b${NC} Choose option [1-3]: " "$ICON_SELECT"
    read -r option </dev/tty
    echo

    case "$option" in
        1)
            printf "${CYAN}%b${NC} Enter backup directory path: " "$ICON_FOLDER"
            read -r new_path </dev/tty
            # Expand tilde if present
            BACKUP_ROOT_DIR="${new_path/#\~/$HOME}"
            echo
            ;;
        2)
            # Just retry with current path
            ;;
        3|q|Q)
            log "$ICON_WARN" "Restore cancelled by user"
            exit 0
            ;;
        *)
            warn "Invalid option: $option"
            ;;
    esac
done

success "$ICON_SUCCESS" "Found backup directory: $BACKUP_ROOT_DIR"
echo

# === List Mode ===

if [ "$LIST_MODE" = true ]; then
    list_backups
    exit 0
fi

# === Determine Backup to Restore ===

if [ -z "$BACKUP_TIMESTAMP" ]; then
    INTERACTIVE_MODE=true
fi

if [ "$INTERACTIVE_MODE" = true ]; then
    select_backup
fi

if [ -z "$BACKUP_TIMESTAMP" ]; then
    die "No backup specified. Use --interactive or provide a timestamp."
fi

# === Restore Process ===

BACKUP_DIR="$BACKUP_ROOT_DIR/backup_$BACKUP_TIMESTAMP"

# Verify backup exists
[ -d "$BACKUP_DIR" ] || die "Backup not found: $BACKUP_DIR"

# Verify backup integrity
verify_backup "$BACKUP_DIR"

# Show contents
show_backup_contents "$BACKUP_DIR"

# Confirm restore (if not dry run)
if [ "$DRY_RUN" = false ] && [ -t 0 ]; then
    hr
    printf "${YELLOW}%b WARNING:${NC} This will restore files from backup: %s\n" "$ICON_WARN" "$BACKUP_TIMESTAMP"
    printf "Continue? [y/N]: "
    read -r confirm
    echo

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log "$ICON_WARN" "Restore cancelled by user"
        exit 0
    fi
fi

# Perform restore
restore_backup "$BACKUP_DIR"

# === Summary ===

hr
success "$ICON_SUCCESS" "Restore completed successfully!"
if [ "$DRY_RUN" = false ]; then
    info "$ICON_CLOCK" "Restored from: $BACKUP_TIMESTAMP"
fi
hr
