#!/bin/bash
#
# Harness Partner Demo Kit - Startup Script
#
# This script sets up and starts all local infrastructure needed for the demo:
# - Kubernetes cluster (platform-specific):
#   * macOS (Apple Silicon): Colima - native arm64 (default) or amd64 emulation
#   * macOS (Intel): minikube, Rancher Desktop, Docker Desktop, or Colima
#   * Windows: minikube, Rancher Desktop, or Docker Desktop
#   * Linux: minikube or other K8s distributions
# - Prometheus monitoring
# - Docker image builds (backend, test, docs) with buildx: multi-arch (amd64 + arm64)
#   so the same tags work on Harness Cloud and on Apple Silicon clusters
# - Harness resource provisioning via Terraform or OpenTofu
# - Harness delegate installation (Helm), named to match the connectors
#
# Usage: ./start-demo.sh [--skip-docker-build] [--skip-terraform] [--skip-delegate]
#                        [--org <identifier>] [--participant <id>] [--colima-arch native|amd64]
# Every setting is also asked interactively (flags only pre-answer the question).
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Minimum resource requirements for the demo
MIN_CPU_CORES=4
MIN_MEMORY_GB=8

# Temporary directory for background process logs
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Progress spinner function
spinner() {
  local pid=$1
  local message=$2
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0

  while kill -0 $pid 2>/dev/null; do
    i=$(( (i + 1) % ${#spin} ))
    printf "\r${CYAN}${spin:$i:1}${NC} $message"
    sleep 0.1
  done
  printf "\r"
}

# Wait for background process with spinner
wait_with_spinner() {
  local pid=$1
  local message=$2
  spinner $pid "$message" &
  local spinner_pid=$!
  wait $pid
  local exit_code=$?
  kill $spinner_pid 2>/dev/null || true
  wait $spinner_pid 2>/dev/null || true
  return $exit_code
}

# Configuration
SKIP_DOCKER_BUILD=false
SKIP_TERRAFORM=false
SKIP_DELEGATE=false
PARTICIPANT_FLAG=""
COLIMA_MODE_FLAG=""
ORG_FLAG=""
SKIP_DOCKER_BUILD_FLAG=false
CONFIG_FILE=".demo-config"
PROJECT_NAME=""
PROJECT_IDENTIFIER=""
IAC_CMD=""  # Will be set to 'terraform' or 'tofu' (OpenTofu)

# Load project name from config if available (for display purposes)
if [ -f "$CONFIG_FILE" ]; then
  PROJECT_NAME=$(grep "PROJECT_NAME=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-)
  PROJECT_IDENTIFIER=$(grep "PROJECT_IDENTIFIER=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
fi
# Default to "Base Demo" if not set
PROJECT_NAME=${PROJECT_NAME:-Base Demo}
PROJECT_IDENTIFIER=${PROJECT_IDENTIFIER:-Base_Demo}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-docker-build)
      SKIP_DOCKER_BUILD=true
      SKIP_DOCKER_BUILD_FLAG=true
      shift
      ;;
    --skip-terraform)
      SKIP_TERRAFORM=true
      shift
      ;;
    --skip-delegate)
      SKIP_DELEGATE=true
      shift
      ;;
    --participant)
      PARTICIPANT_FLAG="${2:-}"
      PARTICIPANT_FLAG_SET=true
      shift 2
      ;;
    --colima-arch)
      COLIMA_MODE_FLAG="${2:-}"
      shift 2
      ;;
    --org)
      ORG_FLAG="${2:-}"
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: ./start-demo.sh [--skip-docker-build] [--skip-terraform] [--skip-delegate] [--org <identifier>] [--participant <id>] [--colima-arch native|amd64]"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Harness Partner Demo Kit - Startup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print status messages
print_status() {
  echo -e "${GREEN}✓${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

print_info() {
  echo -e "${YELLOW}ℹ${NC} $1"
}

print_section() {
  echo ""
  echo -e "${BLUE}▶ $1${NC}"
  echo "----------------------------------------"
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/demo-lib.sh
source "$SCRIPT_DIR/scripts/demo-lib.sh"

# Participant ID: lets several people share one Harness project without collisions.
# Asked on every run (previous answer is the default); --participant pre-answers it.
ensure_participant_id() {
  if [ "$PARTICIPANT_RESOLVED" = true ]; then
    return 0
  fi
  local previous ans
  previous=$(config_get "$CONFIG_FILE" PARTICIPANT_ID)
  if [ "$PARTICIPANT_FLAG_SET" = true ]; then
    PARTICIPANT_ID="$PARTICIPANT_FLAG"
  else
    echo ""
    echo "Participant ID - needed when several people share one Harness project."
    echo "Use the ID your workshop lead gave you (e.g. 'alex'). It's appended to everything"
    echo "this kit creates (workshop_k8s_alex, Dev alex, alex-k8s-delegate, ...)."
    echo "Leave it empty only if nobody else uses the project."
    if [ -n "$previous" ]; then
      read -r -p "Participant ID [$previous] (type 'none' for no ID): " ans
      ans=${ans:-$previous}
    else
      read -r -p "Participant ID (Enter for none): " ans
    fi
    [ "$ans" = "none" ] && ans=""
    PARTICIPANT_ID=$(normalize_participant_id "$ans")
  fi
  while ! is_valid_participant_id "$PARTICIPANT_ID"; do
    print_error "Participant ID '$PARTICIPANT_ID' is invalid (1-20 lowercase letters/digits, starting with a letter)"
    read -r -p "Participant ID (Enter for none): " ans
    PARTICIPANT_ID=$(normalize_participant_id "$ans")
  done
  if [ -n "$previous" ] && [ "$PARTICIPANT_ID" != "$previous" ]; then
    print_info "Participant ID changed from '$previous' - Terraform will create a new set of resources for '$PARTICIPANT_ID'"
  fi
  if [ -n "$PARTICIPANT_ID" ]; then
    print_status "Participant ID: $PARTICIPANT_ID (delegate: $(delegate_name_for "$PARTICIPANT_ID"))"
  else
    print_info "No participant ID (single-user names; delegate: local-k8s-delegate)"
  fi
  config_set "$CONFIG_FILE" PARTICIPANT_ID "$PARTICIPANT_ID"
  PARTICIPANT_RESOLVED=true
}

print_harness_pat_instructions() {
  echo ""
  echo "You need a Harness API token (used by Terraform and cleanup scripts)."
  echo ""
  echo "Create one in the Harness UI:"
  echo "  1. Click your profile (bottom-left) > My API Keys & Tokens"
  echo "  2. Under My API Keys, open your key (or click + API Key to create one)"
  echo "  3. Click + Token on that key — creating an API key alone is not enough"
  echo "  4. Set permissions to All resources / All scopes (or Admin/API access)"
  echo "  5. Copy the token immediately — it is shown only once and starts with pat."
  echo ""
  echo "Optional: export DEMO_BASE_PAT=\"pat.xxx\" before running this script."
  echo ""
}

validate_harness_pat() {
  local pat="$1"
  local account_id="$2"

  if [ -z "$pat" ] || [ -z "$account_id" ]; then
    return 1
  fi

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" -X GET \
    "https://app.harness.io/ng/api/user/currentUser?accountIdentifier=${account_id}" \
    -H "x-api-key: ${pat}" \
    -H "Content-Type: application/json" 2>/dev/null)

  [ "$http_code" = "200" ]
}

prompt_for_harness_pat() {
  while true; do
    print_harness_pat_instructions
    read -p "Enter your Harness PAT: " HARNESS_PAT

    if [ -z "$HARNESS_PAT" ]; then
      print_error "PAT cannot be empty"
      continue
    fi

    print_info "Validating Harness PAT..."
    if validate_harness_pat "$HARNESS_PAT" "$HARNESS_ACCOUNT_ID"; then
      print_status "Harness PAT validated"
      return 0
    fi

    print_error "That token is not valid for account ${HARNESS_ACCOUNT_ID}"
    print_info "Common causes: token expired/revoked, or you created an API key but not a + Token under it"
  done
}

ensure_valid_harness_pat() {
  local source_label="$1"

  print_info "Validating Harness PAT from ${source_label}..."
  if validate_harness_pat "$HARNESS_PAT" "$HARNESS_ACCOUNT_ID"; then
    print_status "Harness PAT validated"
    return 0
  fi

  print_error "Harness PAT from ${source_label} is invalid or expired"
  print_info "Generate a new token: Profile > My API Keys & Tokens > your key > + Token"
  prompt_for_harness_pat
}

# Check Kubernetes cluster resources (CPU and memory)
check_cluster_resources() {
  print_section "Checking Cluster Resources"

  # Wait for cluster to be ready (API server may need a moment after fresh start)
  print_info "Waiting for cluster API to be ready..."
  local retries=0
  local max_retries=30
  while [ $retries -lt $max_retries ]; do
    if kubectl get nodes &> /dev/null; then
      print_status "Cluster API is ready"
      break
    fi
    retries=$((retries + 1))
    sleep 2
  done

  if [ $retries -eq $max_retries ]; then
    print_error "Cluster API did not become ready in time"
    return 1
  fi

  # Get node resources using kubectl with jsonpath for more reliable parsing
  local cpu_raw memory_raw
  cpu_raw=$(kubectl get nodes -o jsonpath='{.items[0].status.allocatable.cpu}' 2>/dev/null || true)
  memory_raw=$(kubectl get nodes -o jsonpath='{.items[0].status.allocatable.memory}' 2>/dev/null || true)

  if [ -z "$cpu_raw" ] || [ -z "$memory_raw" ]; then
    print_error "Cannot retrieve cluster node information"
    return 1
  fi

  # Parse CPU (convert millicores to cores if needed)
  local cpu_cores
  if [[ "$cpu_raw" == *m ]]; then
    cpu_cores=$(( ${cpu_raw%m} / 1000 ))
  else
    cpu_cores=$cpu_raw
  fi

  # Parse memory (convert to GB) - handle Ki suffix properly
  local memory_gb
  local memory_num
  case "$memory_raw" in
    *Gi)
      memory_gb=${memory_raw%Gi}
      ;;
    *G)
      memory_gb=${memory_raw%G}
      ;;
    *Mi)
      memory_num=${memory_raw%Mi}
      memory_gb=$(( memory_num / 1024 ))
      ;;
    *Ki)
      memory_num=${memory_raw%Ki}
      # Use awk for larger numbers to avoid bash integer overflow
      memory_gb=$(echo "$memory_num" | awk '{printf "%.0f", $1 / 1024 / 1024}')
      ;;
    *)
      # Raw bytes - use awk for large numbers
      memory_gb=$(echo "$memory_raw" | awk '{printf "%.0f", $1 / 1024 / 1024 / 1024}')
      ;;
  esac

  # Ensure memory_gb is a valid number (default to 0 if parsing failed)
  if ! [[ "$memory_gb" =~ ^[0-9]+$ ]]; then
    memory_gb=0
  fi

  print_info "Cluster resources: ${cpu_cores} CPU cores, ${memory_gb}GB memory"

  local resources_ok=true

  # Check CPU
  if [ "$cpu_cores" -lt "$MIN_CPU_CORES" ]; then
    print_error "Insufficient CPU: ${cpu_cores} cores (minimum: ${MIN_CPU_CORES} cores)"
    resources_ok=false
  else
    print_status "CPU: ${cpu_cores} cores (minimum: ${MIN_CPU_CORES})"
  fi

  # Check memory
  if [ "$memory_gb" -lt "$MIN_MEMORY_GB" ]; then
    print_error "Insufficient memory: ${memory_gb}GB (minimum: ${MIN_MEMORY_GB}GB)"
    resources_ok=false
  else
    print_status "Memory: ${memory_gb}GB (minimum: ${MIN_MEMORY_GB}GB)"
  fi

  if [ "$resources_ok" = false ]; then
    echo ""
    print_error "Cluster does not meet minimum resource requirements"
    echo ""
    echo "The demo requires at least ${MIN_CPU_CORES} CPU cores and ${MIN_MEMORY_GB}GB memory."
    echo ""

    # Offer automatic remediation for Colima and minikube
    if [ "$K8S_TYPE" = "colima" ]; then
      echo "Would you like to automatically restart Colima with the correct resources?"
      echo "This will stop and delete the current Colima VM, then create a new one."
      echo ""
      read -p "Restart Colima with ${MIN_CPU_CORES} CPUs and ${MIN_MEMORY_GB}GB memory? [Y/n]: " RESTART_COLIMA
      RESTART_COLIMA=${RESTART_COLIMA:-yes}

      if [[ "$RESTART_COLIMA" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        print_info "Stopping Colima..."
        colima stop 2>/dev/null || true
        print_info "Deleting Colima VM and runtime data..."
        colima delete -f --data 2>/dev/null || true
        print_info "Starting Colima with correct resources (this may take 5-10 minutes)..."
        if [ "$OS_TYPE" = "macos" ] && ([ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]); then
          # shellcheck disable=SC2046
          if colima start $(colima_mode_args "${COLIMA_MODE:-native}") --cpu ${MIN_CPU_CORES} --memory ${MIN_MEMORY_GB} --kubernetes --runtime docker; then
            print_status "Colima restarted successfully with ${MIN_CPU_CORES} CPUs and ${MIN_MEMORY_GB}GB memory"
            return 0  # Resources are now OK
          else
            print_error "Failed to restart Colima"
            exit 1
          fi
        else
          if colima start --cpu ${MIN_CPU_CORES} --memory ${MIN_MEMORY_GB} --kubernetes; then
            print_status "Colima restarted successfully with ${MIN_CPU_CORES} CPUs and ${MIN_MEMORY_GB}GB memory"
            return 0  # Resources are now OK
          else
            print_error "Failed to restart Colima"
            exit 1
          fi
        fi
      else
        echo ""
        echo "To manually increase Colima resources:"
        echo "  colima stop"
        echo "  colima delete --data"
        if [ "$OS_TYPE" = "macos" ] && ([ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]); then
          echo "  colima start $(colima_mode_args "${COLIMA_MODE:-native}") --cpu ${MIN_CPU_CORES} --memory ${MIN_MEMORY_GB} --kubernetes --runtime docker"
        else
          echo "  colima start --cpu ${MIN_CPU_CORES} --memory ${MIN_MEMORY_GB} --kubernetes"
        fi
      fi
    elif [ "$K8S_TYPE" = "minikube" ]; then
      echo "Would you like to automatically restart minikube with the correct resources?"
      echo "This will stop and delete the current minikube cluster, then create a new one."
      echo ""
      read -p "Restart minikube with ${MIN_CPU_CORES} CPUs and ${MIN_MEMORY_GB}GB memory? [Y/n]: " RESTART_MINIKUBE
      RESTART_MINIKUBE=${RESTART_MINIKUBE:-yes}

      if [[ "$RESTART_MINIKUBE" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        print_info "Stopping minikube..."
        minikube stop 2>/dev/null || true
        print_info "Deleting minikube cluster..."
        minikube delete 2>/dev/null || true
        print_info "Starting minikube with correct resources..."
        if minikube start --cpus=${MIN_CPU_CORES} --memory=${MIN_MEMORY_GB}g; then
          print_status "minikube restarted successfully with ${MIN_CPU_CORES} CPUs and ${MIN_MEMORY_GB}GB memory"
          minikube addons enable metrics-server &> /dev/null || true
          return 0  # Resources are now OK
        else
          print_error "Failed to restart minikube"
          exit 1
        fi
      else
        echo ""
        echo "To manually increase minikube resources:"
        echo "  minikube stop"
        echo "  minikube delete"
        echo "  minikube start --cpus=${MIN_CPU_CORES} --memory=${MIN_MEMORY_GB}g"
      fi
    elif [ "$K8S_TYPE" = "docker-desktop" ]; then
      echo "To increase Docker Desktop resources:"
      echo "  1. Open Docker Desktop > Settings > Resources"
      echo "  2. Set CPUs to at least ${MIN_CPU_CORES}"
      echo "  3. Set Memory to at least ${MIN_MEMORY_GB}GB"
      echo "  4. Click 'Apply & Restart'"
    elif [ "$K8S_TYPE" = "rancher-desktop" ]; then
      echo "To increase Rancher Desktop resources:"
      echo "  1. Open Rancher Desktop > Preferences > Virtual Machine"
      echo "  2. Set CPUs to at least ${MIN_CPU_CORES}"
      echo "  3. Set Memory to at least ${MIN_MEMORY_GB}GB"
      echo "  4. Click 'Apply'"
    else
      echo "Please increase your Kubernetes cluster resources to at least:"
      echo "  - CPU: ${MIN_CPU_CORES} cores"
      echo "  - Memory: ${MIN_MEMORY_GB}GB"
    fi
    echo ""

    read -p "Continue anyway? (not recommended) [y/N]: " CONTINUE_ANYWAY
    if [[ ! "$CONTINUE_ANYWAY" =~ ^[Yy]$ ]]; then
      print_error "Exiting. Please increase cluster resources and try again."
      exit 1
    fi
    print_info "Continuing with insufficient resources (may experience issues)..."
  else
    print_status "Cluster resources are sufficient for the demo"
  fi
}

# Detect Operating System and Architecture
print_section "Detecting Platform"

OS_TYPE="unknown"
ARCH=$(uname -m)

case "$(uname -s)" in
  Darwin*)
    OS_TYPE="macos"
    print_status "Operating System: macOS"
    ;;
  Linux*)
    OS_TYPE="linux"
    print_status "Operating System: Linux"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    OS_TYPE="windows"
    print_status "Operating System: Windows (Git Bash/MSYS/Cygwin)"
    print_info "See README.md 'Windows Users' section for setup guidance"
    ;;
  *)
    print_error "Unknown operating system: $(uname -s)"
    exit 1
    ;;
esac

print_info "Architecture: $ARCH"

# Check for required Kubernetes tool based on OS and architecture
print_section "Checking Kubernetes Tool"

K8S_TOOL_MISSING=false
RECOMMENDED_TOOL=""

if [ "$OS_TYPE" = "macos" ] && ([ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]); then
  # Apple Silicon Mac - Colima, either native arm64 (default) or amd64 emulation
  RECOMMENDED_TOOL="Colima"

  # Native vs amd64: --colima-arch flag > COLIMA_ARCH_MODE in .demo-config > prompt
  COLIMA_MODE=$(choose_colima_mode "$COLIMA_MODE_FLAG" "$(config_get "$CONFIG_FILE" COLIMA_ARCH_MODE)")
  config_set "$CONFIG_FILE" COLIMA_ARCH_MODE "$COLIMA_MODE"
  if [ "$COLIMA_MODE" = "amd64" ]; then
    print_info "Colima mode: amd64 emulation (qemu; slower)"
  else
    print_status "Colima mode: native arm64 (amd64-only images run via Rosetta)"
  fi

  # Check for all required dependencies (qemu is only needed to emulate amd64)
  REQUIRED_DEPS="colima docker kubectl"
  [ "$COLIMA_MODE" = "amd64" ] && REQUIRED_DEPS="$REQUIRED_DEPS qemu lima-additional-guestagents"
  MISSING_DEPS=""
  for dep in $REQUIRED_DEPS; do
    case "$dep" in
      qemu|lima-additional-guestagents) brew list "$dep" &> /dev/null || MISSING_DEPS="$MISSING_DEPS $dep" ;;
      *) command -v "$dep" &> /dev/null || MISSING_DEPS="$MISSING_DEPS $dep" ;;
    esac
  done

  if [ -n "$MISSING_DEPS" ]; then
    print_error "Missing required dependencies for Apple Silicon:$MISSING_DEPS"
    echo ""
    echo "To install them:"
    echo "  brew install$MISSING_DEPS"
    echo ""

    # Offer to install missing dependencies
    read -p "Would you like to install missing dependencies now? [Y/n]: " INSTALL_DEPS
    INSTALL_DEPS=${INSTALL_DEPS:-yes}

    if [[ "$INSTALL_DEPS" =~ ^[Yy]([Ee][Ss])?$ ]]; then
      print_info "Installing missing dependencies via Homebrew..."
      # shellcheck disable=SC2086
      if brew install $MISSING_DEPS; then
        print_status "Dependencies installed successfully"
      else
        print_error "Failed to install dependencies. Please install manually:"
        echo "  brew install$MISSING_DEPS"
        K8S_TOOL_MISSING=true
      fi
    else
      echo ""
      echo "After installing, start Colima with:"
      echo "  $(colima_start_cmd "$COLIMA_MODE")"
      echo ""
      K8S_TOOL_MISSING=true
    fi
  fi

  if [ "$K8S_TOOL_MISSING" != true ] && command -v colima &> /dev/null; then
    print_status "Colima is installed"
    if colima status &> /dev/null; then
      # Ask the Docker daemon inside the VM what it actually runs on. (Don't trust
      # colima.yaml's vmType: an x86_64 VM on Apple Silicon silently runs under qemu.)
      COLIMA_ARCH=$(docker_daemon_arch)
      if arch_matches_mode "$COLIMA_MODE" "$COLIMA_ARCH"; then
        print_status "Colima is running ($COLIMA_ARCH) as chosen"
      else
        print_error "Colima is running $COLIMA_ARCH, but you chose '$COLIMA_MODE'"
        echo ""
        echo "Switching requires recreating the Colima VM, including its data disk"
        echo "(the old cluster's data would otherwise break Kubernetes on the new VM)."
        echo ""
        read -p "Recreate Colima as '$COLIMA_MODE' now? [Y/n]: " RESTART_COLIMA
        RESTART_COLIMA=${RESTART_COLIMA:-yes}

        if [[ "$RESTART_COLIMA" =~ ^[Yy]([Ee][Ss])?$ ]]; then
          print_info "Stopping Colima..."
          colima stop
          print_info "Deleting Colima VM and its data disk..."
          colima delete --data -f
          print_info "Starting Colima ($COLIMA_MODE; first run may take a few minutes)..."
          # shellcheck disable=SC2046
          colima start $(colima_mode_args "$COLIMA_MODE") $COLIMA_RESOURCE_ARGS
          print_status "Colima started ($COLIMA_MODE)"
        else
          print_info "Keeping the current Colima VM ($COLIMA_ARCH)"
          if arch_matches_mode native "$COLIMA_ARCH"; then COLIMA_MODE=native; else COLIMA_MODE=amd64; fi
          config_set "$CONFIG_FILE" COLIMA_ARCH_MODE "$COLIMA_MODE"
        fi
      fi
    else
      print_info "Colima is not running - starting it now ($COLIMA_MODE)..."
      echo ""
      # shellcheck disable=SC2046
      if colima start $(colima_mode_args "$COLIMA_MODE") $COLIMA_RESOURCE_ARGS; then
        print_status "Colima started successfully"
      else
        # A leftover VM/data disk from a different architecture or runtime can block start
        print_info "Start failed - retrying with a clean Colima VM (deleting old VM data)..."
        colima delete --data -f 2>/dev/null || true
        # shellcheck disable=SC2046
        if colima start $(colima_mode_args "$COLIMA_MODE") $COLIMA_RESOURCE_ARGS; then
          print_status "Colima started successfully"
        else
          print_error "Failed to start Colima"
          echo ""
          echo "Please try starting manually:"
          echo "  colima delete --data"
          echo "  $(colima_start_cmd "$COLIMA_MODE")"
          echo ""
          K8S_TOOL_MISSING=true
        fi
      fi
    fi
  fi
elif [ "$OS_TYPE" = "windows" ]; then
  # Windows - recommend minikube but allow other options
  RECOMMENDED_TOOL="minikube"
  if ! command -v minikube &> /dev/null; then
    print_info "minikube is not installed (recommended for Windows)"
    echo ""
    echo "For Windows, we recommend minikube for running Kubernetes locally."
    echo ""
    echo "To install minikube:"
    echo "  Visit: https://minikube.sigs.k8s.io/docs/start/"
    echo ""
    echo "Alternative options:"
    echo "  - Docker Desktop with Kubernetes enabled"
    echo "  - Rancher Desktop with Kubernetes enabled"
    echo ""
    read -p "Do you have Docker Desktop or Rancher Desktop with Kubernetes? [y/N]: " HAS_ALTERNATIVE
    if [[ ! "$HAS_ALTERNATIVE" =~ ^[Yy]$ ]]; then
      print_error "No Kubernetes tool detected. Please install one of the options above."
      K8S_TOOL_MISSING=true
    else
      print_info "Proceeding with alternative Kubernetes tool"
    fi
  else
    print_status "minikube is installed"
  fi
else
  # macOS Intel or Linux - flexible options
  if [ "$OS_TYPE" = "macos" ]; then
    RECOMMENDED_TOOL="minikube, Colima, Docker Desktop, or Rancher Desktop"
  else
    RECOMMENDED_TOOL="minikube or your preferred K8s distribution"
  fi

  # Check for common tools
  if command -v minikube &> /dev/null; then
    print_status "minikube is installed"
  elif command -v colima &> /dev/null; then
    print_status "Colima is installed"
  elif kubectl config current-context 2>/dev/null | grep -q "docker-desktop"; then
    print_status "Docker Desktop with Kubernetes detected"
  elif kubectl config current-context 2>/dev/null | grep -q "rancher-desktop"; then
    print_status "Rancher Desktop detected"
  else
    print_info "No common Kubernetes tool detected"
    echo ""
    echo "Please ensure you have one of the following installed and running:"
    echo "  - minikube: https://minikube.sigs.k8s.io/docs/start/"
    echo "  - Colima: brew install colima"
    echo "  - Docker Desktop: https://www.docker.com/products/docker-desktop/"
    echo "  - Rancher Desktop: https://rancherdesktop.io/"
    echo ""
    read -p "Do you have Kubernetes running with kubectl configured? [y/N]: " HAS_K8S
    if [[ ! "$HAS_K8S" =~ ^[Yy]$ ]]; then
      print_error "No Kubernetes tool detected. Please install one of the options above."
      K8S_TOOL_MISSING=true
    else
      print_info "Proceeding with your Kubernetes setup"
    fi
  fi
fi

if [ "$K8S_TOOL_MISSING" = true ]; then
  print_error "Required Kubernetes tool not found: $RECOMMENDED_TOOL"
  echo ""
  print_info "Setup instructions: see README.md or CLAUDE.md for platform-specific setup"
  exit 1
fi

# Check prerequisites
print_section "Checking Prerequisites"

# Check Docker
if ! command -v docker &> /dev/null; then
  print_error "Docker is not installed. Please install Docker Desktop or Docker Engine."
  exit 1
fi
print_status "Docker found: $(docker --version | head -n1)"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
  print_error "kubectl is not installed. Please install kubectl."
  exit 1
fi
print_status "kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>&1 | head -n1)"

# Verify Docker daemon is ready
print_info "Checking container runtime availability..."
if docker info &> /dev/null; then
  print_status "Docker daemon is running"
else
  print_error "Docker daemon is not running"
  echo ""
  echo "Please start Docker Desktop or your container runtime platform."
  exit 1
fi

# Detect Kubernetes environment
print_section "Detecting Kubernetes Environment"

K8S_TYPE=""
if kubectl config current-context 2>/dev/null | grep -q "colima"; then
  K8S_TYPE="colima"
  print_status "Detected Colima"
  # Verify architecture for Colima on Apple Silicon
  if [ "$OS_TYPE" = "macos" ] && ([ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]); then
    # Wait for cluster to be ready before checking architecture
    print_info "Checking cluster architecture (waiting for API to be ready)..."
    CLUSTER_ARCH=""
    ARCH_RETRIES=0
    ARCH_MAX_RETRIES=30
    while [ $ARCH_RETRIES -lt $ARCH_MAX_RETRIES ]; do
      CLUSTER_ARCH=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.architecture}' 2>/dev/null || true)
      if [ -n "$CLUSTER_ARCH" ]; then
        break
      fi
      ARCH_RETRIES=$((ARCH_RETRIES + 1))
      sleep 2
    done

    if [ -z "$CLUSTER_ARCH" ]; then
      print_error "Could not determine cluster architecture (API not ready after 60 seconds)"
      exit 1
    fi

    if arch_matches_mode "${COLIMA_MODE:-native}" "$CLUSTER_ARCH"; then
      print_status "Cluster architecture: $CLUSTER_ARCH (matches '${COLIMA_MODE:-native}' mode)"
    else
      print_error "Cluster is running $CLUSTER_ARCH, but Colima mode is '${COLIMA_MODE:-native}'"
      echo ""
      echo "Recreate Colima (including its data disk) in the chosen mode:"
      echo "  colima stop && colima delete --data -f"
      echo "  $(colima_start_cmd "${COLIMA_MODE:-native}")"
      echo "Or rerun with --colima-arch native|amd64 to match the running cluster."
      exit 1
    fi
  fi
elif kubectl config current-context 2>/dev/null | grep -q "minikube"; then
  K8S_TYPE="minikube"
  print_status "Detected minikube"
elif kubectl config current-context 2>/dev/null | grep -q "rancher-desktop"; then
  K8S_TYPE="rancher-desktop"
  print_status "Detected Rancher Desktop"
elif kubectl config current-context 2>/dev/null | grep -q "docker-desktop"; then
  K8S_TYPE="docker-desktop"
  print_status "Detected Docker Desktop"
else
  # Try to connect to see if any cluster is available
  if kubectl cluster-info &> /dev/null; then
    K8S_TYPE="other"
    print_status "Detected Kubernetes cluster: $(kubectl config current-context)"
  else
    print_error "No Kubernetes cluster detected."
    echo ""
    if [ "$OS_TYPE" = "macos" ] && ([ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]); then
      echo "For Apple Silicon Macs, start Colima:"
      echo "  $(colima_start_cmd "${COLIMA_MODE:-native}")"
    else
      echo "Please ensure one of the following is running:"
      echo "  - minikube (run 'minikube start')"
      echo "  - Colima (run 'colima start --kubernetes')"
      echo "  - Rancher Desktop with Kubernetes enabled"
      echo "  - Docker Desktop with Kubernetes enabled"
    fi
    exit 1
  fi
fi

# Start Colima if needed
if [ "$K8S_TYPE" = "colima" ]; then
  # Colima should already be running if we got here, but verify
  if ! colima status &> /dev/null; then
    print_info "Starting Colima (this may take 5-10 minutes on first run)..."
    if [ "$OS_TYPE" = "macos" ] && ([ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]); then
      # shellcheck disable=SC2046
      colima start $(colima_mode_args "${COLIMA_MODE:-native}") $COLIMA_RESOURCE_ARGS
    else
      colima start --cpu 4 --memory 8 --kubernetes
    fi
    print_status "Colima started successfully"
  fi
fi

# Start minikube if needed
if [ "$K8S_TYPE" = "minikube" ]; then
  print_section "Starting minikube"

  if minikube status | grep -q "host: Running"; then
    print_status "minikube is already running"
  else
    print_info "Starting minikube (this may take a few minutes)..."
    minikube start
    print_status "minikube started successfully"
  fi

  # Enable metrics-server
  print_info "Ensuring metrics-server addon is enabled..."
  minikube addons enable metrics-server &> /dev/null
  print_status "metrics-server addon enabled"
fi

# Verify cluster connectivity
print_section "Verifying Cluster Connectivity"

# Wait for cluster API to be ready (may need a moment after fresh start)
print_info "Waiting for cluster API to be ready..."
RETRIES=0
MAX_RETRIES=30
while [ $RETRIES -lt $MAX_RETRIES ]; do
  if kubectl cluster-info &> /dev/null; then
    print_status "Successfully connected to Kubernetes cluster"
    print_info "Cluster: $(kubectl config current-context)"
    break
  fi
  RETRIES=$((RETRIES + 1))
  sleep 2
done

if [ $RETRIES -eq $MAX_RETRIES ]; then
  print_error "Cannot connect to Kubernetes cluster after waiting 60 seconds"
  echo ""
  echo "Troubleshooting tips:"
  if [ "$K8S_TYPE" = "colima" ]; then
    echo "  1. Check Colima status: colima status"
    if [ "$OS_TYPE" = "macos" ] && ([ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]); then
      echo "  2. Try restarting Colima: colima stop && $(colima_start_cmd "${COLIMA_MODE:-native}")"
    else
      echo "  2. Try restarting Colima: colima stop && colima start --cpu 4 --memory 8 --kubernetes"
    fi
  elif [ "$K8S_TYPE" = "minikube" ]; then
    echo "  1. Check minikube status: minikube status"
    echo "  2. Try restarting minikube: minikube stop && minikube start"
  fi
  echo "  3. Check kubectl config: kubectl config current-context"
  exit 1
fi

# Check cluster resources (CPU and memory)
check_cluster_resources

# Ensure harness-delegate-ng namespace exists (for delegate installation later)
print_info "Ensuring harness-delegate-ng namespace exists..."
if ! kubectl get namespace harness-delegate-ng &> /dev/null; then
  kubectl create namespace harness-delegate-ng &> /dev/null
  print_status "Created harness-delegate-ng namespace"
else
  print_status "harness-delegate-ng namespace already exists"
fi

# Create Docker Hub secret for pulling images
print_section "Creating Docker Hub Secret for Image Pulls"

# This secret allows Kubernetes to pull Harness CI addon images (harness/ci-addon, etc.)
# Harness CI looks for a secret named 'dockerhub-pull'

# Load Docker credentials from config file
CONFIG_FILE=".demo-config"
if [ -f "$CONFIG_FILE" ]; then
  DOCKER_USERNAME=$(grep "DOCKER_USERNAME=" "$CONFIG_FILE" | cut -d'=' -f2)
  DOCKER_PAT=$(grep "DOCKER_PAT=" "$CONFIG_FILE" | cut -d'=' -f2)
fi

# Check if we have credentials
if [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_PAT" ] && [ "$DOCKER_PAT" != "logged-in-via-docker-desktop" ]; then
  print_info "Creating Docker Hub pull secret with saved credentials..."

  # Create secret in default namespace
  if kubectl get secret dockerhub-pull -n default &> /dev/null; then
    print_info "Updating existing Docker Hub secret in default namespace..."
    kubectl delete secret dockerhub-pull -n default &> /dev/null
  fi

  kubectl create secret docker-registry dockerhub-pull \
    --docker-server=https://index.docker.io/v1/ \
    --docker-username="$DOCKER_USERNAME" \
    --docker-password="$DOCKER_PAT" \
    --docker-email="${DOCKER_USERNAME}@example.com" \
    -n default &> /dev/null

  if [ $? -eq 0 ]; then
    print_status "Docker Hub secret created in default namespace"
  else
    print_error "Failed to create Docker Hub secret in default namespace"
  fi

  # Create secret in harness-delegate-ng namespace
  if kubectl get secret dockerhub-pull -n harness-delegate-ng &> /dev/null; then
    print_info "Updating existing Docker Hub secret in harness-delegate-ng namespace..."
    kubectl delete secret dockerhub-pull -n harness-delegate-ng &> /dev/null
  fi

  kubectl create secret docker-registry dockerhub-pull \
    --docker-server=https://index.docker.io/v1/ \
    --docker-username="$DOCKER_USERNAME" \
    --docker-password="$DOCKER_PAT" \
    --docker-email="${DOCKER_USERNAME}@example.com" \
    -n harness-delegate-ng &> /dev/null

  if [ $? -eq 0 ]; then
    print_status "Docker Hub secret created in harness-delegate-ng namespace"

    # Attach secret to default service account
    kubectl patch serviceaccount default -n harness-delegate-ng -p '{"imagePullSecrets": [{"name": "dockerhub-pull"}]}' &> /dev/null
    print_status "Attached secret to default service account in harness-delegate-ng"
  else
    print_error "Failed to create Docker Hub secret in harness-delegate-ng namespace"
  fi

  # Attach secret to default service account in default namespace
  kubectl patch serviceaccount default -n default -p '{"imagePullSecrets": [{"name": "dockerhub-pull"}]}' &> /dev/null
  print_status "Attached secret to default service account in default namespace"
else
  print_info "Docker credentials not available yet, skipping secret creation"
  print_info "The secret will be created after Docker authentication"
fi

# Deploy Prometheus (non-blocking - runs in background)
print_section "Deploying Prometheus (Background)"

# Function to deploy Prometheus in background
deploy_prometheus_background() {
  {
    # Check if monitoring namespace exists
    if ! kubectl get namespace monitoring &> /dev/null; then
      kubectl create namespace monitoring 2>/dev/null
    fi

    # Check if Prometheus is already deployed and running
    if kubectl get pods -n monitoring -l app=prometheus 2>/dev/null | grep -q "Running"; then
      echo "ALREADY_RUNNING" > "$TEMP_DIR/prometheus_status"
    elif kubectl get deployment -n monitoring prometheus-deployment &> /dev/null; then
      kubectl -n monitoring delete -f kit/prometheus.yml --ignore-not-found=true &> /dev/null
      sleep 3
      kubectl -n monitoring apply -f kit/prometheus.yml &> /dev/null
      kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=120s &> /dev/null
      echo "REDEPLOYED" > "$TEMP_DIR/prometheus_status"
    else
      kubectl -n monitoring apply -f kit/prometheus.yml &> /dev/null
      kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=120s &> /dev/null
      echo "DEPLOYED" > "$TEMP_DIR/prometheus_status"
    fi
  } &> "$TEMP_DIR/prometheus.log"
  echo $? > "$TEMP_DIR/prometheus_exit_code"
}

# Check if already running before starting background deployment
if kubectl get pods -n monitoring -l app=prometheus 2>/dev/null | grep -q "Running"; then
  print_status "Prometheus is already running"
  PROMETHEUS_PID=""
else
  print_info "Prometheus deployment started in background..."
  deploy_prometheus_background &
  PROMETHEUS_PID=$!
fi

# Build and push Docker images? (--skip-docker-build pre-answers "no")
if [ "$SKIP_DOCKER_BUILD_FLAG" != true ]; then
  echo ""
  echo "Build and push the demo's Docker images (backend, test, docs) to your Docker Hub?"
  echo "Answer Yes on your first run, after changing code, or after changing your project"
  echo "name or participant ID (the lab guides are built into the docs image)."
  read -r -p "Build images? [Y/n]: " BUILD_ANSWER
  if [[ "$BUILD_ANSWER" =~ ^[Nn] ]]; then
    SKIP_DOCKER_BUILD=true
  fi
fi

if [ "$SKIP_DOCKER_BUILD" = false ]; then
  print_section "Building Backend Docker Image"

  # Prompt for project name early (needed for documentation personalization)
  # Full validation with existence check happens in the Terraform section
  if [ "$PROJECT_NAME" = "Base Demo" ]; then
    echo ""
    echo "Choose a name for your Harness project"
    echo "This will be displayed in the Harness UI (e.g., 'Partner Workshop', 'ACME Demo')"
    echo ""
    echo "Note: Cannot use reserved words like: project, org, account, pipeline, service, etc."
    echo ""
    read -p "Enter your Harness Project name [Base Demo]: " USER_PROJECT_NAME

    # Default to "Base Demo" if empty
    USER_PROJECT_NAME=${USER_PROJECT_NAME:-Base Demo}

    # Reserved words that cannot be used as project names
    RESERVED_WORDS="project org account pipeline service environment connector secret template infrastructure delegate trigger artifact manifest variable input output stage step group"

    # Function to check if a word is reserved (local to this block)
    check_reserved() {
      local word=$(echo "$1" | tr '[:upper:]' '[:lower:]')
      for reserved in $RESERVED_WORDS; do
        if [ "$word" = "$reserved" ]; then
          return 0
        fi
      done
      return 1
    }

    # Validate project name - reserved words check only
    VALID_NAME=false
    while [ "$VALID_NAME" = false ]; do
      RESERVED_FOUND=false
      for word in $USER_PROJECT_NAME; do
        if check_reserved "$word"; then
          print_error "'$word' is a reserved word and cannot be used in the project name"
          RESERVED_FOUND=true
          break
        fi
      done

      if [ "$RESERVED_FOUND" = true ]; then
        read -p "Enter a different project name: " USER_PROJECT_NAME
        USER_PROJECT_NAME=${USER_PROJECT_NAME:-Base Demo}
      else
        VALID_NAME=true
      fi
    done

    PROJECT_NAME="$USER_PROJECT_NAME"
    # Generate identifier from name (alphanumeric and underscores only)
    PROJECT_IDENTIFIER=$(echo "$PROJECT_NAME" | sed 's/[^a-zA-Z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_//' | sed 's/_$//')
    print_status "Project name set to: $PROJECT_NAME"
    print_info "Project identifier: $PROJECT_IDENTIFIER"
    echo ""
  fi

  print_info "Checking Docker Hub authentication..."

  # Configuration file to store username
  CONFIG_FILE=".demo-config"
  DOCKER_USERNAME=""
  DOCKER_LOGIN_PASSWORD=""
  LOGGED_IN_USER=""

  # Check if already logged in and get current username
  LOGGED_IN_USER=$(docker info 2>/dev/null | grep "Username:" | awk '{print $2}')

  if [ -n "$LOGGED_IN_USER" ]; then
    print_status "Detected Docker Hub session: $LOGGED_IN_USER"
  fi

  # Load cached username/password if available
  if [ -f "$CONFIG_FILE" ]; then
    DOCKER_USERNAME=$(grep "DOCKER_USERNAME=" "$CONFIG_FILE" | cut -d'=' -f2)
    DOCKER_LOGIN_PASSWORD=$(grep "DOCKER_PAT=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
  fi

  if [ -n "$DOCKER_USERNAME" ]; then
    case "$DOCKER_USERNAME" in
      username|dockerhubaccountid|your-username|your-dockerhub-username|DOCKERHUB_USERNAME)
        print_info "Found placeholder username in saved config: $DOCKER_USERNAME"
        print_info "Please provide your actual Docker Hub username"
        DOCKER_USERNAME=""
        ;;
      *)
        print_info "Found saved Docker Hub username: $DOCKER_USERNAME"
        ;;
    esac
  fi

  # Try to get username from Terraform config if still not found
  if [ -z "$DOCKER_USERNAME" ] && [ -f "kit/se-parms.tfvars" ]; then
    DOCKER_USERNAME=$(grep docker_username kit/se-parms.tfvars | cut -d'"' -f2 2>/dev/null || echo "")

    # Check if username looks like a placeholder
    if [ -n "$DOCKER_USERNAME" ]; then
      case "$DOCKER_USERNAME" in
        username|dockerhubaccountid|your-username|your-dockerhub-username|DOCKERHUB_USERNAME)
          print_info "Found placeholder username in kit/se-parms.tfvars: $DOCKER_USERNAME"
          print_info "Please provide your actual Docker Hub username"
          DOCKER_USERNAME=""
          ;;
        *)
          print_info "Found Docker Hub username in kit/se-parms.tfvars: $DOCKER_USERNAME"
          ;;
      esac
    fi
  fi

  # Fall back to currently logged-in user if no cached username
  if [ -z "$DOCKER_USERNAME" ] && [ -n "$LOGGED_IN_USER" ]; then
    DOCKER_USERNAME="$LOGGED_IN_USER"
    print_status "Using Docker Desktop session for user: $DOCKER_USERNAME"
  fi

  # Prompt for username if still not found or was a placeholder
  if [ -z "$DOCKER_USERNAME" ]; then
    echo ""
    read -p "Enter your Docker Hub username: " DOCKER_USERNAME

    # Validate that username is not empty
    while [ -z "$DOCKER_USERNAME" ]; do
      print_error "Username cannot be empty"
      read -p "Enter your Docker Hub username: " DOCKER_USERNAME
    done
  fi

  # Load cached password/PAT
  if [ -f "$CONFIG_FILE" ]; then
    DOCKER_LOGIN_PASSWORD=$(grep "DOCKER_PAT=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
  fi

  if [ -z "$DOCKER_LOGIN_PASSWORD" ] && [ -f "kit/se-parms.tfvars" ]; then
    DOCKER_LOGIN_PASSWORD=$(grep DOCKER_PAT kit/se-parms.tfvars | cut -d'"' -f2 2>/dev/null || echo "")
  fi

  if [ "$DOCKER_LOGIN_PASSWORD" = "logged-in-via-docker-desktop" ]; then
    DOCKER_LOGIN_PASSWORD=""
  fi

  NEED_DOCKER_LOGIN=false

  # If we have cached credentials, ALWAYS use them to login
  # This ensures we have a fresh auth token even if docker info shows a logged-in user
  if [ -n "$DOCKER_LOGIN_PASSWORD" ]; then
    print_status "Using cached Docker Hub credentials"
    NEED_DOCKER_LOGIN=true
  elif [ -n "$LOGGED_IN_USER" ] && [ "$LOGGED_IN_USER" = "$DOCKER_USERNAME" ]; then
    # Only trust existing session if we don't have cached credentials
    print_status "Using existing Docker Hub session for: $LOGGED_IN_USER"
    print_info "Note: If push fails, you may need to re-authenticate"
  else
    echo ""
    print_info "You need to provide your Docker Hub password or Personal Access Token (PAT)"
    print_info "To create a PAT: https://hub.docker.com/settings/security"
    echo ""
    read -sp "Enter your Docker Hub password/PAT: " DOCKER_LOGIN_PASSWORD
    echo ""

    # Validate that password is not empty
    while [ -z "$DOCKER_LOGIN_PASSWORD" ]; do
      print_error "Password/PAT cannot be empty"
      read -sp "Enter your Docker Hub password/PAT: " DOCKER_LOGIN_PASSWORD
      echo ""
    done
    NEED_DOCKER_LOGIN=true
  fi

  if [ "$NEED_DOCKER_LOGIN" = true ]; then
    echo ""
    if [ -n "$LOGGED_IN_USER" ] && [ "$LOGGED_IN_USER" != "$DOCKER_USERNAME" ]; then
      print_info "Logging in to Docker Hub as $DOCKER_USERNAME (overriding existing session)..."
    else
      print_info "Logging in to Docker Hub as $DOCKER_USERNAME..."
    fi

    # Verify we have a password to use
    if [ -z "$DOCKER_LOGIN_PASSWORD" ]; then
      print_error "Docker password is empty - cannot log in"
      echo ""
      read -sp "Enter your Docker Hub password/PAT: " DOCKER_LOGIN_PASSWORD
      echo ""
    fi

    # Attempt Docker login
    set +e
    LOGIN_OUTPUT=$(printf '%s' "$DOCKER_LOGIN_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin 2>&1)
    LOGIN_EXIT_CODE=$?
    set -e

    # Retry on network timeout (Docker daemon may need a moment after fresh start)
    if [ $LOGIN_EXIT_CODE -ne 0 ] && echo "$LOGIN_OUTPUT" | grep -q "Client.Timeout exceeded\|connection timed out\|connection refused"; then
      print_info "Docker daemon may still be initializing, retrying login in 5 seconds..."
      sleep 5
      set +e
      LOGIN_OUTPUT=$(printf '%s' "$DOCKER_LOGIN_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin 2>&1)
      LOGIN_EXIT_CODE=$?
      set -e
    fi

    if [ $LOGIN_EXIT_CODE -eq 0 ]; then
      print_status "Successfully logged in to Docker Hub"
    else
      # Check if it's a credential helper error
      if echo "$LOGIN_OUTPUT" | grep -q "docker-credential.*executable file not found"; then
        print_info "Docker credential helper not found, configuring direct credential storage..."

        # Backup existing Docker config if it exists
        if [ -f ~/.docker/config.json ]; then
          cp ~/.docker/config.json ~/.docker/config.json.backup.$(date +%s) 2>/dev/null || true
        fi

        # Create or update Docker config to not use credential helper
        mkdir -p ~/.docker
        if [ -f ~/.docker/config.json ]; then
          # Remove credsStore from existing config
          cat ~/.docker/config.json | grep -v '"credsStore"' > ~/.docker/config.json.tmp
          mv ~/.docker/config.json.tmp ~/.docker/config.json
        else
          echo '{}' > ~/.docker/config.json
        fi

        # Retry Docker login
        print_info "Retrying Docker login..."
        set +e
        LOGIN_OUTPUT=$(printf '%s' "$DOCKER_LOGIN_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin 2>&1)
        LOGIN_EXIT_CODE=$?
        set -e

        if [ $LOGIN_EXIT_CODE -eq 0 ]; then
          print_status "Successfully logged in to Docker Hub"
        else
          print_error "Docker login failed. Please check your credentials."
          exit 1
        fi
      else
        # Distinguish between network and authentication errors
        if echo "$LOGIN_OUTPUT" | grep -q "Client.Timeout exceeded\|connection timed out\|connection refused\|network\|dial"; then
          print_error "Docker login failed: Network connectivity issue"
          echo ""
          echo "$LOGIN_OUTPUT"
          echo ""
          print_info "Possible causes:"
          print_info "  - Docker daemon not fully ready (wait a moment and retry)"
          print_info "  - Network connectivity issues"
          print_info "  - Firewall blocking Docker Hub access"
          echo ""
          print_info "Try rerunning: ./start-demo.sh"
        elif echo "$LOGIN_OUTPUT" | grep -q "unauthorized\|incorrect\|denied"; then
          print_error "Docker login failed: Invalid credentials"
          echo ""
          echo "$LOGIN_OUTPUT"
          echo ""
          print_info "Please verify your Docker Hub username and password/PAT"
          print_info "Delete .demo-config and re-run to enter new credentials"
        else
          print_error "Docker login failed: $LOGIN_OUTPUT"
          print_error "Please check your credentials and try again."
        fi
        exit 1
      fi
    fi

    # Save Docker credentials for future runs if they aren't stored yet
    # (preserves anything else already in the config, e.g. saved by the Terraform section)
    if [ -z "$(config_get "$CONFIG_FILE" DOCKER_PAT)" ]; then
      config_set "$CONFIG_FILE" DOCKER_USERNAME "$DOCKER_USERNAME"
      config_set "$CONFIG_FILE" DOCKER_PAT "$DOCKER_LOGIN_PASSWORD"
      print_info "Saved credentials to $CONFIG_FILE for future runs"
    fi
  fi

  # Architecture of the Docker daemon (the Colima VM on Macs)
  DOCKER_ARCH=$(docker_daemon_arch)
  print_info "Docker daemon architecture: ${DOCKER_ARCH:-unknown}"

  # buildx (BuildKit) builds amd64 + arm64 images under one tag, so the same images run on
  # Harness Cloud (amd64) and on native Apple Silicon clusters (arm64)
  if ! ensure_buildx; then
    print_info "Continuing with the legacy builder: images will be ${DOCKER_ARCH:-the local architecture} only"
  fi

  # Participant ID is needed now: the lab docs are personalized with it
  ensure_participant_id

  # Personalize the lab documentation in a temporary copy (the repo's markdown is untouched)
  DOCS_BUILD_DIR="$TEMP_DIR/docs-build"
  print_info "Personalizing lab documentation..."
  echo "   'dockerhubaccountid' -> '$DOCKER_USERNAME', 'Base Demo' -> '$PROJECT_NAME'"
  if [ -n "$PARTICIPANT_ID" ]; then
    echo "   Resource names include your participant ID '$PARTICIPANT_ID'"
  fi
  if personalize_docs "$SCRIPT_DIR" "$DOCS_BUILD_DIR" "$DOCKER_USERNAME" "$PROJECT_NAME" "$PROJECT_IDENTIFIER" "$PARTICIPANT_ID"; then
    print_status "Documentation personalized"
  else
    print_error "Could not prepare the documentation build"
  fi

  print_section "Building Docker Images"
  echo ""
  print_info "Building 3 images: backend, test, docs (platforms: $DEMO_BUILD_PLATFORMS)"
  echo ""

  BUILD_FAILED=false

  print_info "Building backend image..."
  if ! build_and_push_image backend "$DOCKER_USERNAME/harness-demo:backend-latest"; then
    print_error "Backend image build/push failed"
    BUILD_FAILED=true
  fi

  print_info "Building test image..."
  if ! build_and_push_image python-tests "$DOCKER_USERNAME/harness-demo:test-latest"; then
    print_error "Test image build/push failed (non-critical)"
  fi

  print_info "Building docs image..."
  if ! build_and_push_image "$DOCS_BUILD_DIR" "$DOCKER_USERNAME/harness-demo:docs-latest"; then
    print_error "Docs image build/push failed (non-critical)"
  fi

  # Exit if backend build failed (critical)
  if [ "$BUILD_FAILED" = true ]; then
    echo ""
    echo "To fix Docker push issues:"
    echo "  • Go to https://hub.docker.com/repository/create"
    echo "  • Create a repository named: harness-demo"
    echo "  • Make it public or private (your choice)"
    echo "  • Then re-run: ./start-demo.sh"
    exit 1
  fi

  # Now create/update Docker Hub secret with authenticated credentials
  print_section "Updating Docker Hub Secret for Image Pulls"

  if [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_LOGIN_PASSWORD" ]; then
    print_info "Creating/updating Docker Hub pull secret with authenticated credentials..."

    # Create secret in default namespace
    if kubectl get secret dockerhub-pull -n default &> /dev/null; then
      kubectl delete secret dockerhub-pull -n default &> /dev/null
    fi

    kubectl create secret docker-registry dockerhub-pull \
      --docker-server=https://index.docker.io/v1/ \
      --docker-username="$DOCKER_USERNAME" \
      --docker-password="$DOCKER_LOGIN_PASSWORD" \
      --docker-email="${DOCKER_USERNAME}@example.com" \
      -n default &> /dev/null

    if [ $? -eq 0 ]; then
      print_status "Docker Hub secret created/updated in default namespace"
    else
      print_error "Failed to create Docker Hub secret in default namespace"
    fi

    # Create secret in harness-delegate-ng namespace
    if kubectl get secret dockerhub-pull -n harness-delegate-ng &> /dev/null; then
      kubectl delete secret dockerhub-pull -n harness-delegate-ng &> /dev/null
    fi

    kubectl create secret docker-registry dockerhub-pull \
      --docker-server=https://index.docker.io/v1/ \
      --docker-username="$DOCKER_USERNAME" \
      --docker-password="$DOCKER_LOGIN_PASSWORD" \
      --docker-email="${DOCKER_USERNAME}@example.com" \
      -n harness-delegate-ng &> /dev/null

    if [ $? -eq 0 ]; then
      print_status "Docker Hub secret created/updated in harness-delegate-ng namespace"

      # Attach secret to default service account
      kubectl patch serviceaccount default -n harness-delegate-ng -p '{"imagePullSecrets": [{"name": "dockerhub-pull"}]}' &> /dev/null
      print_status "Attached secret to service account in harness-delegate-ng"
    else
      print_error "Failed to create Docker Hub secret in harness-delegate-ng namespace"
    fi

    # Attach secret to default service account in default namespace
    kubectl patch serviceaccount default -n default -p '{"imagePullSecrets": [{"name": "dockerhub-pull"}]}' &> /dev/null
    print_status "Attached secret to service account in default namespace"
  fi
else
  print_info "Skipping Docker image build (existing images on Docker Hub will be used)"
fi

# Configure and run Terraform
if [ "$SKIP_TERRAFORM" = false ]; then
  print_section "Configuring Harness Resources"

  # Configuration file
  CONFIG_FILE=".demo-config"

  # Start terraform/tofu init early in background (if no state file and only one IaC tool is installed)
  # This runs while user enters credentials, saving time
  # Note: If both terraform and tofu are installed, we skip early init since we need to ask user which to use
  EARLY_TF_INIT_PID=""
  if [ ! -f "kit/terraform.tfstate" ] || [ ! -s "kit/terraform.tfstate" ]; then
    # Detect IaC tools
    HAS_TF_EARLY=false
    HAS_TOFU_EARLY=false
    if command -v terraform &> /dev/null; then HAS_TF_EARLY=true; fi
    if command -v tofu &> /dev/null; then HAS_TOFU_EARLY=true; fi

    # Only start early init if exactly one tool is available (not both)
    if [ "$HAS_TF_EARLY" = true ] && [ "$HAS_TOFU_EARLY" = false ]; then
      IAC_CMD="terraform"
      print_info "Starting terraform init in background (parallel with credential collection)..."
      (
        cd kit
        terraform init > "$TEMP_DIR/terraform_init.log" 2>&1
        echo $? > "$TEMP_DIR/terraform_init.exit"
      ) &
      EARLY_TF_INIT_PID=$!
    elif [ "$HAS_TOFU_EARLY" = true ] && [ "$HAS_TF_EARLY" = false ]; then
      IAC_CMD="tofu"
      print_info "Starting tofu init in background (parallel with credential collection)..."
      (
        cd kit
        tofu init > "$TEMP_DIR/terraform_init.log" 2>&1
        echo $? > "$TEMP_DIR/terraform_init.exit"
      ) &
      EARLY_TF_INIT_PID=$!
    fi
    # If both are installed, don't start early init - wait for user choice
  fi

  # Collect required variables (or load from cache)
  HARNESS_ACCOUNT_ID=""
  HARNESS_PAT=""
  DOCKER_PAT=""

  print_info "Checking cached credentials..."
  echo ""

  # Get Harness Account ID
  # Try to get account_id from config file first
  if [ -f "$CONFIG_FILE" ]; then
    HARNESS_ACCOUNT_ID=$(grep "HARNESS_ACCOUNT_ID=" "$CONFIG_FILE" | cut -d'=' -f2)
    HARNESS_ORG_ID=$(grep "HARNESS_ORG_ID=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
  fi
  # Org that holds the demo project (most accounts use "default"; partner accounts may differ)
  HARNESS_ORG_ID=${HARNESS_ORG_ID:-default}

  # Try to get from se-parms.tfvars if not found
  if [ -z "$HARNESS_ACCOUNT_ID" ] && [ -f "kit/se-parms.tfvars" ]; then
    HARNESS_ACCOUNT_ID=$(grep account_id kit/se-parms.tfvars | cut -d'"' -f2 2>/dev/null || echo "")
    # Check if it's a placeholder
    if [[ "$HARNESS_ACCOUNT_ID" == *"harness account id"* ]] || [[ "$HARNESS_ACCOUNT_ID" == *"VEuU4vZ6QmSJZcgvnccqYQ"* ]]; then
      HARNESS_ACCOUNT_ID=""
    fi
  fi

  # Prompt if not found
  if [ -z "$HARNESS_ACCOUNT_ID" ]; then
    echo "Your Harness Account ID can be found in the URL when viewing your profile"
    echo "Example: https://app.harness.io/ng/account/VEuU4vZ6QmSJZcgvnccqYQ/settings/overview"
    echo "         (the ID is: VEuU4vZ6QmSJZcgvnccqYQ)"
    echo ""
    read -p "Enter your Harness Account ID: " HARNESS_ACCOUNT_ID

    while [ -z "$HARNESS_ACCOUNT_ID" ]; do
      print_error "Account ID cannot be empty"
      read -p "Enter your Harness Account ID: " HARNESS_ACCOUNT_ID
    done
  else
    print_status "Using cached Harness Account ID: $HARNESS_ACCOUNT_ID"
  fi

  # Get Harness PAT
  # Check environment variable first
  if [ -n "$DEMO_BASE_PAT" ]; then
    HARNESS_PAT="$DEMO_BASE_PAT"
    print_status "Using Harness PAT from DEMO_BASE_PAT environment variable"
    ensure_valid_harness_pat "DEMO_BASE_PAT"
  else
    # Try to get from config file
    if [ -f "$CONFIG_FILE" ]; then
      HARNESS_PAT=$(grep "HARNESS_PAT=" "$CONFIG_FILE" | cut -d'=' -f2)
    fi

    # Prompt if not found
    if [ -z "$HARNESS_PAT" ]; then
      prompt_for_harness_pat
    else
      print_status "Using cached Harness PAT"
      ensure_valid_harness_pat ".demo-config"
    fi
  fi

  # Harness organization (asked every run; --org pre-answers it)
  HARNESS_ORG_ID=$(choose_harness_org "$HARNESS_ACCOUNT_ID" "$ORG_FLAG" "$HARNESS_ORG_ID")
  print_status "Organization: $HARNESS_ORG_ID"

  # Get Docker password/PAT
  # Try to get from config file first
  if [ -f "$CONFIG_FILE" ]; then
    DOCKER_PAT=$(grep "DOCKER_PAT=" "$CONFIG_FILE" | cut -d'=' -f2)
  fi

  # If still not found, use a placeholder (should have been saved during Docker build section)
  if [ -z "$DOCKER_PAT" ]; then
    # Check if we're logged in to Docker Hub (might have been logged in via Docker Desktop on first run)
    LOGGED_IN_USER=$(docker info 2>/dev/null | grep "Username:" | awk '{print $2}')
    if [ -n "$LOGGED_IN_USER" ]; then
      print_status "Using Docker Hub session (logged in via Docker Desktop)"
      DOCKER_PAT="logged-in-via-docker-desktop"
    else
      # This shouldn't happen if the Docker build section ran, but handle it anyway
      print_info "Docker Hub password not found in cache"
      echo ""
      echo "Enter your Docker Hub password or Personal Access Token (PAT)"
      echo "To create a PAT: https://hub.docker.com/settings/security"
      echo ""
      read -sp "Docker Hub password/PAT: " DOCKER_PAT
      echo ""

      while [ -z "$DOCKER_PAT" ]; do
        print_error "Password/PAT cannot be empty"
        read -sp "Docker Hub password/PAT: " DOCKER_PAT
        echo ""
      done
    fi
  else
    print_status "Using cached Docker Hub password/PAT for Terraform"
  fi

  # Get Harness Project Name (may already be set from Docker build section)
  # Only reset if not already set
  if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME=""
    PROJECT_IDENTIFIER=""
  fi

  # Reserved words that cannot be used as project names (Harness API restrictions)
  RESERVED_WORDS="project org account pipeline service environment connector secret template infrastructure delegate trigger artifact manifest variable input output stage step group"

  # Function to check if a word is reserved
  is_reserved_word() {
    local word=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    for reserved in $RESERVED_WORDS; do
      if [ "$word" = "$reserved" ]; then
        return 0  # true - is reserved
      fi
    done
    return 1  # false - not reserved
  }

  # Function to convert project name to identifier (alphanumeric and underscores only)
  name_to_identifier() {
    echo "$1" | sed 's/[^a-zA-Z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_//' | sed 's/_$//'
  }

  # Function to check if a project already exists in Harness
  project_exists() {
    local identifier="$1"
    local response
    local http_code

    # Make API call to check if project exists
    response=$(curl -s -w "\n%{http_code}" -X GET \
      "https://app.harness.io/ng/api/projects/${identifier}?accountIdentifier=${HARNESS_ACCOUNT_ID}&orgIdentifier=${HARNESS_ORG_ID}" \
      -H "x-api-key: ${HARNESS_PAT}" \
      -H "Content-Type: application/json" 2>/dev/null)

    http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "200" ]; then
      return 0  # true - project exists
    else
      return 1  # false - project doesn't exist (404 or other error)
    fi
  }

  # Function to find the identifier of an existing project by its display name
  # (a project pre-created by an org admin may have an identifier that differs from name_to_identifier)
  find_project_by_name() {
    local name="$1"
    curl -s -X GET \
      "https://app.harness.io/ng/api/projects?accountIdentifier=${HARNESS_ACCOUNT_ID}&orgIdentifier=${HARNESS_ORG_ID}&searchTerm=$(printf '%s' "$name" | sed 's/ /%20/g')&pageSize=50" \
      -H "x-api-key: ${HARNESS_PAT}" 2>/dev/null \
      | python3 -c 'import sys,json
name=sys.argv[1]
try:
    for p in json.load(sys.stdin)["data"]["content"]:
        if p["project"]["name"] == name:
            print(p["project"]["identifier"]); break
except Exception:
    pass' "$name"
  }

  # Track if project name was set from Docker build section (custom name)
  PROJECT_FROM_DOCKER_BUILD=false
  if [ -n "$PROJECT_NAME" ] && [ "$PROJECT_NAME" != "Base Demo" ]; then
    PROJECT_FROM_DOCKER_BUILD=true
  fi

  # Try to get from config file if not already set
  if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "Base Demo" ]; then
    if [ -f "$CONFIG_FILE" ]; then
      CACHED_PROJECT=$(grep "PROJECT_NAME=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-)
      CACHED_IDENTIFIER=$(grep "PROJECT_IDENTIFIER=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
      if [ -n "$CACHED_PROJECT" ] && [ "$CACHED_PROJECT" != "Base Demo" ]; then
        PROJECT_NAME="$CACHED_PROJECT"
        PROJECT_IDENTIFIER="$CACHED_IDENTIFIER"
        print_status "Using cached project name: $PROJECT_NAME"
      fi
    fi
  fi

  # Try to get from se-parms.tfvars if still not found
  if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "Base Demo" ]; then
    if [ -f "kit/se-parms.tfvars" ]; then
      TF_PROJECT=$(grep 'project_name' kit/se-parms.tfvars 2>/dev/null | cut -d'"' -f2)
      TF_IDENTIFIER=$(grep 'project_identifier' kit/se-parms.tfvars 2>/dev/null | cut -d'"' -f2)
      if [ -n "$TF_PROJECT" ] && [ "$TF_PROJECT" != "Base Demo" ]; then
        PROJECT_NAME="$TF_PROJECT"
        PROJECT_IDENTIFIER="$TF_IDENTIFIER"
        print_status "Using project name from tfvars: $PROJECT_NAME"
      fi
    fi
  fi

  # Prompt for project name if still using default
  if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "Base Demo" ]; then
    echo ""
    echo "Choose a name for your Harness project"
    echo "This will be displayed in the Harness UI (e.g., 'Partner Workshop', 'ACME Demo')"
    echo ""
    echo "Note: Cannot use reserved words like: project, org, account, pipeline, service, etc."
    echo ""
    read -p "Enter your Harness Project name [Base Demo]: " PROJECT_NAME

    # Default to "Base Demo" if empty
    PROJECT_NAME=${PROJECT_NAME:-Base Demo}
  fi

  # Validate project name and check existence
  # Always do existence check (even for names from cache/config) for first-time Terraform apply
  VALID_NAME=false
  while [ "$VALID_NAME" = false ]; do
    # Check for reserved words (check each word in the project name)
    RESERVED_FOUND=false
    for word in $PROJECT_NAME; do
      if is_reserved_word "$word"; then
        print_error "'$word' is a reserved word and cannot be used in the project name"
        RESERVED_FOUND=true
        break
      fi
    done

    if [ "$RESERVED_FOUND" = true ]; then
      read -p "Enter a different project name: " PROJECT_NAME
      PROJECT_NAME=${PROJECT_NAME:-Base Demo}
      continue
    fi

    # Reuse a project that already exists with this exact name (e.g. pre-created by an org admin
    # when the user cannot create projects). Its identifier is taken from Harness, not derived.
    print_info "Checking if project '$PROJECT_NAME' already exists in org '$HARNESS_ORG_ID'..."
    EXISTING_IDENTIFIER=$(find_project_by_name "$PROJECT_NAME")
    if [ -n "$EXISTING_IDENTIFIER" ]; then
      PROJECT_IDENTIFIER="$EXISTING_IDENTIFIER"
      REUSE_EXISTING_PROJECT=true
      print_status "Found existing project '$PROJECT_NAME' (identifier: $PROJECT_IDENTIFIER) - it will be reused"
      VALID_NAME=true
      continue
    fi
    REUSE_EXISTING_PROJECT=false

    # Generate identifier from name
    PROJECT_IDENTIFIER=$(name_to_identifier "$PROJECT_NAME")

    # Check for an identifier collision with a differently-named project (only if Terraform state doesn't exist)
    # If state exists, we're updating an existing project, not creating a new one
    if [ ! -f "kit/terraform.tfstate" ] || [ ! -s "kit/terraform.tfstate" ]; then
      if project_exists "$PROJECT_IDENTIFIER"; then
        print_error "A project with identifier '$PROJECT_IDENTIFIER' already exists in your Harness account"
        print_info "Please choose a different project name"
        echo ""
        read -p "Enter a different project name: " PROJECT_NAME
        PROJECT_NAME=${PROJECT_NAME:-Base Demo}
        continue
      fi
    fi

    VALID_NAME=true
  done

  print_status "Project name: $PROJECT_NAME"
  print_info "Project identifier: $PROJECT_IDENTIFIER"

  ensure_participant_id

  # Was the project created by someone else (an admin, or another participant)?
  # Then cleanup must never delete it. Decided once, on the run that first imports it.
  PROJECT_PREEXISTING=$(config_get "$CONFIG_FILE" PROJECT_PREEXISTING)
  if [ "$REUSE_EXISTING_PROJECT" = true ] && ! grep -q '"harness_platform_project"' kit/terraform.tfstate 2>/dev/null; then
    PROJECT_PREEXISTING=true
  fi
  # Reusing a project but no saved answer (e.g. .demo-config was deleted): we can't tell who
  # created it, so err on the side of never deleting it
  if [ "$REUSE_EXISTING_PROJECT" = true ] && ! grep -q "^PROJECT_PREEXISTING=" "$CONFIG_FILE" 2>/dev/null; then
    PROJECT_PREEXISTING=true
  fi
  PROJECT_PREEXISTING=${PROJECT_PREEXISTING:-false}

  # Catch token/permission/collision problems now, not as a 403 halfway through Terraform
  print_section "Pre-flight Checks"
  if [ "$DEMO_SKIP_PREFLIGHT" = true ]; then
    print_info "Skipping pre-flight checks (DEMO_SKIP_PREFLIGHT=true)"
  else
    if ! harness_preflight "$HARNESS_ACCOUNT_ID" "$HARNESS_ORG_ID" "$PROJECT_IDENTIFIER" "$REUSE_EXISTING_PROJECT"; then
      print_error "Pre-flight checks failed - Terraform will very likely fail with the same problem"
      read -r -p "Continue anyway? [y/N]: " PREFLIGHT_CONTINUE
      if [[ ! "$PREFLIGHT_CONTINUE" =~ ^[Yy] ]]; then
        print_info "Fix the problem above and rerun ./start-demo.sh"
        exit 1
      fi
    fi
    # Someone else already uses this participant ID (or no ID) in this project: ask for another
    while [ "$REUSE_EXISTING_PROJECT" = true ] && \
          ! participant_collision_check "$HARNESS_ACCOUNT_ID" "$HARNESS_ORG_ID" "$PROJECT_IDENTIFIER" "$PARTICIPANT_ID" kit/terraform.tfstate; do
      read -r -p "Enter a different participant ID (ask your workshop lead), or Ctrl-C to stop: " NEW_PID
      NEW_PID=$(normalize_participant_id "$NEW_PID")
      if [ -n "$NEW_PID" ] && is_valid_participant_id "$NEW_PID"; then
        PARTICIPANT_ID="$NEW_PID"
        config_set "$CONFIG_FILE" PARTICIPANT_ID "$PARTICIPANT_ID"
        print_status "Participant ID: $PARTICIPANT_ID (delegate: $(delegate_name_for "$PARTICIPANT_ID"))"
        if [ "$SKIP_DOCKER_BUILD" = false ]; then
          print_info "The lab guides were already built with the old ID; afterwards rerun ./start-demo.sh and answer Yes to 'Build images?'"
        fi
      else
        print_error "Participant ID must be 1-20 lowercase letters/digits, starting with a letter"
      fi
    done
  fi

  # Save configuration for future runs (keep settings chosen earlier in this run)
  SAVED_COLIMA_MODE=$(config_get "$CONFIG_FILE" COLIMA_ARCH_MODE)
  {
    echo "DOCKER_USERNAME=$DOCKER_USERNAME"
    echo "HARNESS_ACCOUNT_ID=$HARNESS_ACCOUNT_ID"
    echo "HARNESS_ORG_ID=$HARNESS_ORG_ID"
    echo "HARNESS_PAT=$HARNESS_PAT"
    echo "DOCKER_PAT=$DOCKER_PAT"
    echo "PROJECT_NAME=$PROJECT_NAME"
    echo "PROJECT_IDENTIFIER=$PROJECT_IDENTIFIER"
    echo "PROJECT_PREEXISTING=$PROJECT_PREEXISTING"
    echo "PARTICIPANT_ID=$PARTICIPANT_ID"
    [ -n "$SAVED_COLIMA_MODE" ] && echo "COLIMA_ARCH_MODE=$SAVED_COLIMA_MODE"
  } > "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
  print_status "Saved credentials to $CONFIG_FILE for future runs"
  echo ""

  # Update se-parms.tfvars
  print_info "Updating kit/se-parms.tfvars..."
  cat > kit/se-parms.tfvars <<EOF
account_id = "$HARNESS_ACCOUNT_ID"

docker_username = "$DOCKER_USERNAME"
DOCKER_PAT = "$DOCKER_PAT"

project_name = "$PROJECT_NAME"
project_identifier = "$PROJECT_IDENTIFIER"

org_id = "$HARNESS_ORG_ID"

participant_id = "$PARTICIPANT_ID"
EOF
  print_status "Updated se-parms.tfvars with your configuration"

  # Check if Terraform has already been applied
  RUN_TERRAFORM=true
  if [ -f "kit/terraform.tfstate" ] && [ -s "kit/terraform.tfstate" ]; then
    echo ""
    print_info "IaC state file exists from a previous run"
    echo ""
    echo "Options:"
    echo "  1) Skip Terraform - assume Harness resources already exist"
    echo "  2) Re-run Terraform - recreate/update Harness resources"
    echo ""
    read -p "Choose [1/2] (default: 2 - re-run): " STATE_CHOICE
    STATE_CHOICE=${STATE_CHOICE:-2}

    if [ "$STATE_CHOICE" = "1" ]; then
      print_info "Skipping Terraform - using existing Harness resources"
      RUN_TERRAFORM=false
    else
      print_info "Will re-run Terraform to ensure resources are configured"
    fi
    echo ""
  fi

  if [ "$RUN_TERRAFORM" = "true" ]; then

    # Check for Terraform or OpenTofu
    print_section "Checking for Terraform/OpenTofu"

    # Detect available IaC tools
    HAS_TERRAFORM=false
    HAS_TOFU=false

    if command -v terraform &> /dev/null; then
      HAS_TERRAFORM=true
    fi
    if command -v tofu &> /dev/null; then
      HAS_TOFU=true
    fi

    # Handle based on what's available
    if [ "$HAS_TERRAFORM" = true ] && [ "$HAS_TOFU" = true ]; then
      # Both installed - ask user which to use
      print_status "Found Terraform: $(terraform version | head -n1)"
      print_status "Found OpenTofu: $(tofu version | head -n1)"
      echo ""
      echo "Both Terraform and OpenTofu are installed."
      echo ""
      read -p "Which would you like to use? [terraform/tofu] (default: terraform): " IAC_CHOICE
      IAC_CHOICE=${IAC_CHOICE:-terraform}

      case "$IAC_CHOICE" in
        tofu|opentofu|OpenTofu)
          IAC_CMD="tofu"
          print_status "Using OpenTofu"
          ;;
        *)
          IAC_CMD="terraform"
          print_status "Using Terraform"
          ;;
      esac
    elif [ "$HAS_TERRAFORM" = true ]; then
      IAC_CMD="terraform"
      print_status "Found Terraform: $(terraform version | head -n1)"
    elif [ "$HAS_TOFU" = true ]; then
      IAC_CMD="tofu"
      print_status "Found OpenTofu: $(tofu version | head -n1)"
    else
      print_error "Neither Terraform nor OpenTofu is installed"
      echo ""
      echo "This demo requires Terraform or OpenTofu to provision Harness resources."
      echo ""
      echo "Installation options:"
      echo ""
      echo "Terraform: https://www.terraform.io/downloads"
      echo "OpenTofu:  https://opentofu.org/docs/intro/install/"
      echo ""
      cd ..
      exit 1
    fi

    # Run Terraform/OpenTofu
    print_section "Running $IAC_CMD"

    cd kit

    # Check if early init was started, otherwise start it now
    if [ -n "$EARLY_TF_INIT_PID" ]; then
      TERRAFORM_INIT_PID=$EARLY_TF_INIT_PID
      print_info "$IAC_CMD init was started earlier (parallel with credential collection)"
    else
      # Start init now
      print_info "Starting $IAC_CMD init..."
      (
        $IAC_CMD init > "$TEMP_DIR/terraform_init.log" 2>&1
        echo $? > "$TEMP_DIR/terraform_init.exit"
      ) &
      TERRAFORM_INIT_PID=$!
    fi

    # Wait for init to complete (should already be done or nearly done)
    print_info "Waiting for $IAC_CMD init to complete..."
    INIT_EXIT=1
    if wait_with_spinner $TERRAFORM_INIT_PID "Initializing $IAC_CMD providers..."; then
      INIT_EXIT=$(cat "$TEMP_DIR/terraform_init.exit" 2>/dev/null || echo "1")
    fi
    if [ "$INIT_EXIT" = "0" ]; then
      print_status "$IAC_CMD initialized"
    else
      # The background init occasionally fails without output; retry once in the foreground
      print_info "$IAC_CMD init did not complete in the background - retrying..."
      if $IAC_CMD init > "$TEMP_DIR/terraform_init.log" 2>&1; then
        print_status "$IAC_CMD initialized"
      else
        print_error "$IAC_CMD init failed"
        tail -10 "$TEMP_DIR/terraform_init.log" 2>/dev/null
        cd ..
        exit 1
      fi
    fi

    # If reusing a pre-existing project, import it into IaC state so plan updates it rather than creating it
    if [ "$REUSE_EXISTING_PROJECT" = true ] && ! $IAC_CMD state list 2>/dev/null | grep -q '^harness_platform_project.base_demo$'; then
      print_info "Importing existing project '$PROJECT_IDENTIFIER' into $IAC_CMD state..."
      if $IAC_CMD import -var="pat=$HARNESS_PAT" -var-file="se-parms.tfvars" harness_platform_project.base_demo "${HARNESS_ORG_ID}/${PROJECT_IDENTIFIER}" > "$TEMP_DIR/terraform_import.log" 2>&1; then
        print_status "Project imported"
      else
        print_error "$IAC_CMD import failed"
        cat "$TEMP_DIR/terraform_import.log" 2>/dev/null | tail -10
        cd ..
        exit 1
      fi
    fi

    # Plan
    print_info "Running $IAC_CMD plan..."
    (
      $IAC_CMD plan -var="pat=$HARNESS_PAT" -var-file="se-parms.tfvars" -out=plan.tfplan > "$TEMP_DIR/terraform_plan.log" 2>&1
      echo $? > "$TEMP_DIR/terraform_plan.exit"
    ) &
    PLAN_PID=$!

    if wait_with_spinner $PLAN_PID "Creating $IAC_CMD plan (1-2 minutes)..."; then
      PLAN_EXIT=$(cat "$TEMP_DIR/terraform_plan.exit" 2>/dev/null || echo "1")
      if [ "$PLAN_EXIT" = "0" ]; then
        print_status "$IAC_CMD plan created"
      else
        print_error "$IAC_CMD plan failed"
        echo ""
        cat "$TEMP_DIR/terraform_plan.log" 2>/dev/null | tail -20
        echo ""
        print_info "Run manually to see full errors: cd kit && $IAC_CMD plan -var=\"pat=\$HARNESS_PAT\" -var-file=\"se-parms.tfvars\""
        cd ..
        exit 1
      fi
    else
      print_error "$IAC_CMD plan failed"
      cd ..
      exit 1
    fi

    # Apply (show output for visibility)
    print_info "Running $IAC_CMD apply (this may take 3-5 minutes)..."
    if $IAC_CMD apply -auto-approve plan.tfplan; then
      print_status "$IAC_CMD apply completed - Harness resources created!"
    else
      print_error "$IAC_CMD apply failed"
      cd ..
      exit 1
    fi

    cd ..
    echo ""
  fi
else
  print_info "Skipping Terraform setup (--skip-terraform flag used)"
fi

# Check if Prometheus background deployment completed (if we started one)
if [ -n "$PROMETHEUS_PID" ]; then
  print_section "Waiting for Background Tasks"

  # Check if Prometheus deployment is still running
  if kill -0 $PROMETHEUS_PID 2>/dev/null; then
    print_info "Waiting for Prometheus deployment to complete..."
    wait_with_spinner $PROMETHEUS_PID "Deploying Prometheus..."
  fi

  # Check result
  if [ -f "$TEMP_DIR/prometheus_status" ]; then
    PROM_STATUS=$(cat "$TEMP_DIR/prometheus_status")
    case "$PROM_STATUS" in
      "DEPLOYED")
        print_status "Prometheus deployed successfully"
        ;;
      "REDEPLOYED")
        print_status "Prometheus redeployed successfully"
        ;;
      *)
        print_status "Prometheus deployment completed"
        ;;
    esac
  else
    # Check if Prometheus is actually running
    if kubectl get pods -n monitoring -l app=prometheus 2>/dev/null | grep -q "Running"; then
      print_status "Prometheus is running"
    else
      print_error "Prometheus may have failed to deploy. Check: kubectl get pods -n monitoring"
    fi
  fi
fi

# Display status
print_section "Infrastructure Status"

echo ""
echo "Kubernetes Cluster:"
kubectl get nodes

echo ""
echo "Prometheus Status:"
kubectl get pods -n monitoring 2>/dev/null || echo "  (monitoring namespace not found)"

if [ "$K8S_TYPE" = "minikube" ]; then
  echo ""
  print_info "NOTE: For minikube, you need to run 'minikube tunnel' in a separate terminal"
  print_info "to access services at localhost:8080"
fi

# Deploy documentation to Kubernetes (every run - the image may already exist from an earlier run)
print_section "Deploying Documentation"
DOCS_USER="${DOCKER_USERNAME:-$(config_get "$CONFIG_FILE" DOCKER_USERNAME)}"
DOCS_OK=false
if [ -z "$DOCS_USER" ]; then
  print_info "Docker Hub username unknown - skipping docs deployment"
else
  print_info "Deploying $DOCS_USER/harness-demo:docs-latest..."
  if deploy_docs "$SCRIPT_DIR" "$DOCS_USER"; then
    DOCS_OK=true
    print_status "Documentation available at http://localhost:30001"
    if [ "$SKIP_DOCKER_BUILD" = true ]; then
      print_info "(Using the docs image from an earlier build; rerun without --skip-docker-build to refresh names)"
    fi
  else
    print_error "Documentation deployment didn't become ready (non-critical)"
    print_info "If the docs image was never built, rerun without --skip-docker-build"
    print_info "Check: kubectl get pods -l app=docs; kubectl describe deployment docs-deployment"
  fi
fi

# Install the Harness delegate (named to match the connectors Terraform created)
DELEGATE_OK=false
if [ "$SKIP_DELEGATE" = true ]; then
  print_info "Skipping delegate installation (--skip-delegate)"
else
  print_section "Harness Delegate"
  D_ACCOUNT="${HARNESS_ACCOUNT_ID:-$(config_get "$CONFIG_FILE" HARNESS_ACCOUNT_ID)}"
  D_ORG="${HARNESS_ORG_ID:-$(config_get "$CONFIG_FILE" HARNESS_ORG_ID)}"
  D_ORG="${D_ORG:-default}"
  D_PROJECT="$(config_get "$CONFIG_FILE" PROJECT_IDENTIFIER)"
  [ -z "$HARNESS_PAT" ] && HARNESS_PAT="${DEMO_BASE_PAT:-$(config_get "$CONFIG_FILE" HARNESS_PAT)}"
  [ "$PARTICIPANT_RESOLVED" = true ] || PARTICIPANT_ID="$(config_get "$CONFIG_FILE" PARTICIPANT_ID)"
  DELEGATE_NAME="$(delegate_name_for "$PARTICIPANT_ID")"

  if [ -z "$D_ACCOUNT" ] || [ -z "$D_PROJECT" ] || [ -z "$HARNESS_PAT" ]; then
    print_info "Harness settings not available yet - run without --skip-terraform first, then rerun"
  elif delegate_connected "$D_ACCOUNT" "$D_ORG" "$D_PROJECT" "$DELEGATE_NAME"; then
    DELEGATE_OK=true
    print_status "Delegate '$DELEGATE_NAME' is already connected"
  else
    echo "Your connectors use a delegate named '$DELEGATE_NAME'. It isn't connected yet."
    read -p "Install it into this cluster now with Helm? [Y/n]: " INSTALL_DELEGATE
    INSTALL_DELEGATE=${INSTALL_DELEGATE:-yes}
    if [[ "$INSTALL_DELEGATE" =~ ^[Yy]([Ee][Ss])?$ ]]; then
      if install_delegate "$D_ACCOUNT" "$D_ORG" "$D_PROJECT" "$DELEGATE_NAME"; then
        DELEGATE_OK=true
      else
        print_info "See Lab 0 'Installing the Delegate Manually' (name it exactly '$DELEGATE_NAME')"
      fi
    else
      print_info "Install it later: rerun ./start-demo.sh --skip-docker-build --skip-terraform"
    fi
  fi
fi

# Display next steps
print_section "Next Steps"
echo ""
echo "Your local infrastructure is ready! 🚀"
echo ""

if [ "$SKIP_TERRAFORM" = true ]; then
  echo "To complete setup, run Terraform manually or rerun without --skip-terraform:"
  echo "  ./start-demo.sh"
  echo ""
elif [ -f "kit/terraform.tfstate" ] && [ -s "kit/terraform.tfstate" ]; then
  echo "✅ Harness resources are configured and ready!"
  echo ""
  echo "Next steps:"
  if [ "$DOCS_OK" = true ]; then
    echo "  1. Open the lab guides: http://localhost:30001"
  else
    echo "  1. Lab guides: rerun ./start-demo.sh (without --skip-docker-build) to build and deploy them"
  fi
  echo "  2. Open Harness: https://app.harness.io and select the '$PROJECT_NAME' project"
  if [ "$DELEGATE_OK" = true ]; then
    echo "  3. Delegate '$DELEGATE_NAME' is connected - start with Lab 0's verification steps"
  else
    echo "  3. Install the delegate (see Lab 0) - it must be named '$DELEGATE_NAME'"
  fi
  echo "  4. Follow the labs in order"
  echo ""
else
  echo "Note: Harness resources were not configured (terraform.tfstate not found)"
  echo "This may happen if terraform apply was skipped or failed."
  echo ""
  echo "To configure Harness resources, run this script again:"
  echo "  ./start-demo.sh --skip-docker-build"
  echo ""
fi

if [ "$K8S_TYPE" = "minikube" ]; then
  echo "⚠️  IMPORTANT for minikube users:"
  echo "     Run this in a separate terminal and keep it running:"
  echo "     minikube tunnel"
  echo ""
fi

print_status "Startup complete!"
echo ""
