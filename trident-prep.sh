#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# TRIDENT Bootstrap / Prep Pack – v0.3
# Governance kernel bootstrap – February 2026
# Auto-diagnosis, auto-repair, zero-friction operator-grade bootstrap
# https://github.com/openclaw/openclaw
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

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
    local color
    case "$decision" in
        "PERMIT") color="$GREEN" ;;
        "DENY") color="$RED" ;;
        "REPAIR") color="$YELLOW" ;;
        "OVERRIDE"|"ESCALATE") color="$MAGENTA" ;;
        *) color="$CYAN" ;;
    esac
    printf "${color}[%s] %-12s %-8s %s${RESET}\n" "$DATE_NOW" "$action" "$decision" "${rationale:0:80}"
}

narrate() {
    printf "${BLUE}\n╔══════════════════════════════════════════════════════════════╗${RESET}\n"
    printf "${BLUE}║ ${CYAN}TRIDENT NARRATION:${RESET} %s\n" "$*"
    printf "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}\n\n"
}

narrate_repair() {
    printf "${YELLOW}\n╔══════════════════════════════════════════════════════════════╗${RESET}\n"
    printf "${YELLOW}║ ${WHITE}TRIDENT AUTO-REPAIR:${RESET} %s\n" "$*"
    printf "${YELLOW}╚══════════════════════════════════════════════════════════════╝${RESET}\n\n"
}

ask_override() {
    local check_name="$1"
    printf "${MAGENTA}ESCALATE → Override this DENY and continue anyway? [y/N] ${RESET}"
    read -r answer
    if [[ "${answer:-N}" =~ ^[Yy]$ ]]; then
        append_log "$check_name" "Human override accepted" "OVERRIDE" "User explicitly accepted risk"
        return 0
    else
        narrate "${RED}Bootstrap aborted per user choice. No changes applied.${RESET}"
        exit 1
    fi
}

ask_permission() {
    local action="$1"
    printf "${CYAN}TRIDENT → Proceed with: $action? [Y/n] ${RESET}"
    read -r answer
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
    narrate "${MAGENTA}GATE 1: Filesystem Detection${RESET}"
    local pwd_real
    pwd_real="$(pwd -P)"
    if [[ "$pwd_real" == /mnt/* ]]; then
        local fs_type
        fs_type=$(stat -f -c %T . 2>/dev/null || echo "unknown")
        append_log "FILESYSTEM" "DrvFS detected at $pwd_real" "DENY" "DrvFS causes symlink corruption, venv failures, permission issues"
        narrate "${RED}CRITICAL: You are running on Windows DrvFS mount ($pwd_real)${RESET}"
        narrate "${RED}DrvFS breaks Python venvs, corrupts symlinks, and causes permission issues.${RESET}"
        narrate "${RED}TRIDENT REQUIRES native Linux filesystem (ext4/xfs) for reliability.${RESET}"
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
    narrate "${YELLOW}MIGRATION OFFER: Auto-migrate project to /opt/trident-bootstrap?${RESET}"
    printf "This will:\n"
    printf " 1. Create /opt/trident-bootstrap (requires sudo)\n"
    printf " 2. Copy all files from current directory\n"
    printf " 3. Set proper ownership to current user\n"
    printf " 4. Provide commands to complete migration\n\n"
    if ask_permission "auto-migrate to /opt/trident-bootstrap"; then
        narrate_repair "Migrating project to native Linux filesystem"
        sudo mkdir -p /opt/trident-bootstrap
        sudo cp -r "$(pwd)"/* /opt/trident-bootstrap/ 2>/dev/null || true
        sudo cp -r "$(pwd)"/.[!.]* /opt/trident-bootstrap/ 2>/dev/null || true
        sudo chown -R "$(whoami):$(whoami)" /opt/trident-bootstrap
        append_log "MIGRATION" "Project migrated to /opt/trident-bootstrap" "REPAIR" "DrvFS → native filesystem"
        narrate "Migration complete. Next steps:"
        printf " cd /opt/trident-bootstrap\n"
        printf " ./trident-prep.sh\n\n"
        exit 0
    else
        append_log "MIGRATION" "User declined migration" "DENY" "Cannot proceed on DrvFS"
        narrate "${RED}Bootstrap cannot proceed on DrvFS. Manually move to native filesystem and retry.${RESET}"
        exit 1
    fi
}

# ─── Gate 2: Dependency Auto-Install ────────────────────────────────────────
check_and_install_deps() {
    narrate "${MAGENTA}GATE 2: Dependency Auto-Install${RESET}"
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
            narrate "${RED}Install these manually: ${missing_deps[*]}${RESET}"
            exit 1
        fi
    else
        append_log "DEPENDENCIES" "All dependencies present" "PERMIT" "jq, curl, python3-venv available"
    fi
}

# ─── Gate 3: Venv Integrity Check & Auto-Repair ─────────────────────────────
check_venv_integrity() {
    narrate "${MAGENTA}GATE 3: Virtual Environment Integrity Check${RESET}"
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
        narrate "${RED}Python3 is required. Install Python 3 and retry.${RESET}"
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
    narrate "${MAGENTA}GATE 4: Node.js Version Check & Auto-Upgrade${RESET}"
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
            narrate "${RED}Install Node.js 22+ manually from https://nodejs.org${RESET}"
            exit 1
        fi
    else
        append_log "NODE_INSTALL" "User declined Node.js upgrade" "DENY" "Cannot proceed without Node.js 22+"
        narrate "${RED}Node.js 22+ required. Install manually and retry.${RESET}"
        exit 1
    fi
}

# ─── Gate 5: Docker Check ───────────────────────────────────────────────────
check_docker() {
    narrate "${MAGENTA}GATE 5: Docker Runtime Check${RESET}"
    if command -v docker >/dev/null 2>&1; then
        append_log "DOCKER" "Docker found" "PERMIT" "Strong sandbox capability available"
    else
        append_log "DOCKER" "Docker not found" "ESCALATE" "Runtime sandbox weakened without Docker"
        narrate "${YELLOW}TRIDENT Gate 4 (Controlled Execution) is significantly stronger with Docker.${RESET}"
        printf "${YELLOW}Install Docker? (optional but recommended) [y/N] ${RESET}"
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
        narrate "${RED}Install Docker manually: https://docs.docker.com/engine/install/${RESET}"
    fi
}

# ─── Gate 6: Platform & Privilege Checks ────────────────────────────────────
check_platform() {
    narrate "${MAGENTA}GATE 6: Platform & Privilege Verification${RESET}"
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
            narrate "${RED}TRIDENT strongly prefers Linux (native) or macOS. Windows → use WSL2 only.${RESET}"
            exit 1
            ;;
    esac
    if [[ $EUID -eq 0 ]]; then
        append_log "PRIVILEGE" "Running as root (EUID=0)" "DENY" "Principle III – Capability must be earned"
        narrate "${RED}Do NOT run bootstrap or OpenClaw as root. Use a dedicated non-root user.${RESET}"
        exit 1
    else
        append_log "PRIVILEGE" "Non-root (EUID=$EUID)" "PERMIT" "Principle III satisfied"
    fi
    local pwd_real
    pwd_real="$(pwd -P)"
    if [[ "$pwd_real" == "$HOME"* || "$pwd_real" == "/root"* || "$pwd_real" == "/tmp"* ]]; then
        append_log "ISOLATION" "Working dir in home/root/tmp → $pwd_real" "ESCALATE" "Weak isolation increases blast radius"
        narrate "${YELLOW}Recommendation: run bootstrap from dedicated project folder. TRIDENT standard: /opt/trident-bootstrap${RESET}"
        ask_override "ISOLATION"
    else
        append_log "ISOLATION" "Working dir: $pwd_real" "PERMIT" "Reasonable isolation"
    fi
}

# ─── Doctor Mode ─────────────────────────────────────────────────────────────
doctor_mode() {
    narrate "${WHITE}TRIDENT DOCTOR MODE: Environment Diagnostics${RESET}"
    printf "\n"
    printf "${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}\n"
    printf "${CYAN}║ TRIDENT Bootstrap Doctor v%s                                      ║${RESET}\n" "$SCRIPT_VERSION"
    printf "${CYAN}╚════════════════════════════════════════════════════════════════╝${RESET}\n\n"
    printf "${BLUE}┌─ Filesystem Check ─────────────────────────────────────────────┐${RESET}\n"
    local pwd_real
    pwd_real="$(pwd -P)"
    local fs_type
    fs_type=$(stat -f -c %T . 2>/dev/null || echo "unknown")
    printf "│ Path: %s\n" "$pwd_real"
    printf "│ Type: %s\n" "$fs_type"
    if [[ "$pwd_real" == /mnt/* ]]; then
        printf "│ Status: ${RED}✗ FAIL${RESET} - DrvFS detected\n"
        printf "│ Action: Migrate to /opt/trident-bootstrap\n"
    else
        printf "│ Status: ${GREEN}✓ PASS${RESET} - Native filesystem\n"
    fi
    printf "${BLUE}└────────────────────────────────────────────────────────────────┘${RESET}\n\n"
    printf "${BLUE}┌─ Dependency Check ─────────────────────────────────────────────┐${RESET}\n"
    for cmd in jq curl python3; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf "│ %-10s ${GREEN}✓${RESET} installed\n" "$cmd"
        else
            printf "│ %-10s ${RED}✗${RESET} missing\n" "$cmd"
        fi
    done
    if python3 -m venv --help >/dev/null 2>&1; then
        printf "│ %-10s ${GREEN}✓${RESET} installed\n" "python-venv"
    else
        printf "│ %-10s ${RED}✗${RESET} missing\n" "python-venv"
    fi
    printf "${BLUE}└────────────────────────────────────────────────────────────────┘${RESET}\n\n"
    printf "${BLUE}┌─ Python Environment ───────────────────────────────────────────┐${RESET}\n"
    if command -v python3 >/dev/null 2>&1; then
        local py_ver
        py_ver=$(python3 --version 2>&1)
        printf "│ Version: %s\n" "$py_ver"
    else
        printf "│ Version: ${RED}✗${RESET} not found\n"
    fi
    if [[ -d "venv" ]]; then
        printf "│ Venv: exists\n"
        local issues=0
        [[ ! -f "venv/bin/activate" ]] && { printf "│ ${RED}✗${RESET} Missing activate\n"; ((issues++)); }
        [[ ! -f "venv/bin/python3" ]] && { printf "│ ${RED}✗${RESET} Missing python3\n"; ((issues++)); }
        [[ ! -f "venv/pyvenv.cfg" ]] && { printf "│ ${RED}✗${RESET} Missing pyvenv.cfg\n"; ((issues++)); }
        if [[ -f "venv/bin/python3" ]]; then
            local sys_py=$(python3 --version 2>&1 | awk '{print $2}')
            local venv_py=$(venv/bin/python3 --version 2>&1 | awk '{print $2}')
            if [[ "$sys_py" != "$venv_py" ]]; then
                printf "│ ${RED}✗${RESET} Version mismatch (sys=%s venv=%s)\n" "$sys_py" "$venv_py"
                ((issues++))
            fi
        fi
        if (( issues == 0 )); then
            printf "│ Status: ${GREEN}✓ PASS${RESET} - integrity verified\n"
        else
            printf "│ Status: ${RED}✗ FAIL${RESET} - %d issue(s) detected\n" "$issues"
            printf "│ Action: Run bootstrap to auto-repair\n"
        fi
    else
        printf "│ Venv: not created\n"
        printf "│ Status: ${RED}✗ FAIL${RESET} - venv missing\n"
        printf "│ Action: Run bootstrap to create\n"
    fi
    printf "${BLUE}└────────────────────────────────────────────────────────────────┘${RESET}\n\n"
    printf "${BLUE}┌─ Node.js Check ────────────────────────────────────────────────┐${RESET}\n"
    if command -v node >/dev/null 2>&1; then
        local node_ver
        node_ver=$(node --version)
        local node_major
        node_major=$(echo "$node_ver" | cut -d. -f1 | tr -d 'v')
        printf "│ Version: %s\n" "$node_ver"
        if (( node_major >= 22 )); then
            printf "│ Status: ${GREEN}✓ PASS${RESET} - meets requirement (v22+)\n"
        else
            printf "│ Status: ${RED}✗ FAIL${RESET} - too old (need v22+)\n"
            printf "│ Action: Run bootstrap to auto-upgrade\n"
        fi
    else
        printf "│ Version: not installed\n"
        printf "│ Status: ${RED}✗ FAIL${RESET} - Node.js required\n"
        printf "│ Action: Run bootstrap to auto-install\n"
    fi
    printf "${BLUE}└────────────────────────────────────────────────────────────────┘${RESET}\n\n"
    printf "${BLUE}┌─ Platform & Privilege ─────────────────────────────────────────┐${RESET}\n"
    printf "│ OS: %s\n" "$(uname -s)"
    printf "│ EUID: %s\n" "$EUID"
    if [[ $EUID -eq 0 ]]; then
        printf "│ Status: ${RED}✗ FAIL${RESET} - running as root\n"
    else
        printf "│ Status: ${GREEN}✓ PASS${RESET} - non-root user\n"
    fi
    printf "${BLUE}└────────────────────────────────────────────────────────────────┘${RESET}\n\n"
    printf "${BLUE}┌─ Docker Check ─────────────────────────────────────────────────┐${RESET}\n"
    if command -v docker >/dev/null 2>&1; then
        local docker_ver
        docker_ver=$(docker --version 2>&1 | head -1)
        printf "│ Version: %s\n" "$docker_ver"
        printf "│ Status: ${GREEN}✓${RESET} installed\n"
    else
        printf "│ Status: ${RED}✗${RESET} not installed (optional)\n"
    fi
    printf "${BLUE}└────────────────────────────────────────────────────────────────┘${RESET}\n\n"
    printf "${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}\n"
    printf "${CYAN}║ To repair issues: ./trident-prep.sh                            ║${RESET}\n"
    printf "${CYAN}╚════════════════════════════════════════════════════════════════╝${RESET}\n\n"
    exit 0
}

# ─── Main Bootstrap Flow ─────────────────────────────────────────────────────
main() {
    if [[ "${1:-}" == "--doctor" ]]; then
        DOCTOR_MODE=true
        doctor_mode
    fi
    printf "${WHITE}\n"
    printf "  ██████╗  ██████╗ ███████╗\n"
    printf "  ╚════██╗██╔═████╗██╔════╝\n"
    printf "   █████╔╝██║██╔██║███████╗\n"
    printf "  ██╔═══╝ ████╔╝██║╚════██║\n"
    printf "  ███████╗╚██████╔╝███████║\n"
    printf "  ╚══════╝ ╚═════╝ ╚══════╝\n"
    printf "TRIDENT Bootstrap v${SCRIPT_VERSION}${RESET}\n\n"
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
    narrate "${GREEN}All pre-requisite gates passed (or overridden). Proceeding to intent & install phase.${RESET}"
    printf "${CYAN}Your name / handle (for provenance audit trail): ${RESET}"
    read -r actor
    actor="${actor:-anonymous-developer}"
    printf "${CYAN}Brief purpose of this OpenClaw instance: ${RESET}"
    read -r purpose
    purpose="${purpose:-TRIDENT governance development}"
    append_log "INTENT_CAPTURE" "Actor: ${actor} | Purpose: ${purpose}" "PERMIT" "Principle I – Provenance mandatory"
    if command -v openclaw >/dev/null 2>&1; then
        narrate "OpenClaw binary already detected — skipping install step."
        append_log "INSTALL" "openclaw already present" "SKIP" "No action taken"
    else
        narrate "Official install method: curl -fsSL https://openclaw.ai/install.sh | bash"
        printf "${CYAN}Execute official installer now? [y/N] ${RESET}"
        read -r confirm
        if [[ "${confirm:-N}" =~ ^[Yy]$ ]]; then
            append_log "INSTALL" "User approved official installer" "PERMIT" "Controlled execution"
            curl -fsSL https://openclaw.ai/install.sh | bash
            append_log "INSTALL" "Installer completed" "PERMIT" "Assuming success (check logs)"
        else
            append_log "INSTALL" "User declined installer" "DENY" "Principle I – no unprovenanced execution"
            narrate "${RED}Install skipped per policy. Manually install after review.${RESET}"
        fi
    fi
    append_log "BOOTSTRAP_COMPLETE" "Prep finished – last hash: $PREV_HASH" "PERMIT" "Immutable chain established"
    narrate "${GREEN}TRIDENT Bootstrap complete.${RESET}"
    narrate "Audit trail: ${LOG_FILE}"
    narrate "Last chain hash (replay token): ${PREV_HASH}"
    narrate "State cache: ${STATE_DIR}"
}

touch "$LOG_FILE" 2>/dev/null || { echo "${RED}Cannot write to ${LOG_FILE} – check permissions${RESET}"; exit 1; }
main "$@"
exit 0
