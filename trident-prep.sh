#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# TRIDENT Bootstrap / Prep Pack – v0.2
# Governance kernel bootstrap – February 2026
# Enforces doctrine principles BEFORE OpenClaw is installed/run
# https://github.com/openclaw/openclaw   (assumed canonical source 2026)
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

LOG_FILE="$(pwd)/bootstrap-log.jsonl"
PREV_HASH=""                  # Chain starts empty
SCRIPT_VERSION="0.2"
DATE_NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ─── Helpers ─────────────────────────────────────────────────────────────────

append_log() {
    local action="$1"
    local details="$2"
    local decision="$3"
    local rationale="$4"

    local payload
    payload=$(jq -c -n \
        --arg ts "$DATE_NOW" \
        --arg act "$action" \
        --arg det "$details" \
        --arg dec "$decision" \
        --arg rat "$rationale" \
        --arg ph "$PREV_HASH" \
        --arg sv "$SCRIPT_VERSION" \
        '{timestamp: $ts, script_version: $sv, action: $act, details: $det, decision: $dec, rationale: $rat, prev_hash: $ph}')

    local current_hash
    current_hash=$(echo -n "$payload" | sha256sum | cut -d' ' -f1)

    echo "$payload" >> "$LOG_FILE"
    PREV_HASH="$current_hash"

    printf "[%s] %-12s %-8s %s\n" "$DATE_NOW" "$action" "$decision" "${rationale:0:80}"
}

narrate() {
    printf "\n┌──────────────────────────────────────────────────────────────┐\n"
    printf "│ TRIDENT NARRATION: %s\n" "$*"
    printf "└──────────────────────────────────────────────────────────────┘\n\n"
}

ask_override() {
    local check_name="$1"
    read -r -p "ESCALATE → Override this DENY and continue anyway? [y/N] " answer
    if [[ "${answer:-N}" =~ ^[Yy]$ ]]; then
        append_log "$check_name" "Human override accepted" "OVERRIDE" "User explicitly accepted risk"
        return 0
    else
        narrate "Bootstrap aborted per user choice. No changes applied."
        exit 1
    fi
}

# ─── Python / Venv Preflight ─────────────────────────────────────────────────

trident_venv_preflight() {
    narrate "VENV PREFLIGHT – verifying Python isolation"
    append_log "VENV_PREFLIGHT" "Governance kernel initialization" "PERMIT" "Starting Python isolation checks"

    if ! command -v python3 >/dev/null 2>&1; then
        append_log "PYTHON" "python3 not found" "DENY" "Python 3 required"
        narrate "Python3 is required but not found. Install Python 3 and retry."
        exit 1
    else
        append_log "PYTHON" "python3 found" "PERMIT" "Python interpreter available"
    fi

    if ! python3 -m venv --help >/dev/null 2>&1; then
        append_log "VENV_MOD" "venv module missing" "DENY" "Python venv module required"
        narrate "Python venv module missing. Install python3-venv and retry."
        exit 1
    else
        append_log "VENV_MOD" "venv module available" "PERMIT" "Python venv ready"
    fi

    if [[ ! -d "venv" ]]; then
        python3 -m venv venv
        append_log "VENV_DIR" "Created new venv" "PERMIT" "Fresh isolated environment created"
    else
        append_log "VENV_DIR" "Reusing existing venv" "PERMIT" "Reusing isolated environment"
    fi

    source venv/bin/activate
    append_log "VENV_ACT" "Activated venv" "PERMIT" "Python execution now isolated"

    narrate "Python virtual environment activated."
    append_log "VENV_PREFLIGHT" "Python isolation established" "PERMIT" "Venv preflight complete"
}

# ─── Pre-requisite Gates ─────────────────────────────────────────────────────

main() {
    narrate "TRIDENT Bootstrap v${SCRIPT_VERSION} starting"
    append_log "BOOTSTRAP_START" "Script invoked" "PERMIT" "Provenance chain begins"

    trident_venv_preflight

    OS="$(uname -s)"
    case "$OS" in
        Linux*)  append_log "PLATFORM" "Linux detected" "PERMIT" "Preferred production platform" ;;
        Darwin*) append_log "PLATFORM" "macOS detected" "PERMIT" "Supported for development" ;;
        *)
            append_log "PLATFORM" "$OS detected" "DENY" "Unsupported OS family"
            narrate "TRIDENT strongly prefers Linux (native) or macOS. Windows → use WSL2 only."
            exit 1
            ;;
    esac

    if [[ $EUID -eq 0 ]]; then
        append_log "PRIVILEGE" "Running as root (EUID=0)" "DENY" "Principle III – Capability must be earned"
        narrate "Do NOT run bootstrap or OpenClaw as root. Use a dedicated non-root user."
        exit 1
    else
        append_log "PRIVILEGE" "Non-root (EUID=$EUID)" "PERMIT" "Principle III satisfied"
    fi

    pwd_real="$(pwd -P)"
    if [[ "$pwd_real" == "$HOME"* || "$pwd_real" == "/root"* || "$pwd_real" == "/tmp"* ]]; then
        append_log "ISOLATION" "Working dir looks like home/root/tmp → $pwd_real" "ESCALATE" "Weak isolation increases blast radius"
        narrate "Recommendation: run bootstrap from a dedicated project folder outside \$HOME and /tmp. TRIDENT standard path: /opt/trident-bootstrap"
        ask_override "ISOLATION"
    else
        append_log "ISOLATION" "Working dir: $pwd_real" "PERMIT" "Reasonable isolation"
    fi

    if ! command -v node >/dev/null 2>&1; then
        append_log "NODE" "node command not found" "DENY" "Node.js 22+ required"
        narrate "Install Node.js ≥22 (https://nodejs.org or nvm)"
        exit 1
    fi

    node_ver=$(node --version | cut -d. -f1 | tr -d 'v')
    if (( node_ver < 22 )); then
        append_log "NODE" "Node v${node_ver}.x detected" "DENY" "Known vulnerabilities & compatibility issues below v22"
        narrate "Upgrade Node.js to 22+ (nvm install 22; nvm use 22)"
        exit 1
    else
        append_log "NODE" "Node v$(node --version) OK" "PERMIT" "Meets minimum requirement"
    fi

    if command -v docker >/dev/null 2>&1; then
        append_log "DOCKER" "Docker found" "PERMIT" "Strong sandbox capability available"
    else
        append_log "DOCKER" "Docker not found" "ESCALATE" "Runtime sandbox weakened"
        narrate "TRIDENT Gate 4 (Controlled Execution) is significantly stronger with Docker."
        ask_override "DOCKER"
    fi

    narrate "All pre-requisite gates passed (or overridden). Proceeding to intent & install phase."

    read -r -p "Your name / handle (for provenance audit trail): " actor
    actor="${actor:-anonymous-developer}"
    read -r -p "Brief purpose of this OpenClaw instance: " purpose
    purpose="${purpose:-TRIDENT governance development}"

    append_log "INTENT_CAPTURE" "Actor: ${actor} | Purpose: ${purpose}" "PERMIT" "Principle I – Provenance mandatory"

    if command -v openclaw >/dev/null 2>&1; then
        narrate "OpenClaw binary already detected — skipping install step."
        append_log "INSTALL" "openclaw already present" "SKIP" "No action taken"
    else
        narrate "Official install method: curl -fsSL https://openclaw.ai/install.sh | bash"
        read -r -p "Execute official installer now? [y/N] " confirm
        if [[ "${confirm:-N}" =~ ^[Yy]$ ]]; then
            append_log "INSTALL" "User approved official installer" "PERMIT" "Controlled execution"
            curl -fsSL https://openclaw.ai/install.sh | bash
            append_log "INSTALL" "Installer completed" "PERMIT" "Assuming success (check logs)"
        else
            append_log "INSTALL" "User declined installer" "DENY" "Principle I – no unprovenanced execution"
            narrate "Install skipped per policy. Manually install after review."
        fi
    fi

    append_log "BOOTSTRAP_COMPLETE" "Prep finished – last hash: $PREV_HASH" "PERMIT" "Immutable chain established"

    narrate "TRIDENT Bootstrap complete."
    narrate "Audit trail: ${LOG_FILE}"
    narrate "Last chain hash (replay token): ${PREV_HASH}"
}

touch "$LOG_FILE" 2>/dev/null || { echo "Cannot write to ${LOG_FILE} – check permissions"; exit 1; }
main "$@"
exit 0
