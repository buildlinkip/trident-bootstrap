#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# TRIDENT Bootstrap / Prep Pack – v0.3
# Governance kernel bootstrap – February 2026
# Auto-diagnosis, auto-repair, zero-friction operator-grade bootstrap
# https://github.com/openclaw/openclaw
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

LOG_FILE="$(pwd)/bootstrap-log.jsonl"
STATE_DIR="$(pwd)/.trident_state"
PREV_HASH=""
SCRIPT_VERSION="0.3"
DATE_NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DOCTOR_MODE=false

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

narrate_repair() {
    printf "\n┌──────────────────────────────────────────────────────────────┐\n"
    printf "│ TRIDENT AUTO-REPAIR: %s\n" "$*"
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

ask_permission() {
    local action="$1"
    read -r -p "TRIDENT → Proceed with: $action? [Y/n] " answer
    if [[ "${answer:-Y}" =~ ^[Nn]$ ]]; then
        return 1
    fi
    return 0
}

# ─── State Management ────────────────────────────────────────────────────────

init_state_dir() {
    mkdir -p "$STATE_DIR"
}

cache_state() {
    local key="$1"
    local value="$2"
    echo "$value" > "$STATE_DIR/$key"
}

load_state() {
    local key="$1"
    if [[ -f "$STATE_DIR/$key" ]]; then
        cat "$STATE_DIR/$key"
    fi
}

# ─── Gate 1: Filesystem Detection ───────────────────────────────────────────

detect_filesystem() {
    narrate "GATE 1: Filesystem Detection"

    local pwd_real
    pwd_real="$(pwd -P)"

    if [[ "$pwd_real" == /mnt/* ]]; then
        local fs_type
        fs_type=$(stat -f -c %T . 2>/dev/null || echo "unknown")

        append_log "FILESYSTEM" "DrvFS detected at $pwd_real" "DENY" "DrvFS causes symlink corruption, venv failures, permission issues"
        narrate "CRITICAL: You are running on Windows DrvFS mount ($pwd_real)"
        narrate "DrvFS breaks Python venvs, corrupts symlinks, and causes permission issues."
        narrate "TRIDENT REQUIRES native Linux filesystem (ext4/xfs) for reliability."

        cache_state "filesystem_type" "drvfs"

        offer_migration
        exit 1
    else
        local fs_type
        fs_type=$(stat -f -c %T . 2>/dev/null || echo "unknown")
        append_log "FILESYSTEM" "Native filesystem: $fs_type at $pwd_real" "PERMIT" "Safe for venv and symlinks"
        cache_state "filesystem_type" "$fs_type"
    fi
}

offer_migration() {
    narrate "MIGRATION OFFER: Auto-migrate project to /opt/trident-bootstrap?"
    printf "This will:\n"
    printf "  1. Create /opt/trident-bootstrap (requires sudo)\n"
    printf "  2. Copy all files from current directory\n"
    printf "  3. Set proper ownership to current user\n"
    printf "  4. Provide commands to complete migration\n\n"

    if ask_permission "auto-migrate to /opt/trident-bootstrap"; then
        narrate_repair "Migrating project to native Linux filesystem"

        sudo mkdir -p /opt/trident-bootstrap
        sudo cp -r "$(pwd)"/* /opt/trident-bootstrap/ 2>/dev/null || true
        sudo cp -r "$(pwd)"/.[!.]* /opt/trident-bootstrap/ 2>/dev/null || true
        sudo chown -R "$(whoami):$(whoami)" /opt/trident-bootstrap

        append_log "MIGRATION" "Project migrated to /opt/trident-bootstrap" "REPAIR" "DrvFS → native filesystem"

        narrate "Migration complete. Next steps:"
        printf "  cd /opt/trident-bootstrap\n"
        printf "  ./trident-prep.sh\n\n"
        exit 0
    else
        append_log "MIGRATION" "User declined migration" "DENY" "Cannot proceed on DrvFS"
        narrate "Bootstrap cannot proceed on DrvFS. Manually move to native filesystem and retry."
        exit 1
    fi
}

# ─── Gate 2: Dependency Auto-Install ────────────────────────────────────────

check_and_install_deps() {
    narrate "GATE 2: Dependency Auto-Install"

    local missing_deps=()

    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi

    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi

    if ! python3 -m venv --help >/dev/null 2>&1; then
        local py_version
        py_version=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
        missing_deps+=("python${py_version}-venv")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        narrate_repair "Missing dependencies detected: ${missing_deps[*]}"
        append_log "DEPENDENCIES" "Missing: ${missing_deps[*]}" "REPAIR" "Auto-installing system packages"

        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update -qq
            for dep in "${missing_deps[@]}"; do
                narrate_repair "Installing $dep via apt-get"
                sudo apt-get install -y "$dep"
                append_log "DEP_INSTALL" "$dep installed" "PERMIT" "System dependency satisfied"
            done
        elif command -v yum >/dev/null 2>&1; then
            for dep in "${missing_deps[@]}"; do
                narrate_repair "Installing $dep via yum"
                sudo yum install -y "$dep"
                append_log "DEP_INSTALL" "$dep installed" "PERMIT" "System dependency satisfied"
            done
        else
            append_log "DEPENDENCIES" "No package manager found" "DENY" "Cannot auto-install: ${missing_deps[*]}"
            narrate "Install these manually: ${missing_deps[*]}"
            exit 1
        fi
    else
        append_log "DEPENDENCIES" "All dependencies present" "PERMIT" "jq, curl, python3-venv available"
    fi
}

# ─── Gate 3: Venv Integrity Check & Auto-Repair ─────────────────────────────

check_venv_integrity() {
    narrate "GATE 3: Virtual Environment Integrity Check"

    if [[ ! -d "venv" ]]; then
        append_log "VENV_INTEGRITY" "venv directory missing" "REPAIR" "Creating fresh venv"
        create_venv
        return 0
    fi

    local integrity_ok=true
    local issues=()

    if [[ ! -f "venv/bin/activate" ]]; then
        issues+=("Missing venv/bin/activate")
        integrity_ok=false
    fi

    if [[ ! -f "venv/bin/python3" ]]; then
        issues+=("Missing venv/bin/python3")
        integrity_ok=false
    fi

    if [[ ! -f "venv/pyvenv.cfg" ]]; then
        issues+=("Missing venv/pyvenv.cfg")
        integrity_ok=false
    fi

    local venv_path_real
    venv_path_real="$(cd venv && pwd -P)"
    if [[ "$venv_path_real" == /mnt/* ]]; then
        issues+=("venv on DrvFS filesystem")
        integrity_ok=false
    fi

    if [[ -f "venv/bin/python3" ]]; then
        local system_py_version
        local venv_py_version
        system_py_version=$(python3 --version 2>&1 | awk '{print $2}')
        venv_py_version=$(venv/bin/python3 --version 2>&1 | awk '{print $2}')

        if [[ "$system_py_version" != "$venv_py_version" ]]; then
            issues+=("Python version mismatch: system=$system_py_version venv=$venv_py_version")
            integrity_ok=false
        fi
    fi

    if [[ "$integrity_ok" == false ]]; then
        append_log "VENV_INTEGRITY" "Corrupted venv detected: ${issues[*]}" "REPAIR" "Auto-deleting and recreating"
        narrate_repair "Venv integrity compromised: ${issues[*]}"
        narrate_repair "Deleting corrupted venv and recreating"

        rm -rf venv
        create_venv
    else
        append_log "VENV_INTEGRITY" "venv integrity verified" "PERMIT" "All checks passed"
        cache_state "venv_path" "$(cd venv && pwd -P)"
    fi
}

create_venv() {
    narrate_repair "Creating fresh Python virtual environment"

    if ! command -v python3 >/dev/null 2>&1; then
        append_log "PYTHON" "python3 not found" "DENY" "Python 3 required"
        narrate "Python3 is required. Install Python 3 and retry."
        exit 1
    fi

    local py_version
    py_version=$(python3 --version 2>&1 | awk '{print $2}')
    cache_state "python_version" "$py_version"

    python3 -m venv venv
    append_log "VENV_CREATE" "Created venv with Python $py_version" "PERMIT" "Fresh isolated environment"

    source venv/bin/activate
    append_log "VENV_ACTIVATE" "Activated venv" "PERMIT" "Python execution now isolated"

    cache_state "venv_path" "$(cd venv && pwd -P)"
}

# ─── Gate 4: Node.js Version & Auto-Upgrade ─────────────────────────────────

check_and_install_node() {
    narrate "GATE 4: Node.js Version Check & Auto-Upgrade"

    if ! command -v node >/dev/null 2>&1; then
        append_log "NODE" "node not found" "REPAIR" "Auto-installing Node.js 22.x via NodeSource"
        narrate_repair "Node.js not found. Installing Node.js 22.x LTS"

        install_node_22
        return 0
    fi

    local node_ver
    node_ver=$(node --version | cut -d. -f1 | tr -d 'v')

    if (( node_ver < 22 )); then
        append_log "NODE" "Node v${node_ver}.x detected" "REPAIR" "Upgrading to Node.js 22.x for security and compatibility"
        narrate_repair "Node.js version too old (v${node_ver}). Upgrading to v22.x LTS"

        install_node_22
    else
        local full_version
        full_version=$(node --version)
        append_log "NODE" "Node $full_version OK" "PERMIT" "Meets minimum requirement (v22+)"
        cache_state "node_version" "$full_version"
    fi
}

install_node_22() {
    if ask_permission "install Node.js 22.x LTS via NodeSource"; then
        if command -v apt-get >/dev/null 2>&1; then
            narrate_repair "Installing Node.js 22.x via NodeSource repository"
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
            sudo apt-get install -y nodejs
            append_log "NODE_INSTALL" "Node.js 22.x installed" "PERMIT" "NodeSource installation complete"

            local full_version
            full_version=$(node --version)
            cache_state "node_version" "$full_version"
            narrate_repair "Node.js upgraded to $full_version"
        elif command -v yum >/dev/null 2>&1; then
            narrate_repair "Installing Node.js 22.x via NodeSource repository"
            curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
            sudo yum install -y nodejs
            append_log "NODE_INSTALL" "Node.js 22.x installed" "PERMIT" "NodeSource installation complete"

            local full_version
            full_version=$(node --version)
            cache_state "node_version" "$full_version"
            narrate_repair "Node.js upgraded to $full_version"
        else
            append_log "NODE_INSTALL" "No package manager found" "DENY" "Cannot auto-install Node.js"
            narrate "Install Node.js 22+ manually from https://nodejs.org"
            exit 1
        fi
    else
        append_log "NODE_INSTALL" "User declined Node.js upgrade" "DENY" "Cannot proceed without Node.js 22+"
        narrate "Node.js 22+ required. Install manually and retry."
        exit 1
    fi
}

# ─── Gate 5: Docker Check ───────────────────────────────────────────────────

check_docker() {
    narrate "GATE 5: Docker Runtime Check"

    if command -v docker >/dev/null 2>&1; then
        append_log "DOCKER" "Docker found" "PERMIT" "Strong sandbox capability available"
    else
        append_log "DOCKER" "Docker not found" "ESCALATE" "Runtime sandbox weakened without Docker"
        narrate "TRIDENT Gate 4 (Controlled Execution) is significantly stronger with Docker."

        printf "Install Docker? (optional but recommended) [y/N] "
        read -r answer
        if [[ "${answer:-N}" =~ ^[Yy]$ ]]; then
            install_docker
        else
            ask_override "DOCKER"
        fi
    fi
}

install_docker() {
    if command -v apt-get >/dev/null 2>&1; then
        narrate_repair "Installing Docker via apt-get"
        sudo apt-get update -qq
        sudo apt-get install -y docker.io
        sudo systemctl enable --now docker 2>/dev/null || true
        sudo usermod -aG docker "$(whoami)"
        append_log "DOCKER_INSTALL" "Docker installed" "PERMIT" "Sandbox capability enabled"
        narrate_repair "Docker installed. Log out and back in for group changes to take effect."
    else
        narrate "Install Docker manually: https://docs.docker.com/engine/install/"
    fi
}

# ─── Gate 6: Platform & Privilege Checks ────────────────────────────────────

check_platform() {
    narrate "GATE 6: Platform & Privilege Verification"

    local OS
    OS="$(uname -s)"
    case "$OS" in
        Linux*)
            append_log "PLATFORM" "Linux detected" "PERMIT" "Preferred production platform"
            ;;
        Darwin*)
            append_log "PLATFORM" "macOS detected" "PERMIT" "Supported for development"
            ;;
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

    local pwd_real
    pwd_real="$(pwd -P)"
    if [[ "$pwd_real" == "$HOME"* || "$pwd_real" == "/root"* || "$pwd_real" == "/tmp"* ]]; then
        append_log "ISOLATION" "Working dir in home/root/tmp → $pwd_real" "ESCALATE" "Weak isolation increases blast radius"
        narrate "Recommendation: run bootstrap from dedicated project folder. TRIDENT standard: /opt/trident-bootstrap"
        ask_override "ISOLATION"
    else
        append_log "ISOLATION" "Working dir: $pwd_real" "PERMIT" "Reasonable isolation"
    fi
}

# ─── Doctor Mode ─────────────────────────────────────────────────────────────

doctor_mode() {
    narrate "TRIDENT DOCTOR MODE: Environment Diagnostics"
    printf "\n"

    printf "╔════════════════════════════════════════════════════════════════╗\n"
    printf "║  TRIDENT Bootstrap Doctor v%s                                ║\n" "$SCRIPT_VERSION"
    printf "╚════════════════════════════════════════════════════════════════╝\n\n"

    printf "┌─ Filesystem Check ─────────────────────────────────────────────┐\n"
    local pwd_real
    pwd_real="$(pwd -P)"
    local fs_type
    fs_type=$(stat -f -c %T . 2>/dev/null || echo "unknown")
    printf "│ Path:       %s\n" "$pwd_real"
    printf "│ Type:       %s\n" "$fs_type"
    if [[ "$pwd_real" == /mnt/* ]]; then
        printf "│ Status:     ✗ FAIL - DrvFS detected\n"
        printf "│ Action:     Migrate to /opt/trident-bootstrap\n"
    else
        printf "│ Status:     ✓ PASS - Native filesystem\n"
    fi
    printf "└────────────────────────────────────────────────────────────────┘\n\n"

    printf "┌─ Dependency Check ─────────────────────────────────────────────┐\n"
    for cmd in jq curl python3; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf "│ %-10s  ✓ installed\n" "$cmd"
        else
            printf "│ %-10s  ✗ missing\n" "$cmd"
        fi
    done

    if python3 -m venv --help >/dev/null 2>&1; then
        printf "│ %-10s  ✓ installed\n" "python-venv"
    else
        printf "│ %-10s  ✗ missing\n" "python-venv"
    fi
    printf "└────────────────────────────────────────────────────────────────┘\n\n"

    printf "┌─ Python Environment ───────────────────────────────────────────┐\n"
    if command -v python3 >/dev/null 2>&1; then
        local py_ver
        py_ver=$(python3 --version 2>&1)
        printf "│ Version:    %s\n" "$py_ver"
    else
        printf "│ Version:    ✗ not found\n"
    fi

    if [[ -d "venv" ]]; then
        printf "│ Venv:       exists\n"
        local issues=0
        [[ ! -f "venv/bin/activate" ]] && { printf "│   ✗ Missing activate\n"; ((issues++)); }
        [[ ! -f "venv/bin/python3" ]] && { printf "│   ✗ Missing python3\n"; ((issues++)); }
        [[ ! -f "venv/pyvenv.cfg" ]] && { printf "│   ✗ Missing pyvenv.cfg\n"; ((issues++)); }

        if [[ -f "venv/bin/python3" ]]; then
            local sys_py=$(python3 --version 2>&1 | awk '{print $2}')
            local venv_py=$(venv/bin/python3 --version 2>&1 | awk '{print $2}')
            if [[ "$sys_py" != "$venv_py" ]]; then
                printf "│   ✗ Version mismatch (sys=%s venv=%s)\n" "$sys_py" "$venv_py"
                ((issues++))
            fi
        fi

        if (( issues == 0 )); then
            printf "│ Status:     ✓ PASS - integrity verified\n"
        else
            printf "│ Status:     ✗ FAIL - %d issue(s) detected\n" "$issues"
            printf "│ Action:     Run bootstrap to auto-repair\n"
        fi
    else
        printf "│ Venv:       not created\n"
        printf "│ Status:     ✗ FAIL - venv missing\n"
        printf "│ Action:     Run bootstrap to create\n"
    fi
    printf "└────────────────────────────────────────────────────────────────┘\n\n"

    printf "┌─ Node.js Check ────────────────────────────────────────────────┐\n"
    if command -v node >/dev/null 2>&1; then
        local node_ver
        node_ver=$(node --version)
        local node_major
        node_major=$(echo "$node_ver" | cut -d. -f1 | tr -d 'v')
        printf "│ Version:    %s\n" "$node_ver"
        if (( node_major >= 22 )); then
            printf "│ Status:     ✓ PASS - meets requirement (v22+)\n"
        else
            printf "│ Status:     ✗ FAIL - too old (need v22+)\n"
            printf "│ Action:     Run bootstrap to auto-upgrade\n"
        fi
    else
        printf "│ Version:    not installed\n"
        printf "│ Status:     ✗ FAIL - Node.js required\n"
        printf "│ Action:     Run bootstrap to auto-install\n"
    fi
    printf "└────────────────────────────────────────────────────────────────┘\n\n"

    printf "┌─ Platform & Privilege ─────────────────────────────────────────┐\n"
    printf "│ OS:         %s\n" "$(uname -s)"
    printf "│ EUID:       %s\n" "$EUID"
    if [[ $EUID -eq 0 ]]; then
        printf "│ Status:     ✗ FAIL - running as root\n"
    else
        printf "│ Status:     ✓ PASS - non-root user\n"
    fi
    printf "└────────────────────────────────────────────────────────────────┘\n\n"

    printf "┌─ Docker Check ─────────────────────────────────────────────────┐\n"
    if command -v docker >/dev/null 2>&1; then
        local docker_ver
        docker_ver=$(docker --version 2>&1 | head -1)
        printf "│ Version:    %s\n" "$docker_ver"
        printf "│ Status:     ✓ installed\n"
    else
        printf "│ Status:     ✗ not installed (optional)\n"
    fi
    printf "└────────────────────────────────────────────────────────────────┘\n\n"

    printf "╔════════════════════════════════════════════════════════════════╗\n"
    printf "║  To repair issues: ./trident-prep.sh                          ║\n"
    printf "╚════════════════════════════════════════════════════════════════╝\n\n"

    exit 0
}

# ─── Main Bootstrap Flow ─────────────────────────────────────────────────────

main() {
    if [[ "${1:-}" == "--doctor" ]]; then
        DOCTOR_MODE=true
        doctor_mode
    fi

    narrate "TRIDENT Bootstrap v${SCRIPT_VERSION} starting"
    append_log "BOOTSTRAP_START" "Script invoked" "PERMIT" "Provenance chain begins"

    init_state_dir

    detect_filesystem

    check_and_install_deps

    check_venv_integrity

    source venv/bin/activate

    check_and_install_node

    check_platform

    check_docker

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
    narrate "State cache: ${STATE_DIR}"
}

touch "$LOG_FILE" 2>/dev/null || { echo "Cannot write to ${LOG_FILE} – check permissions"; exit 1; }
main "$@"
exit 0
