#!/bin/bash
set -o pipefail

# runner.sh - SCP:SL Server Runner
# Installed inside Docker image at /opt/scpsl/runner.sh
# Called by entrypoint.sh with evaluated startup command

ARCH=$(uname -m)
GLOBAL_BASE="/home/container/global/SCP Secret Laboratory"
LOG_BASE="/home/container/.logs"
EXCLUDE_PATTERNS=(
    "LocalAdminLogs"
    "Metrics"
    "ServerLogs"
    "PluginAPI/dependencies"
    "PluginAPI/plugins"
    "config_backup"
)

SERVER_LOG=""
RETRY_DELAY="${RETRY_DELAY:-10}"
MAX_RETRIES="${MAX_RETRIES:-3}"

is_excluded() {
    local path="$1"
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        case "$path" in
            *"$pattern"*) return 0 ;;
        esac
    done
    return 1
}

auto_update() {
    [ "$AUTO_UPDATE" != "true" ] && return
    local DD=".DepotDownloader/DepotDownloader"
    [ ! -f "$DD" ] && { printf '\033[0;33mDepotDownloader not found, skipping auto-update\033[0m\n'; return; }
    printf '\033[0;36mChecking for SCP:SL updates...\033[0m\n'
    local DD_CMD="$DD"
    [ "$ARCH" = "aarch64" ] && DD_CMD="box64 $DD"
    timeout 120 $DD_CMD -app 996560 -depot 996562 -dir /home/container -validate 2>&1 | tail -5 || printf '\033[0;33mUpdate check skipped\033[0m\n'
}

setup_logging() {
    local year month day hour minute second ts log_dir
    year=$(date +%Y); month=$(date +%m); day=$(date +%d)
    hour=$(date +%H); minute=$(date +%M); second=$(date +%S)
    log_dir="${LOG_BASE}/${year}/${month}"
    mkdir -p "$log_dir"
    ts="${day}_${hour}-${minute}-${second}"
    SERVER_LOG="${log_dir}/log${ts}.txt"
    printf '\033[0;36mLogging to %s\033[0m\n' "$SERVER_LOG"
}

log() {
    if [ -n "$SERVER_LOG" ]; then
        echo "$@" | tee -a "$SERVER_LOG"
    else
        echo "$@"
    fi
}

sync_global_configs() {
    if [ ! -d "$GLOBAL_BASE" ]; then
        printf '\033[0;33mFirst run: creating global config templates...\033[0m\n'
        mkdir -p "$GLOBAL_BASE"
        cd /home/container || return
        find "SCP Secret Laboratory" -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
            is_excluded "$f" && continue
            local target="/home/container/global/$f"
            mkdir -p "$(dirname "$target")"
            cp "$f" "$target"
        done
        printf '\033[0;32mGlobal configs created from current server configs.\033[0m\n'
        return
    fi

    printf '\033[0;36mSyncing global configs...\033[0m\n'
    cd /home/container/global || return
    find "SCP Secret Laboratory" -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
        is_excluded "$f" && continue
        local target="/home/container/$f"
        mkdir -p "$(dirname "$target")"
        cp "$f" "$target"
    done
    printf '\033[0;32mGlobal configs synced.\033[0m\n'
}

run_server() {
    local cmd="$1"
    log "Starting SCP:SL server..."

    # Outer PTY for line-buffered output + ANSI colors.
    # start.sh already wraps LocalAdmin in an inner script(1) PTY,
    # so this creates a clean nested-PTY pipeline:
    #   LocalAdmin → (inner PTY) → start.sh → (outer PTY) → stdout (colored)
    #                                                       → sed strip → .log (clean)
    script -q -f -c "cd /home/container && $cmd" /dev/null 2>&1 | \
        sed -u -E '/\x1b\[/!{
            /\[INFO\]/ s/.*/\x1b[0;94m&\x1b[0m/;
            /\[DEBUG\]/ s/.*/\x1b[0;36m&\x1b[0m/;
            /\[SUCCEED\]/ s/.*/\x1b[0;32m&\x1b[0m/;
            /\[SUCCESS\]/ s/.*/\x1b[0;32m&\x1b[0m/;
            /\[WARN\]/ s/.*/\x1b[0;33m&\x1b[0m/;
            /\[CRIT\]/ s/.*/\x1b[0;35m&\x1b[0m/;
            /\[ERROR\]/ s/.*/\x1b[0;31m&\x1b[0m/;
            /\[FATAL\]/ s/.*/\x1b[0;31m&\x1b[0m/;
        }' | \
        tee >(sed -u -E 's/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\x1b\][^\x07]*\x07//g; s/\x1b[=?#]//g; s/\x1b[\(\)]//g; s/\x1b[PX^_]//g; s/\r//g' >> "$SERVER_LOG")

    local rc=${PIPESTATUS[0]}
    log "Server exited with code $rc"
    return $rc
}

main() {
    local startup_cmd="$1"

    cd /home/container || exit 1

    printf '\033[0;36m=== SCP:SL Server Runner ===\033[0m\n'

    auto_update
    setup_logging
    sync_global_configs

    if [ "$ARCH" = "aarch64" ]; then
        local retry_count=0
        while true; do
            run_server "$startup_cmd"
            local rc=$?

            if [ $rc -eq 0 ]; then
                log "Server shutdown complete."
                exit 0
            fi

            if [ "$MAX_RETRIES" -eq 0 ]; then
                log "[$(date +%H:%M:%S)] Server exited ($rc), restarting in ${RETRY_DELAY}s..."
                sleep "$RETRY_DELAY"
                continue
            fi

            retry_count=$((retry_count + 1))
            if [ "$retry_count" -ge "$MAX_RETRIES" ]; then
                log "Server failed after $MAX_RETRIES attempts, last RC: $rc"
                exit $rc
            fi
            log "[$(date +%H:%M:%S)] Server exited ($rc), retry $retry_count/$MAX_RETRIES in ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        done
    else
        run_server "$startup_cmd"
        local rc=$?
        exit $rc
    fi
}

main "$@"
