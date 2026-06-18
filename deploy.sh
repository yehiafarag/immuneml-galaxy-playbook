#!/usr/bin/env bash
set -Eeuo pipefail

# ========================================================================
# ImmuneML Galaxy Deployment Tool
# ========================================================================
#
# Responsibilities:
#   - Prepare local Ansible control environment
#   - Generate inventory from group_vars/galaxyservers.yml
#   - Install Ansible roles from requirements.yml
#   - Run immuneml.yml
#
# Important:
#   Galaxy baseline deployment is handled inside immuneml.yml
#   through the galaxy_deployment role.
#
# immuneML integration:
#   immuneML Galaxy tools are installed as Galaxy wrapper XML files.
#   The tools use Galaxy-native Conda/Bioconda dependency resolution.
#   We do NOT install immuneML with pip inside Galaxy tool environments.
# ========================================================================

OS_NAME="$(uname -s)"
DEPLOYMENT_MODE="remote"

# ------------------------------------------------------------------------
# Terminal Colors Setup
# ------------------------------------------------------------------------
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

step()    { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
fail()    { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ------------------------------------------------------------------------
# Path Configurations
# ------------------------------------------------------------------------
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$PROJECT_DIR/venv"
LOCAL_TMP="$PROJECT_DIR/.tmp"

CONFIG_FILE="$PROJECT_DIR/group_vars/galaxyservers.yml"
INVENTORY_FILE="$PROJECT_DIR/hosts"
REQUIREMENTS_FILE="$PROJECT_DIR/requirements.yml"
PLAYBOOK="$PROJECT_DIR/immuneml.yml"
ROLES_DIR="$PROJECT_DIR/roles"

DEFAULT_REMOTE_ROOT="/srv/galaxy"

GALAXY_HOST_IP=""
GALAXY_SSH_USER=""
GALAXY_ROOT=""

# ========================================================================
# CONFIGURATION LOADER
# ========================================================================
load_config() {
  step "Loading ImmuneML Galaxy configuration file"

  [[ -f "$CONFIG_FILE" ]] || error "Missing target file: group_vars/galaxyservers.yml"

  if ! command -v yq >/dev/null 2>&1; then
    if [[ -x "$VENV_DIR/bin/yq" ]]; then
      export PATH="$VENV_DIR/bin:$PATH"
    else
      error "yq utility missing. Run option 2 first, or install yq manually."
    fi
  fi

  GALAXY_HOST_IP=$(yq -r '.galaxy.host_ip' "$CONFIG_FILE")
  GALAXY_SSH_USER=$(yq -r '.galaxy.ssh_user' "$CONFIG_FILE")
  GALAXY_ROOT=$(yq -r '.galaxy_base_dir // .galaxy_root // "'"$DEFAULT_REMOTE_ROOT"'"' "$CONFIG_FILE")

  [[ -z "$GALAXY_HOST_IP" || "$GALAXY_HOST_IP" == "null" ]] && error "Missing 'galaxy.host_ip' entry in group_vars/galaxyservers.yml"
  [[ -z "$GALAXY_SSH_USER" || "$GALAXY_SSH_USER" == "null" ]] && error "Missing 'galaxy.ssh_user' entry in group_vars/galaxyservers.yml"

  success "Configuration validated and parsed successfully ✅"
}

# ========================================================================
# DYNAMIC INVENTORY GENERATOR
# ========================================================================
generate_inventory() {
  step "Generating inventory host mapping file"

  if [[ "$DEPLOYMENT_MODE" == "local" ]]; then
    cat > "$INVENTORY_FILE" <<EOF
[galaxyservers]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3

[dbservers]
localhost ansible_connection=local
EOF
  else
    cat > "$INVENTORY_FILE" <<EOF
[galaxyservers]
galaxy ansible_host=$GALAXY_HOST_IP ansible_user=$GALAXY_SSH_USER ansible_become=true ansible_become_method=sudo ansible_python_interpreter=/usr/bin/python3

[dbservers]
galaxy
EOF
  fi

  success "Hosts inventory updated at: $INVENTORY_FILE ✅"
}

# ========================================================================
# CONTROL NODE PREPARATION
# ========================================================================
prepare_control_node() {
  step "Setting up local Python virtual environment execution context"

  mkdir -p "$LOCAL_TMP/ansible_tmp"
  chmod 777 "$LOCAL_TMP/ansible_tmp"
  export ANSIBLE_LOCAL_TEMP="$LOCAL_TMP/ansible_tmp"

  rm -rf "$VENV_DIR"
  python3 -m venv "$VENV_DIR"

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  pip install --upgrade pip setuptools wheel
  pip install ansible yq

  success "Control node operational dependencies established ✅"
}

# ========================================================================
# ROLE INSTALLATION
# ========================================================================
install_roles() {
  step "Installing Galaxy deployment and external Ansible role requirements"

  [[ -f "$REQUIREMENTS_FILE" ]] || error "Missing requirements file: $REQUIREMENTS_FILE"

  mkdir -p "$ROLES_DIR"

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  ansible-galaxy role install \
    -r "$REQUIREMENTS_FILE" \
    -p "$ROLES_DIR" \
    --force

  success "Ansible roles fetched successfully into $ROLES_DIR ✅"
}

# ========================================================================
# PLAYBOOK VALIDATION
# ========================================================================
validate_playbook() {
  load_config
  generate_inventory

  step "Validating ImmuneML orchestrator playbook syntax"

  [[ -f "$PLAYBOOK" ]] || error "Missing playbook: $PLAYBOOK"

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK" --syntax-check

  success "ImmuneML playbook structural check completed successfully ✅"
}

# ========================================================================
# REMOTE INFRASTRUCTURE OPERATIONS
# ========================================================================
test_connection() {
  load_config
  generate_inventory

  step "Testing connection capabilities to remote system host"

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  ansible galaxyservers -i "$INVENTORY_FILE" -m ping \
    || error "Failed to establish a connection with the remote machine over SSH."

  success "Remote SSH authentication successful ✅"
}

deploy_remote() {
  load_config
  generate_inventory

  step "Initiating ImmuneML Galaxy automation play run"
  step "Galaxy baseline deployment is handled inside immuneml.yml through galaxy_deployment"
  step "immuneML Galaxy tools use Conda/Bioconda through Galaxy dependency resolvers"

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  ansible-playbook \
    -i "$INVENTORY_FILE" \
    "$PLAYBOOK" \
    --flush-cache

  success "ImmuneML Galaxy playbook run completed successfully ✅"
}

validate_remote() {
  load_config
  generate_inventory

  step "Running remote Galaxy and immuneML diagnostics"

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  step "Checking Galaxy API endpoint"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m command -a \
    "curl -sf http://127.0.0.1/api/version" \
    || error "Galaxy API endpoint is not responding."

  success "Galaxy API endpoint is responding ✅"

  step "Checking immuneML Galaxy wrapper directory"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m shell -a \
    "test -d /srv/galaxy/server/tools/immuneml && ls /srv/galaxy/server/tools/immuneml/*.xml >/dev/null" \
    || error "immuneML Galaxy wrappers are not installed."

  success "immuneML Galaxy wrapper XML files exist ✅"

  step "Checking immuneML Conda/Bioconda requirement declaration"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m shell -a \
    "grep -RniEi '<requirement[^>]*type=\"package\"[^>]*>[[:space:]]*immuneml[[:space:]]*</requirement>' /srv/galaxy/server/tools/immuneml/*.xml /srv/galaxy/server/tools/immuneml/prod_macros.xml >/dev/null 2>&1" \
    || error "immuneML wrappers do not declare a Galaxy package requirement for immuneML/Conda."

  success "immuneML Galaxy wrappers declare Conda/Bioconda package requirement ✅"

  step "Checking Galaxy dependency resolver configuration"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m shell -a \
    "test -f /srv/galaxy/config/dependency_resolvers_conf.xml && grep -q '<conda' /srv/galaxy/config/dependency_resolvers_conf.xml" \
    || error "Galaxy Conda dependency resolver config is missing or incomplete."

  success "Galaxy Conda dependency resolver config exists ✅"

  step "Checking immuneML datatype registration"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m shell -a \
    "test -f /srv/galaxy/config/datatypes_conf.xml && grep -q 'immuneml_receptors.html' /srv/galaxy/config/datatypes_conf.xml" \
    || error "immuneML datatype registration is missing."

  success "immuneML datatype registration exists ✅"

  step "Checking immuneML welcome page configuration"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m shell -a \
    "grep -q 'welcome_url: /static/welcome_immuneml.html' /srv/galaxy/config/galaxy.yml && test -f /srv/galaxy/server/static/welcome_immuneml.html" \
    || error "immuneML welcome page or welcome_url is not configured correctly."

  success "immuneML welcome page configuration exists ✅"

  step "Checking Galaxy database backend is PostgreSQL"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m shell -a \
    "grep -q 'database_connection: postgresql://' /srv/galaxy/config/galaxy.yml" \
    || error "Galaxy is not configured to use PostgreSQL. SQLite can lock and keep jobs queued."

  success "Galaxy PostgreSQL database configuration exists ✅"

  success "Remote Galaxy and immuneML diagnostics completed ✅"
}

full_remote() {
  prepare_control_node
  install_roles
  validate_playbook
  test_connection
  deploy_remote
  validate_remote

  success "FULL IMMUNEML GALAXY AUTOMATION PIPELINE FINISHED 🚀"
}

# ========================================================================
# LOCAL INSTANCE INFRASTRUCTURE — Linux Only
# ========================================================================
deploy_local() {
  DEPLOYMENT_MODE="local"

  [[ "$OS_NAME" == "Linux" ]] || error "Local system installations are only supported on native Linux targets"

  prepare_control_node
  install_roles
  load_config
  generate_inventory

  step "Executing ImmuneML Galaxy automation against localhost"

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK" --flush-cache

  success "Local ImmuneML Galaxy execution completed successfully ✅"
}

# ========================================================================
# CONFIRMATION HELPER
# ========================================================================
confirm_dangerous_action() {
  local expected="$1"
  local prompt="$2"
  local answer=""

  echo ""
  warn "$prompt"
  warn "This is destructive and cannot be automatically undone."
  read -rp "Type exactly '${expected}' to continue: " answer

  if [[ "$answer" != "$expected" ]]; then
    step "Confirmation did not match. Operation cancelled."
    return 1
  fi

  return 0
}

# ========================================================================
# ENVIRONMENT CLEANUP
# ========================================================================
clean_local() {
  step "Cleaning local execution space assets"

  read -rp "Delete control venv, temporary files, and installed roles? (y/n) [default=n]: " ans
  ans="${ans:-n}"

  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    step "Local deletion operations canceled"
    return 0
  fi

  rm -rf "$VENV_DIR" "$LOCAL_TMP" "$ROLES_DIR"

  success "Local dependency footprints cleared successfully ✅"
}

clean_remote_immuneml() {
  load_config
  generate_inventory

  warn "This removes only immuneML overlay assets from the remote host."
  warn "It does NOT remove Galaxy, PostgreSQL, Nginx, Galaxy datasets, or Conda package caches."

  read -rp "Proceed with remote immuneML overlay cleanup? (y/n): " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { step "Remote immuneML cleanup aborted"; return; }

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  step "Removing legacy pip runtime links if present"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m file -a "path=/usr/local/bin/immune-ml state=absent" || true
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m file -a "path=/usr/local/bin/immune-ml-quickstart state=absent" || true

  step "Removing legacy pip runtime directory if present"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m file -a "path=/srv/galaxy/immuneml state=absent" || true

  step "Removing immuneML Galaxy wrapper source checkout"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m file -a "path=/srv/galaxy/immuneml_tools_source state=absent" || true

  step "Removing active immuneML Galaxy tool wrapper directory"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m file -a "path=/srv/galaxy/server/tools/immuneml state=absent" || true

  step "Removing immuneML welcome source checkout"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m file -a "path=/srv/galaxy/immuneml_welcome_source state=absent" || true

  step "Removing cached Galaxy integrated tool panel"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m file -a "path=/srv/galaxy/mutable/config/integrated_tool_panel.xml state=absent" || true

  warn "Managed blocks in tool_conf.xml, datatypes_conf.xml, and galaxy.yml are not removed by this cleanup."

  success "Remote immuneML overlay cleanup completed ✅"
}

wipe_remote_galaxy_keep_database_and_datasets() {
  load_config
  generate_inventory

  confirm_dangerous_action \
    "WIPE_GALAXY_KEEP_DB_DATASETS" \
    "This will remove Galaxy application/runtime/config files, but keep PostgreSQL database and datasets." \
    || return

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  step "Stopping Galaxy service"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m systemd -a \
    "name=galaxy state=stopped" || true

  step "Stopping nginx to avoid serving partially removed files"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m systemd -a \
    "name=nginx state=stopped" || true

  step "Removing Galaxy application/runtime/config assets while keeping database and datasets"

  ansible galaxyservers -i "$INVENTORY_FILE" -b -m shell -a "
    set -e

    echo 'Keeping PostgreSQL database untouched.'
    echo 'Keeping datasets under ${GALAXY_ROOT}/mutable/datasets if present.'

    rm -rf ${GALAXY_ROOT}/server
    rm -rf ${GALAXY_ROOT}/venv
    rm -rf ${GALAXY_ROOT}/config
    rm -rf ${GALAXY_ROOT}/local_tools
    rm -rf ${GALAXY_ROOT}/immuneml_tools_source
    rm -rf ${GALAXY_ROOT}/immuneml_welcome_source
    rm -rf ${GALAXY_ROOT}/immuneml

    rm -rf ${GALAXY_ROOT}/mutable/cache
    rm -rf ${GALAXY_ROOT}/mutable/config
    rm -rf ${GALAXY_ROOT}/mutable/job_working_directory
    rm -rf ${GALAXY_ROOT}/mutable/dependencies
    rm -rf ${GALAXY_ROOT}/mutable/shed_tools
    rm -rf ${GALAXY_ROOT}/mutable/tool_data

    mkdir -p ${GALAXY_ROOT}/mutable/datasets
    chown -R galaxy:galaxy ${GALAXY_ROOT}/mutable || true
  " || error "Failed to wipe Galaxy while keeping database and datasets."

  success "Galaxy wiped while keeping PostgreSQL database and datasets ✅"
  warn "Next run option 6 or option 12 to redeploy Galaxy."
}

wipe_remote_galaxy_everything() {
  load_config
  generate_inventory

  confirm_dangerous_action \
    "WIPE_GALAXY_EVERYTHING" \
    "This will remove /srv/galaxy, Galaxy runtime, configs, tools, datasets, and attempt to drop the Galaxy PostgreSQL database/user." \
    || return

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  step "Stopping Galaxy service"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m systemd -a \
    "name=galaxy state=stopped" || true

  step "Stopping nginx"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m systemd -a \
    "name=nginx state=stopped" || true

  step "Removing Galaxy systemd service if present"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m shell -a "
    set -e
    systemctl disable galaxy || true
    rm -f /etc/systemd/system/galaxy.service
    systemctl daemon-reload
  " || true

  step "Removing full Galaxy directory tree"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m file -a \
    "path=${GALAXY_ROOT} state=absent" \
    || error "Failed to remove ${GALAXY_ROOT}"

  step "Dropping Galaxy PostgreSQL database and user if present"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m shell -a "
    set -e

    if command -v psql >/dev/null 2>&1; then
      sudo -u postgres psql -tAc \"SELECT 1 FROM pg_database WHERE datname='galaxy'\" | grep -q 1 \
        && sudo -u postgres dropdb galaxy \
        || true

      sudo -u postgres psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='galaxy'\" | grep -q 1 \
        && sudo -u postgres dropuser galaxy \
        || true
    fi
  " || true

  success "Full Galaxy wipe completed ✅"
  warn "Next deployment will be a fresh install."
}

force_redeploy_galaxy() {
  load_config
  generate_inventory

  warn "This will stop Galaxy and rerun the playbook."
  warn "It will NOT delete Galaxy files, database, or datasets."
  warn "Because Galaxy will be stopped, Play 1 should mark the baseline unhealthy and rerun galaxy_deployment."

  read -rp "Proceed with force redeploy? (y/n): " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { step "Force redeploy aborted"; return; }

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  step "Stopping Galaxy service"
  ansible galaxyservers -i "$INVENTORY_FILE" -b -m systemd -a \
    "name=galaxy state=stopped" || true

  step "Running ImmuneML Galaxy playbook after stopping Galaxy"
  ansible-playbook \
    -i "$INVENTORY_FILE" \
    "$PLAYBOOK" \
    --flush-cache

  success "Force redeploy completed ✅"
}

# ========================================================================
# INTERACTIVE INTERFACE NAVIGATION MENU
# ========================================================================
menu() {
  echo ""
  echo "===================================================="
  echo " ImmuneML Galaxy Deployment System"
  echo "===================================================="
  echo "1)  Full automated remote ImmuneML Galaxy deployment"
  echo "2)  Prepare local control environment"
  echo "3)  Install dependent Ansible role packages"
  echo "4)  Run remote system ping connectivity analysis"
  echo "5)  Validate ImmuneML orchestrator playbook syntax"
  echo "6)  Run ImmuneML playbook only"
  echo "7)  Run remote Galaxy and ImmuneML diagnostics"
  echo "8)  Deploy Galaxy server and ImmuneML locally (Linux only)"
  echo "9)  Clean local development dependencies workspace"
  echo "10) Remove remote ImmuneML overlay tool only"
  echo "11) Wipe Galaxy app/config/runtime but KEEP database and datasets"
  echo "12) Force redeploy Galaxy and ImmuneML"
  echo "13) DANGER: Wipe Galaxy, datasets, and Galaxy PostgreSQL database"
  echo "14) Exit"
  echo "----------------------------------------------------"

  read -rp "Action Selection: " c

  case "$c" in
    1) full_remote ;;
    2) prepare_control_node ;;
    3) install_roles ;;
    4) test_connection ;;
    5) validate_playbook ;;
    6) deploy_remote ;;
    7) validate_remote ;;
    8) deploy_local ;;
    9) clean_local ;;
    10) clean_remote_immuneml ;;
    11) wipe_remote_galaxy_keep_database_and_datasets ;;
    12) force_redeploy_galaxy ;;
    13) wipe_remote_galaxy_everything ;;
    14) exit 0 ;;
    *) warn "Selected instruction parameters are invalid." ; menu ;;
  esac
}

# Launch the execution loop interface
menu