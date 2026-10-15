#!/bin/bash
#
# Harness Partner Demo Kit - Shutdown Script
#
# This script cleans up and stops all local infrastructure created for the demo:
# - Deletes deployed applications (frontend, backend)
# - Optionally removes Prometheus
# - Optionally stops Kubernetes cluster
#
# Usage: ./stop-demo.sh [OPTIONS]
#   OPTIONS:
#     --delete-prometheus       Also delete Prometheus monitoring
#     --stop-cluster            Stop the Kubernetes cluster (minikube/colima)
#     --delete-harness-project  Delete Harness project via Terraform/OpenTofu
#     --force-api-delete        Delete Harness project via API (bypasses Terraform state)
#     --delete-docker-repo      Delete Docker Hub harness-demo repository via API
#     --delete-config-files     Delete .demo-config, se-parms.tfvars, and IaC state files
#     --full-cleanup            Delete everything (all of the above)
#     --no-interactive          Skip interactive menu (for scripting)
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DELETE_PROMETHEUS=false
STOP_CLUSTER=false
DELETE_COLIMA_VM=false
DELETE_HARNESS_PROJECT=false
FORCE_API_DELETE=false  # Skip Terraform state, delete project directly via API
DELETE_DOCKER_REPO=false
DELETE_CONFIG_FILES=false
NO_INTERACTIVE=false
IAC_CMD=""  # Will be set to 'terraform' or 'tofu' (OpenTofu)

# Save original argument count
ORIGINAL_ARG_COUNT=$#

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --delete-prometheus)
      DELETE_PROMETHEUS=true
      shift
      ;;
    --stop-cluster)
      STOP_CLUSTER=true
      shift
      ;;
    --delete-harness-project)
      DELETE_HARNESS_PROJECT=true
      shift
      ;;
    --force-api-delete)
      DELETE_HARNESS_PROJECT=true
      FORCE_API_DELETE=true
      shift
      ;;
    --delete-docker-repo)
      DELETE_DOCKER_REPO=true
      shift
      ;;
    --delete-config-files)
      DELETE_CONFIG_FILES=true
      shift
      ;;
    --full-cleanup)
      DELETE_PROMETHEUS=true
      STOP_CLUSTER=true
      DELETE_HARNESS_PROJECT=true
      DELETE_DOCKER_REPO=true
      DELETE_CONFIG_FILES=false
      shift
      ;;
    --no-interactive)
      NO_INTERACTIVE=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: ./stop-demo.sh [OPTIONS]"
      echo "  --delete-prometheus       Delete Prometheus monitoring"
      echo "  --stop-cluster            Stop Kubernetes cluster (minikube/colima)"
      echo "  --delete-harness-project  Delete Harness project via Terraform/OpenTofu"
      echo "  --force-api-delete        Delete Harness project via API (bypasses Terraform state)"
      echo "  --delete-docker-repo      Delete Docker Hub repository"
      echo "  --delete-config-files     Delete config and state files (.demo-config, terraform state)"
      echo "  --full-cleanup            Everything except credentials (stops cluster, keeps credentials)"
      echo "  --no-interactive          Skip interactive menu (for scripting)"
      echo ""
      echo "Default (no options): Shows interactive menu to choose cleanup options"
      exit 1
      ;;
  esac
done

# Interactive menu function
show_cleanup_menu() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}Harness Partner Demo Kit - Cleanup Menu${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  echo "What would you like to cleanup?"
  echo ""
  echo -e "${CYAN}1)${NC} Stop K8s deployments only ${GREEN}(Recommended - preserves Harness resources)${NC}"
  echo "   - Removes frontend and backend deployments/services"
  echo "   - Keeps Harness project, Prometheus, and cluster running"
  echo "   - Easy to restart demo later with: ./start-demo.sh"
  echo ""
  echo -e "${CYAN}2)${NC} Stop K8s deployments + Delete Prometheus"
  echo -e "   ${GREEN}Removes:${NC} Frontend, backend, Prometheus monitoring"
  echo -e "   ${BLUE}Keeps:${NC} Harness project, cluster running, config files"
  echo ""
  echo -e "${CYAN}3)${NC} Stop K8s deployments + Stop cluster"
  echo -e "   ${GREEN}Removes:${NC} Frontend, backend deployments"
  echo -e "   ${GREEN}Stops:${NC} Kubernetes cluster (minikube/colima)"
  echo -e "   ${BLUE}Keeps:${NC} Harness project, Prometheus, config files"
  echo ""
  echo -e "${CYAN}4)${NC} Full cleanup (delete all Harness resources)"
  echo -e "   ${GREEN}Removes:${NC} Harness project, Docker Hub repo, Prometheus"
  echo -e "   ${BLUE}Keeps:${NC} Cluster running, config files"
  echo -e "   ${YELLOW}Note:${NC} Restart requires re-running Terraform to recreate Harness resources"
  echo ""
  echo -e "${CYAN}5)${NC} Complete cleanup (everything including cluster)"
  echo -e "   ${GREEN}Removes:${NC} Harness project, Docker Hub repo, Prometheus"
  echo -e "   ${GREEN}Stops:${NC} Kubernetes cluster (minikube/colima)"
  echo -e "   ${BLUE}Keeps:${NC} Config files (for easier restart)"
  echo -e "   ${YELLOW}Note:${NC} Option to delete Colima VM for fresh start (Apple Silicon)"
  echo ""
  echo -e "${CYAN}6)${NC} Force delete Harness project via API ${YELLOW}(bypasses Terraform state)${NC}"
  echo "   - Use when Terraform state is corrupted or start-demo failed partway"
  echo "   - Deletes project directly via API without checking Terraform state"
  echo "   - Also deletes Docker Hub repository and Prometheus"
  echo ""
  echo -e "${CYAN}7)${NC} Custom cleanup options"
  echo "   - Choose exactly what to cleanup"
  echo ""
  echo -e "${CYAN}0)${NC} Exit without doing anything"
  echo ""
  read -p "Enter your choice [0-7] (default: 1): " MENU_CHOICE

  # Default to option 1 if empty
  MENU_CHOICE=${MENU_CHOICE:-1}

  case $MENU_CHOICE in
    1)
      echo ""
      echo -e "${GREEN}✓${NC} Minimal cleanup selected - stopping K8s deployments only"
      DELETE_PROMETHEUS=false
      STOP_CLUSTER=false
      DELETE_HARNESS_PROJECT=false
      DELETE_DOCKER_REPO=false
      DELETE_CONFIG_FILES=false
      ;;
    2)
      echo ""
      echo -e "${GREEN}✓${NC} Stopping K8s deployments and deleting Prometheus"
      DELETE_PROMETHEUS=true
      STOP_CLUSTER=false
      DELETE_HARNESS_PROJECT=false
      DELETE_DOCKER_REPO=false
      DELETE_CONFIG_FILES=false
      ;;
    3)
      echo ""
      echo -e "${GREEN}✓${NC} Stopping K8s deployments and cluster"
      DELETE_PROMETHEUS=false
      STOP_CLUSTER=true
      DELETE_HARNESS_PROJECT=false
      DELETE_DOCKER_REPO=false
      DELETE_CONFIG_FILES=false
      ;;
    4)
      echo ""
      echo -e "${GREEN}✓${NC} Full cleanup - deleting all Harness resources"
      DELETE_PROMETHEUS=true
      STOP_CLUSTER=false
      DELETE_HARNESS_PROJECT=true
      DELETE_DOCKER_REPO=true
      DELETE_CONFIG_FILES=false
      ;;
    5)
      echo ""
      echo -e "${GREEN}✓${NC} Complete cleanup - everything including cluster"
      DELETE_PROMETHEUS=true
      STOP_CLUSTER=true
      DELETE_HARNESS_PROJECT=true
      DELETE_DOCKER_REPO=true
      DELETE_CONFIG_FILES=false
      ;;
    6)
      echo ""
      echo -e "${GREEN}✓${NC} Force delete via API - bypassing Terraform state"
      DELETE_PROMETHEUS=true
      STOP_CLUSTER=false
      DELETE_HARNESS_PROJECT=true
      FORCE_API_DELETE=true
      DELETE_DOCKER_REPO=true
      DELETE_CONFIG_FILES=false
      ;;
    7)
      echo ""
      echo -e "${CYAN}Custom cleanup options:${NC}"
      echo ""
      read -p "Delete Prometheus monitoring? [y/N]: " DELETE_PROM_CHOICE
      DELETE_PROMETHEUS=false
      if [[ "$DELETE_PROM_CHOICE" =~ ^[Yy]$ ]]; then
        DELETE_PROMETHEUS=true
      fi

      read -p "Stop Kubernetes cluster (minikube/colima)? [y/N]: " STOP_CLUSTER_CHOICE
      STOP_CLUSTER=false
      DELETE_COLIMA_VM=false
      if [[ "$STOP_CLUSTER_CHOICE" =~ ^[Yy]$ ]]; then
        STOP_CLUSTER=true
        # Ask about deleting Colima VM on Apple Silicon
        if [ "$(uname -m)" = "arm64" ] || [ "$(uname -m)" = "aarch64" ]; then
          read -p "Also delete Colima VM for fresh start? [y/N]: " DELETE_VM_CHOICE
          if [[ "$DELETE_VM_CHOICE" =~ ^[Yy]$ ]]; then
            DELETE_COLIMA_VM=true
          fi
        fi
      fi

      read -p "Delete Harness '$PROJECT_NAME' project? [y/N]: " DELETE_HARNESS_CHOICE
      DELETE_HARNESS_PROJECT=false
      FORCE_API_DELETE=false
      if [[ "$DELETE_HARNESS_CHOICE" =~ ^[Yy]$ ]]; then
        DELETE_HARNESS_PROJECT=true
        # Ask if they want to force API delete (skip Terraform)
        read -p "Force delete via API (bypass Terraform state)? [y/N]: " FORCE_API_CHOICE
        if [[ "$FORCE_API_CHOICE" =~ ^[Yy]$ ]]; then
          FORCE_API_DELETE=true
        fi
      fi

      read -p "Delete Docker Hub repository? [y/N]: " DELETE_DOCKER_CHOICE
      DELETE_DOCKER_REPO=false
      if [[ "$DELETE_DOCKER_CHOICE" =~ ^[Yy]$ ]]; then
        DELETE_DOCKER_REPO=true
      fi

      read -p "Delete config files (.demo-config, terraform state)? [y/N]: " DELETE_CONFIG_CHOICE
      DELETE_CONFIG_FILES=false
      if [[ "$DELETE_CONFIG_CHOICE" =~ ^[Yy]$ ]]; then
        DELETE_CONFIG_FILES=true
      fi

      echo ""
      echo -e "${GREEN}✓${NC} Custom cleanup configured"
      ;;
    0)
      echo ""
      echo "Exiting without making any changes."
      exit 0
      ;;
    *)
      echo ""
      echo -e "${RED}Invalid choice. Defaulting to minimal cleanup (option 1).${NC}"
      DELETE_PROMETHEUS=false
      STOP_CLUSTER=false
      DELETE_HARNESS_PROJECT=false
      DELETE_DOCKER_REPO=false
      DELETE_CONFIG_FILES=false
      ;;
  esac
  echo ""
}

# If no arguments provided and not in non-interactive mode, show the menu
if [ "$ORIGINAL_ARG_COUNT" -eq 0 ] && [ "$NO_INTERACTIVE" = false ]; then
  show_cleanup_menu
elif [ "$ORIGINAL_ARG_COUNT" -eq 0 ] && [ "$NO_INTERACTIVE" = true ]; then
  # Non-interactive mode with no args: minimal cleanup
  echo -e "${YELLOW}Non-interactive mode: defaulting to minimal cleanup${NC}"
  echo ""
  DELETE_PROMETHEUS=false
  STOP_CLUSTER=false
  DELETE_HARNESS_PROJECT=false
  DELETE_DOCKER_REPO=false
  DELETE_CONFIG_FILES=false
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Harness Partner Demo Kit - Shutdown${NC}"
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

# Load credentials from config file if it exists
CONFIG_FILE=".demo-config"
HARNESS_ACCOUNT_ID=""
HARNESS_PAT=""
DOCKER_USERNAME=""
DOCKER_PAT=""
PROJECT_NAME=""
PROJECT_IDENTIFIER=""
HARNESS_DELETE_SUCCESS=false

# Delete Harness project via API; returns 0 on success, 1 on failure
delete_harness_project_via_api() {
  if [ "$SHARED_PROJECT" = true ]; then
    print_info "Not deleting project '$PROJECT_NAME': it existed before this kit ran or is shared"
    print_info "(PROJECT_PREEXISTING/PARTICIPANT_ID in .demo-config). Only your own resources are removed."
    return 1
  fi
  if [ -z "$HARNESS_ACCOUNT_ID" ] || [ -z "$HARNESS_PAT" ] || [ -z "$PROJECT_IDENTIFIER" ]; then
    print_error "Missing required credentials for API call"
    print_info "HARNESS_ACCOUNT_ID: $([ -n "$HARNESS_ACCOUNT_ID" ] && echo "set" || echo "NOT SET")"
    print_info "HARNESS_PAT: $([ -n "$HARNESS_PAT" ] && echo "set (${#HARNESS_PAT} chars)" || echo "NOT SET")"
    print_info "PROJECT_IDENTIFIER: $([ -n "$PROJECT_IDENTIFIER" ] && echo "set ($PROJECT_IDENTIFIER)" || echo "NOT SET")"
    return 1
  fi

  print_info "Account: ${HARNESS_ACCOUNT_ID}"
  print_info "Org: $HARNESS_ORG_ID"
  print_info "Project: $PROJECT_IDENTIFIER"
  echo ""
  print_info "Deleting '$PROJECT_NAME' project via API..."

  PROJECT_DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE \
    "https://app.harness.io/ng/api/projects/${PROJECT_IDENTIFIER}?accountIdentifier=${HARNESS_ACCOUNT_ID}&orgIdentifier=${HARNESS_ORG_ID}" \
    -H "x-api-key: ${HARNESS_PAT}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" 2>&1)

  PROJECT_HTTP_CODE=$(echo "$PROJECT_DELETE_RESPONSE" | tail -n 1)
  PROJECT_RESPONSE_BODY=$(echo "$PROJECT_DELETE_RESPONSE" | sed '$d')

  echo ""
  echo "HTTP Status Code: $PROJECT_HTTP_CODE"

  if [ "$PROJECT_HTTP_CODE" = "200" ] || [ "$PROJECT_HTTP_CODE" = "204" ]; then
    print_status "$PROJECT_NAME project deleted successfully"
    HARNESS_DELETE_SUCCESS=true
    return 0
  elif [ "$PROJECT_HTTP_CODE" = "404" ]; then
    print_info "Project not found (already deleted)"
    HARNESS_DELETE_SUCCESS=true
    return 0
  elif [ "$PROJECT_HTTP_CODE" = "401" ]; then
    print_error "Failed to delete project: Harness PAT is invalid or expired (HTTP 401)"
    print_info "Create a token: Profile > My API Keys & Tokens > your key > + Token"
    print_info "An API key alone is not enough — you must generate a token under the key"
    print_info "Then run: export DEMO_BASE_PAT=\"pat.xxx\" && ./stop-demo.sh --force-api-delete"
    return 1
  else
    print_error "Failed to delete project (HTTP $PROJECT_HTTP_CODE)"
    if [ -n "$PROJECT_RESPONSE_BODY" ]; then
      echo ""
      echo "API Response Body:"
      echo "----------------------------------------"
      echo "$PROJECT_RESPONSE_BODY" | head -n 5
      echo "----------------------------------------"
    fi
    print_info "Manual deletion: Harness UI > Projects > $PROJECT_NAME > ⋮ > Delete Project"
    return 1
  fi
}

print_harness_pat_instructions() {
  echo ""
  echo "Create a Harness API token in the UI:"
  echo "  1. Profile (bottom-left) > My API Keys & Tokens"
  echo "  2. Open your API key (or create one with + API Key)"
  echo "  3. Click + Token on that key — the key alone is not a usable token"
  echo "  4. Copy the pat.* value immediately (shown only once)"
  echo ""
}

validate_harness_pat() {
  if [ -z "$HARNESS_PAT" ] || [ -z "$HARNESS_ACCOUNT_ID" ]; then
    return 1
  fi

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" -X GET \
    "https://app.harness.io/ng/api/user/currentUser?accountIdentifier=${HARNESS_ACCOUNT_ID}" \
    -H "x-api-key: ${HARNESS_PAT}" \
    -H "Content-Type: application/json" 2>/dev/null)

  [ "$http_code" = "200" ]
}

ensure_valid_harness_pat_for_cleanup() {
  if validate_harness_pat; then
    return 0
  fi

  print_error "Harness PAT is invalid or expired — project deletion will fail until you update it"
  print_harness_pat_instructions

  if [ "$NO_INTERACTIVE" = true ]; then
    print_info "Re-run with a fresh token: export DEMO_BASE_PAT=\"pat.xxx\" && ./stop-demo.sh --force-api-delete"
    return 1
  fi

  read -sp "Enter a fresh Harness PAT (or press Enter to skip deletion): " NEW_PAT
  echo ""
  if [ -z "$NEW_PAT" ]; then
    print_info "Skipping Harness project deletion (no valid PAT provided)"
    DELETE_HARNESS_PROJECT=false
    return 1
  fi

  HARNESS_PAT="$NEW_PAT"
  if validate_harness_pat; then
    print_status "Harness PAT validated"
    return 0
  fi

  print_error "That token is still not valid"
  DELETE_HARNESS_PROJECT=false
  return 1
}

if [ -f "$CONFIG_FILE" ]; then
  print_info "Loading credentials from $CONFIG_FILE..."
  HARNESS_ACCOUNT_ID=$(grep "HARNESS_ACCOUNT_ID=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
  HARNESS_PAT=$(grep "HARNESS_PAT=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
  DOCKER_USERNAME=$(grep "DOCKER_USERNAME=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
  DOCKER_PAT=$(grep "DOCKER_PAT=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
  PROJECT_NAME=$(grep "PROJECT_NAME=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-)
  PROJECT_IDENTIFIER=$(grep "PROJECT_IDENTIFIER=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
  HARNESS_ORG_ID=$(grep "^HARNESS_ORG_ID=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
  PARTICIPANT_ID=$(grep "^PARTICIPANT_ID=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
  PROJECT_PREEXISTING=$(grep "^PROJECT_PREEXISTING=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)

  # Show what was loaded (for debugging)
  if [ -n "$HARNESS_ACCOUNT_ID" ]; then
    print_status "Loaded Harness Account ID from config"
  fi
  if [ -n "$HARNESS_PAT" ]; then
    print_status "Loaded Harness PAT from config"
  fi
  if [ -n "$DOCKER_USERNAME" ]; then
    print_status "Loaded Docker username from config"
  fi
  if [ -n "$DOCKER_PAT" ]; then
    print_status "Loaded Docker password from config"
  fi
  if [ -n "$PROJECT_NAME" ]; then
    print_status "Loaded project name from config: $PROJECT_NAME"
  fi
else
  print_info "Config file $CONFIG_FILE not found"
fi

# Default to "Base Demo" if project name not set
PROJECT_NAME=${PROJECT_NAME:-Base Demo}
PROJECT_IDENTIFIER=${PROJECT_IDENTIFIER:-Base_Demo}
HARNESS_ORG_ID=${HARNESS_ORG_ID:-default}

# A project this kit didn't create (pre-created by an admin) or one shared by several
# participants must never be deleted by cleanup - only this user's own resources.
SHARED_PROJECT=false
if [ "$PROJECT_PREEXISTING" = true ] || [ -n "$PARTICIPANT_ID" ]; then
  SHARED_PROJECT=true
fi
PIPELINE_IDENTIFIER="Workshop_Build_and_Deploy${PARTICIPANT_ID:+_$PARTICIPANT_ID}"

# Check environment variable for Harness PAT (overrides cached value)
if [ -n "$DEMO_BASE_PAT" ]; then
  HARNESS_PAT="$DEMO_BASE_PAT"
  print_status "Using Harness PAT from DEMO_BASE_PAT environment variable"
fi

# Try to load from se-parms.tfvars as fallback
if [ -f "kit/se-parms.tfvars" ]; then
  if [ -z "$HARNESS_ACCOUNT_ID" ]; then
    HARNESS_ACCOUNT_ID=$(grep account_id kit/se-parms.tfvars 2>/dev/null | cut -d'"' -f2)
    if [ -n "$HARNESS_ACCOUNT_ID" ]; then
      print_status "Loaded Harness Account ID from kit/se-parms.tfvars"
    fi
  fi
  if [ -z "$DOCKER_USERNAME" ]; then
    DOCKER_USERNAME=$(grep docker_username kit/se-parms.tfvars 2>/dev/null | cut -d'"' -f2)
    if [ -n "$DOCKER_USERNAME" ]; then
      print_status "Loaded Docker username from kit/se-parms.tfvars"
    fi
  fi
  if [ -z "$DOCKER_PAT" ]; then
    DOCKER_PAT=$(grep DOCKER_PAT kit/se-parms.tfvars 2>/dev/null | cut -d'"' -f2)
    if [ -n "$DOCKER_PAT" ]; then
      print_status "Loaded Docker password from kit/se-parms.tfvars"
    fi
  fi
  if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "Base Demo" ]; then
    TF_PROJECT_NAME=$(grep 'project_name' kit/se-parms.tfvars 2>/dev/null | cut -d'"' -f2)
    TF_PROJECT_ID=$(grep 'project_identifier' kit/se-parms.tfvars 2>/dev/null | cut -d'"' -f2)
    if [ -n "$TF_PROJECT_NAME" ]; then
      PROJECT_NAME="$TF_PROJECT_NAME"
      PROJECT_IDENTIFIER="$TF_PROJECT_ID"
      print_status "Loaded project name from kit/se-parms.tfvars: $PROJECT_NAME"
    fi
  fi
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
  print_error "kubectl is not installed. Cannot proceed with Kubernetes cleanup."

  # If only doing Harness/Docker cleanup, we can continue
  if [ "$DELETE_HARNESS_PROJECT" = true ] || [ "$DELETE_DOCKER_REPO" = true ] || [ "$DELETE_CONFIG_FILES" = true ]; then
    print_info "Continuing with Harness/Docker/config cleanup only..."
  else
    exit 1
  fi
fi

# Check if cluster is accessible (skip if only doing non-k8s cleanup)
if command -v kubectl &> /dev/null; then
  if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    print_info "Cluster may already be stopped or not configured"

    # If doing Harness/Docker cleanup OR stopping cluster, we can continue
    if [ "$DELETE_HARNESS_PROJECT" = true ] || [ "$DELETE_DOCKER_REPO" = true ] || [ "$DELETE_CONFIG_FILES" = true ] || [ "$STOP_CLUSTER" = true ]; then
      print_info "Continuing with cleanup..."
      K8S_AVAILABLE=false
    else
      exit 1
    fi
  else
    print_info "Connected to cluster: $(kubectl config current-context)"
    K8S_AVAILABLE=true
  fi
else
  K8S_AVAILABLE=false
fi

# Detect Kubernetes environment
# Check directly for running Colima/minikube even if kubectl can't connect
K8S_TYPE=""
if [ "$K8S_AVAILABLE" = true ]; then
  if kubectl config current-context 2>/dev/null | grep -q "colima"; then
    K8S_TYPE="colima"
  elif kubectl config current-context 2>/dev/null | grep -q "minikube"; then
    K8S_TYPE="minikube"
  elif kubectl config current-context 2>/dev/null | grep -q "rancher-desktop"; then
    K8S_TYPE="rancher-desktop"
  elif kubectl config current-context 2>/dev/null | grep -q "docker-desktop"; then
    K8S_TYPE="docker-desktop"
  else
    K8S_TYPE="other"
  fi
fi

# If kubectl couldn't connect but we want to stop the cluster, detect Colima/minikube directly
if [ "$K8S_AVAILABLE" = false ] && [ "$STOP_CLUSTER" = true ]; then
  print_info "Checking for running cluster tools directly..."

  # Check if Colima is running
  if command -v colima &> /dev/null && colima status &> /dev/null; then
    K8S_TYPE="colima"
    print_status "Detected running Colima instance"
  # Check if minikube is running
  elif command -v minikube &> /dev/null && minikube status 2>/dev/null | grep -q "host: Running"; then
    K8S_TYPE="minikube"
    print_status "Detected running minikube instance"
  fi
fi

# Delete deployed applications
if [ "$K8S_AVAILABLE" = true ]; then
  print_section "Cleaning Up Deployed Applications"
else
  print_info "Skipping Kubernetes cleanup (cluster not available)"
fi

if [ "$K8S_AVAILABLE" = true ]; then

# Delete all application deployments (including canary deployments created by pipeline)
print_info "Checking for application deployments in default namespace..."
ALL_DEPLOYMENTS=$(kubectl get deployments -n default --no-headers 2>/dev/null | grep -E "frontend|backend|docs" | awk '{print $1}')

if [ -n "$ALL_DEPLOYMENTS" ]; then
  print_info "Found deployments to delete:"
  echo "$ALL_DEPLOYMENTS" | while read -r deployment; do
    echo "  - $deployment"
  done

  echo "$ALL_DEPLOYMENTS" | while read -r deployment; do
    print_info "Deleting deployment: $deployment"
    kubectl delete deployment "$deployment" -n default --ignore-not-found=true
  done
  print_status "All application deployments deleted"
else
  print_info "No application deployments found"
fi

# Delete all application services (including those created by pipeline)
print_info "Checking for application services in default namespace..."
ALL_SERVICES=$(kubectl get services -n default --no-headers 2>/dev/null | grep -E "frontend|backend|docs" | awk '{print $1}')

if [ -n "$ALL_SERVICES" ]; then
  print_info "Found services to delete:"
  echo "$ALL_SERVICES" | while read -r service; do
    echo "  - $service"
  done

  echo "$ALL_SERVICES" | while read -r service; do
    print_info "Deleting service: $service"
    kubectl delete service "$service" -n default --ignore-not-found=true
  done
  print_status "All application services deleted"
else
  print_info "No application services found"
fi

# Delete any remaining pods and wait for full termination
print_info "Checking for remaining application pods in default namespace..."
REMAINING_PODS=$(kubectl get pods -n default --no-headers 2>/dev/null | grep -E "frontend|backend|docs" | wc -l)
if [ "$REMAINING_PODS" -gt 0 ]; then
  print_info "Waiting for $REMAINING_PODS pod(s) to fully terminate..."

  # Show which pods are terminating
  kubectl get pods -n default --no-headers 2>/dev/null | grep -E "frontend|backend|docs" | awk '{print "  - " $1 " (" $3 ")"}'

  # Wait up to 90 seconds for pods to terminate (increased from 60 for canary cleanup)
  WAIT_TIME=0
  MAX_WAIT=90
  while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    REMAINING=$(kubectl get pods -n default --no-headers 2>/dev/null | grep -E "frontend|backend|docs" | wc -l)
    if [ "$REMAINING" -eq 0 ]; then
      break
    fi
    sleep 2
    WAIT_TIME=$((WAIT_TIME + 2))
  done

  FINAL_COUNT=$(kubectl get pods -n default --no-headers 2>/dev/null | grep -E "frontend|backend|docs" | wc -l)
  if [ "$FINAL_COUNT" -eq 0 ]; then
    print_status "All application pods terminated"
  else
    print_info "$FINAL_COUNT pod(s) still terminating (may take 1-2 full minutes)"
    kubectl get pods -n default --no-headers 2>/dev/null | grep -E "frontend|backend|docs" | awk '{print "  - " $1 " (" $3 ")"}'
  fi
else
  print_status "No application pods found"
fi

# Delete Harness Delegate namespace and resources
print_section "Cleaning Up Harness Delegate"
if kubectl get namespace harness-delegate-ng &> /dev/null; then
  print_info "Found harness-delegate-ng namespace"

  # Delete all deployments in the delegate namespace
  DELEGATE_DEPLOYMENTS=$(kubectl get deployments -n harness-delegate-ng --no-headers 2>/dev/null | awk '{print $1}')
  if [ -n "$DELEGATE_DEPLOYMENTS" ]; then
    print_info "Deleting delegate deployments..."
    echo "$DELEGATE_DEPLOYMENTS" | while read -r deployment; do
      kubectl delete deployment "$deployment" -n harness-delegate-ng --ignore-not-found=true
    done
    print_status "Delegate deployments deleted"
  fi

  # Wait for delegate pods to terminate
  print_info "Waiting for delegate pods to terminate..."
  WAIT_TIME=0
  MAX_WAIT=60
  while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    DELEGATE_PODS=$(kubectl get pods -n harness-delegate-ng --no-headers 2>/dev/null | wc -l)
    if [ "$DELEGATE_PODS" -eq 0 ]; then
      break
    fi
    sleep 2
    WAIT_TIME=$((WAIT_TIME + 2))
  done

  # Delete the namespace
  print_info "Deleting harness-delegate-ng namespace..."
  kubectl delete namespace harness-delegate-ng --ignore-not-found=true &> /dev/null || true
  print_status "Harness delegate namespace deleted"
else
  print_info "Harness delegate namespace not found (already deleted)"
fi

# Delete Prometheus (optional)
if [ "$DELETE_PROMETHEUS" = true ]; then
  print_section "Deleting Prometheus"

  if kubectl get namespace monitoring &> /dev/null; then
    print_info "Deleting Prometheus deployment..."
    kubectl -n monitoring delete -f kit/prometheus.yml --ignore-not-found=true &> /dev/null || true
    print_status "Prometheus deleted"

    print_info "Deleting monitoring namespace..."
    kubectl delete namespace monitoring --ignore-not-found=true &> /dev/null || true
    print_status "Monitoring namespace deleted"
  else
    print_info "Monitoring namespace not found (already deleted)"
  fi
else
  print_info "Keeping Prometheus running (use --delete-prometheus to remove)"
fi

fi  # End of K8S_AVAILABLE check

# Delete Harness Resources (optional)
if [ "$DELETE_HARNESS_PROJECT" = true ]; then
  print_section "Deleting Harness Resources"

  # Credentials were loaded from .demo-config at startup (never `source` it: values may contain spaces)
  if [ -f "kit/se-parms.tfvars" ]; then
    HARNESS_ACCOUNT_ID=$(grep 'account_id' kit/se-parms.tfvars | cut -d'"' -f2)
  fi
  if [ -z "$HARNESS_PAT" ]; then
    HARNESS_PAT="${DEMO_BASE_PAT}"
  fi

  ensure_valid_harness_pat_for_cleanup || true

  # Check if IaC state file exists
  if [ ! -f "kit/terraform.tfstate" ] || [ ! -s "kit/terraform.tfstate" ]; then
    print_info "No Terraform state file found"
    print_info "Will attempt to delete '$PROJECT_NAME' project directly via Harness API..."
    echo ""

    # Try API deletion directly (no terraform)
    if delete_harness_project_via_api; then
      :
    else
      print_info "Cannot delete project without valid credentials"
    fi
  else
    # We have a state file, use IaC to destroy
    print_info "Found Terraform state file"
    echo ""
    echo -e "${YELLOW}Will delete all Harness resources via Terraform:${NC}"
    if [ "$SHARED_PROJECT" = true ]; then
      echo "  - (NOT the '$PROJECT_NAME' project itself - it is pre-existing/shared)"
    else
      echo "  - '$PROJECT_NAME' project"
    fi
    echo "  - Code repositories"
    echo "  - Pipelines"
    echo "  - Services"
    echo "  - Environments"
    echo "  - Connectors"
    echo ""

    # Accept y/Y/yes as confirmation (no prompt needed for full cleanup)
    CONFIRM_HARNESS="yes"
    if [[ "$CONFIRM_HARNESS" =~ ^[Yy]([Ee][Ss])?$ ]]; then
      # Need Harness PAT for destroy
      if [ -z "$HARNESS_PAT" ]; then
        echo ""
        print_info "Harness PAT not found in config files"
        echo "You can use the DEMO_BASE_PAT environment variable or enter it now"
        echo ""
        read -p "Enter your Harness PAT (or press Enter to skip): " HARNESS_PAT
      fi

      if [ -z "$HARNESS_PAT" ]; then
        print_info "Skipping Harness resource deletion (PAT not provided)"
      else
        # First, delete the pipeline to remove references to connectors, templates, etc.
        if [ -n "$HARNESS_ACCOUNT_ID" ] && [ -n "$HARNESS_PAT" ]; then
          print_section "Deleting Harness Pipeline"
          print_info "Deleting pipeline '$PIPELINE_IDENTIFIER'..."

          # Try to delete the pipeline via API
          PIPELINE_DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE \
            "https://app.harness.io/pipeline/api/pipelines/${PIPELINE_IDENTIFIER}?accountIdentifier=${HARNESS_ACCOUNT_ID}&orgIdentifier=${HARNESS_ORG_ID}&projectIdentifier=${PROJECT_IDENTIFIER}" \
            -H "x-api-key: ${HARNESS_PAT}" 2>/dev/null)

          HTTP_CODE=$(echo "$PIPELINE_DELETE_RESPONSE" | tail -n 1)

          if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
            print_status "Pipeline deleted successfully"
          elif [ "$HTTP_CODE" = "404" ]; then
            print_info "Pipeline not found (may already be deleted or not created yet)"
          else
            print_info "Could not delete pipeline via API (HTTP $HTTP_CODE)"
            print_info "This is OK if the pipeline doesn't exist yet"
          fi

          # Wait a moment for Harness to process the deletion
          sleep 2
        fi

        # Check for Terraform or OpenTofu
        HAS_TERRAFORM=false
        HAS_TOFU=false
        if command -v terraform &> /dev/null; then HAS_TERRAFORM=true; fi
        if command -v tofu &> /dev/null; then HAS_TOFU=true; fi

        if [ "$HAS_TERRAFORM" = false ] && [ "$HAS_TOFU" = false ]; then
          print_error "Neither Terraform nor OpenTofu found"
          print_info "Cannot destroy Harness resources without Terraform or OpenTofu"
          print_info "Please install one of them, or delete resources manually through Harness UI"
        else
          # Determine which IaC tool to use
          if [ "$HAS_TERRAFORM" = true ] && [ "$HAS_TOFU" = true ]; then
            # Both installed - ask user
            print_status "Found Terraform: $(terraform version | head -n1)"
            print_status "Found OpenTofu: $(tofu version | head -n1)"
            echo ""
            read -p "Which would you like to use? [terraform/tofu] (default: terraform): " IAC_CHOICE
            IAC_CHOICE=${IAC_CHOICE:-terraform}
            case "$IAC_CHOICE" in
              tofu|opentofu|OpenTofu)
                IAC_CMD="tofu"
                ;;
              *)
                IAC_CMD="terraform"
                ;;
            esac
          elif [ "$HAS_TERRAFORM" = true ]; then
            IAC_CMD="terraform"
            print_status "Found Terraform: $(terraform version | head -n1)"
          else
            IAC_CMD="tofu"
            print_status "Found OpenTofu: $(tofu version | head -n1)"
          fi

          cd kit
          TERRAFORM_SUCCESS=false
          SKIP_TERRAFORM=false

          # Check if we should skip Terraform and go straight to API deletion
          if [ "$FORCE_API_DELETE" = true ]; then
            print_section "Force API Delete Mode"
            print_info "Skipping Terraform state check, will delete project via API"
            SKIP_TERRAFORM=true
          elif [ ! -f "terraform.tfstate" ] && [ ! -f "terraform.tfstate.backup" ]; then
            print_section "Terraform State Check"
            print_error "No Terraform state files found"
            echo ""
            echo "This likely means:"
            echo "  - start-demo.sh never ran successfully, OR"
            echo "  - Terraform state was already cleaned up, OR"
            echo "  - Resources were created manually"
            echo ""
            echo "Options:"
            echo "  1) Delete project via API (bypasses Terraform state)"
            echo "  2) Skip Harness cleanup entirely"
            echo ""
            read -p "Enter your choice [1-2] (default: 1): " STATE_CHOICE
            STATE_CHOICE=${STATE_CHOICE:-1}

            if [ "$STATE_CHOICE" = "1" ]; then
              print_info "Will delete project via API"
              SKIP_TERRAFORM=true
            else
              print_info "Skipping Harness cleanup"
              cd ..
              TERRAFORM_SUCCESS=true  # Set to true to skip error handling
              # Jump to next section (skip terraform destroy)
              SKIP_TERRAFORM=true
              TERRAFORM_SUCCESS=true
            fi
          fi

          if [ "$SKIP_TERRAFORM" = false ]; then
            print_section "Running $IAC_CMD Destroy"
            print_status "Using $IAC_CMD for destroy"

            # Check if se-parms.tfvars exists
            if [ -f "se-parms.tfvars" ]; then
              TFVARS_ARG="-var-file=se-parms.tfvars"

              # Refresh state to match reality before destroying
              print_info "Refreshing Terraform state to match current Harness resources..."
              # Run refresh (ignore errors as some resources may already be deleted)
              $IAC_CMD refresh -var="pat=$HARNESS_PAT" $TFVARS_ARG > /dev/null 2>&1 || true
            else
              print_error "se-parms.tfvars not found"
              echo ""
              echo "Terraform destroy requires the tfvars file with account_id, docker_username, and DOCKER_PAT."
              echo ""
              echo "Options:"
              echo "  1) Delete project via API (bypasses Terraform - RECOMMENDED)"
              echo "  2) Cancel and manually restore se-parms.tfvars"
              echo ""
              read -p "Enter your choice [1-2] (default: 1): " TFVARS_CHOICE
              TFVARS_CHOICE=${TFVARS_CHOICE:-1}

              if [ "$TFVARS_CHOICE" = "1" ]; then
                print_info "Will delete project via API instead"
                SKIP_TERRAFORM=true
                # Continue to API deletion section below
              else
                print_info "Cancelling Terraform destroy"
                cd ..
                exit 0
              fi
            fi

            if [ "$SKIP_TERRAFORM" = false ] && [ "$SHARED_PROJECT" = true ] && \
               $IAC_CMD state list 2>/dev/null | grep -q '^harness_platform_project.base_demo$'; then
              print_info "Project '$PROJECT_NAME' is pre-existing/shared: removing it from $IAC_CMD state so destroy leaves it alone"
              if ! $IAC_CMD state rm harness_platform_project.base_demo > /dev/null; then
                print_error "Could not remove the project from state - aborting destroy to protect the shared project"
                SKIP_TERRAFORM=true
                TERRAFORM_SUCCESS=true
              fi
            fi
            # The code repository is one per project (no per-person suffix): in a shared project
            # it belongs to everyone, so keep it too
            if [ "$SKIP_TERRAFORM" = false ] && [ "$SHARED_PROJECT" = true ] && \
               $IAC_CMD state list 2>/dev/null | grep -q '^harness_platform_repo.partner_demo_kit$'; then
              print_info "Code repository is shared: removing it from $IAC_CMD state so destroy leaves it alone"
              if ! $IAC_CMD state rm harness_platform_repo.partner_demo_kit > /dev/null; then
                print_error "Could not remove the repository from state - aborting destroy to protect it"
                SKIP_TERRAFORM=true
                TERRAFORM_SUCCESS=true
              fi
            fi

            if [ "$SKIP_TERRAFORM" = false ]; then
              print_info "Running $IAC_CMD destroy (this may take 2-3 minutes)..."

              DESTROY_OK=false
              if $IAC_CMD destroy -var="pat=$HARNESS_PAT" $TFVARS_ARG -auto-approve; then
                DESTROY_OK=true
              else
                # Harness can briefly report a connector as "referenced" right after the template/
                # service that used it was deleted; one retry after a short pause clears it
                print_info "Some resources couldn't be deleted yet - retrying in 15 seconds..."
                sleep 15
                if $IAC_CMD destroy -var="pat=$HARNESS_PAT" $TFVARS_ARG -auto-approve; then
                  DESTROY_OK=true
                fi
              fi

              if [ "$DESTROY_OK" = true ]; then
                print_status "Harness resources destroyed successfully via $IAC_CMD"
                TERRAFORM_SUCCESS=true
                HARNESS_DELETE_SUCCESS=true
              else
                print_error "$IAC_CMD destroy encountered errors"
                print_info "If you see 401 Unauthorized, your Harness PAT may be expired."
                print_info "Generate a new PAT and run: export DEMO_BASE_PAT=\"pat.xxx\" && ./stop-demo.sh --force-api-delete"
                print_info "Some resources may have been deleted. Check kit/terraform.tfstate"
                print_info ""

                # Offer to delete the entire project via API as fallback
                echo ""
                echo -e "${YELLOW}$IAC_CMD couldn't delete all resources due to dependencies.${NC}"
                echo -e "${YELLOW}Would you like to delete the entire '$PROJECT_NAME' project via Harness API?${NC}"
                echo "This will forcefully delete the project and all its resources."
                echo ""
                read -p "Delete '$PROJECT_NAME' project via API? [Y/n]: " DELETE_PROJECT_API

                # Default to yes if empty
                DELETE_PROJECT_API=${DELETE_PROJECT_API:-yes}

                # Accept y/Y/yes as confirmation
                if [[ "$DELETE_PROJECT_API" =~ ^[Yy]([Ee][Ss])?$ ]]; then
                  print_section "Deleting Project via Harness API"
                  if delete_harness_project_via_api; then
                    TERRAFORM_SUCCESS=true
                  fi
                else
                  print_info "Skipping API deletion"
                  print_info ""
                  print_info "To retry $IAC_CMD destroy:"
                  print_info "  cd kit && $IAC_CMD destroy -var=\"pat=\$DEMO_BASE_PAT\" -var-file=\"se-parms.tfvars\""
                  print_info ""
                  print_info "Or delete manually in Harness UI:"
                  print_info "  Navigate to Projects > $PROJECT_NAME > ⋮ > Delete Project"
                fi
              fi
            fi
          fi

          # Handle force API delete or missing state scenarios
          if [ "$SKIP_TERRAFORM" = true ] && [ "$TERRAFORM_SUCCESS" = false ]; then
            print_section "Deleting Project via Harness API"
            if delete_harness_project_via_api; then
              TERRAFORM_SUCCESS=true
            fi
          fi

          cd ..

          # Clean up IaC state files if deletion was successful
          if [ "$TERRAFORM_SUCCESS" = true ]; then
            print_info "Cleaning up IaC state files..."
            if [ -f "kit/terraform.tfstate" ]; then
              rm -f kit/terraform.tfstate
              rm -f kit/terraform.tfstate.backup
              print_status "State files removed"
            fi
          fi
        fi
      fi
    else
      print_info "Skipping Harness resource deletion (user cancelled)"
    fi
  fi

  if [ "$DELETE_HARNESS_PROJECT" = true ] && [ "$HARNESS_DELETE_SUCCESS" = false ]; then
    echo ""
    print_error "Harness project '$PROJECT_NAME' was NOT deleted"
    print_info "The cleanup summary below reflects what was actually removed."
  fi
fi

# Delete Docker Hub Repository (optional)
if [ "$DELETE_DOCKER_REPO" = true ]; then
  print_section "Deleting Docker Hub Repository"

  # Check if we have credentials, prompt if missing
  if [ -z "$DOCKER_USERNAME" ]; then
    echo ""
    print_info "Docker Hub username not found in config files"
    read -p "Enter your Docker Hub username (or press Enter to skip): " DOCKER_USERNAME
  fi

  if [ -z "$DOCKER_PAT" ] || [ "$DOCKER_PAT" = "logged-in-via-docker-desktop" ]; then
    echo ""
    print_info "Docker Hub password/PAT not found in config files"
    echo "To create a PAT: https://hub.docker.com/settings/security"
    echo ""
    read -sp "Enter your Docker Hub password/PAT (or press Enter to skip): " DOCKER_PAT
    echo ""
  fi

  # Check again after prompting
  if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PAT" ] || [ "$DOCKER_PAT" = "logged-in-via-docker-desktop" ]; then
    print_info "Skipping Docker Hub repository deletion (credentials not provided)"
  else
    # Prompt for confirmation
    echo ""
    echo -e "${YELLOW}WARNING: This will permanently delete the Docker Hub repository:${NC}"
    echo "  Repository: $DOCKER_USERNAME/harness-demo"
    echo "  All images and tags will be deleted"
    echo ""
    read -p "Are you sure you want to delete this Docker Hub repository? [Y/n]: " CONFIRM_DOCKER

    # Default to yes if empty
    CONFIRM_DOCKER=${CONFIRM_DOCKER:-yes}

    # Accept y/Y/yes as confirmation
    if [[ "$CONFIRM_DOCKER" =~ ^[Yy]([Ee][Ss])?$ ]]; then
      print_info "Deleting Docker Hub repository '$DOCKER_USERNAME/harness-demo'..."

      # First, get a JWT token from Docker Hub
      TOKEN_RESPONSE=$(curl -s -X POST \
        "https://hub.docker.com/v2/users/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${DOCKER_USERNAME}\",\"password\":\"${DOCKER_PAT}\"}")

      JWT_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

      if [ -n "$JWT_TOKEN" ]; then
        # Delete the repository
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
          "https://hub.docker.com/v2/repositories/${DOCKER_USERNAME}/harness-demo/" \
          -H "Authorization: JWT ${JWT_TOKEN}")

        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "202" ]; then
          print_status "Docker Hub repository '$DOCKER_USERNAME/harness-demo' deleted successfully"
        elif [ "$HTTP_CODE" = "404" ]; then
          print_info "Docker Hub repository not found (may already be deleted)"
        else
          print_error "Failed to delete Docker Hub repository (HTTP $HTTP_CODE)"
          print_info "You may need to delete it manually through the Docker Hub UI"
        fi
      else
        print_error "Failed to authenticate with Docker Hub"
        print_info "Please check your Docker Hub credentials and try again"
        print_info "You can delete the repository manually at: https://hub.docker.com/repository/docker/$DOCKER_USERNAME/harness-demo"
      fi
    else
      print_info "Skipping Docker Hub repository deletion (user cancelled)"
    fi
  fi
fi

# Delete Configuration Files (optional)
if [ "$DELETE_CONFIG_FILES" = true ]; then
  print_section "Deleting Configuration Files"

  # Prompt for confirmation
  echo ""
  echo -e "${YELLOW}WARNING: This will delete local configuration and state files:${NC}"
  echo "  - .demo-config (cached credentials)"
  echo "  - kit/se-parms.tfvars (Terraform variables)"
  echo "  - kit/terraform.tfstate* (IaC state files)"
  echo "  - kit/.terraform/ (IaC working directory)"
  echo "  - kit/*.tfplan (Terraform plan files)"
  echo ""
  echo "After deletion, you will need to re-enter credentials on next run."
  echo ""
  read -p "Are you sure you want to delete these files? [Y/n]: " CONFIRM_CONFIG

  # Default to yes if empty
  CONFIRM_CONFIG=${CONFIRM_CONFIG:-yes}

  # Accept y/Y/yes as confirmation
  if [[ "$CONFIRM_CONFIG" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    FILES_DELETED=false

    if [ -f ".demo-config" ]; then
      rm -f .demo-config
      print_status "Deleted .demo-config"
      FILES_DELETED=true
    fi

    if [ -f "kit/se-parms.tfvars" ]; then
      rm -f kit/se-parms.tfvars
      print_status "Deleted kit/se-parms.tfvars"
      FILES_DELETED=true
    fi

    if [ -f "kit/terraform.tfstate" ]; then
      rm -f kit/terraform.tfstate
      print_status "Deleted kit/terraform.tfstate"
      FILES_DELETED=true
    fi

    if [ -f "kit/terraform.tfstate.backup" ]; then
      rm -f kit/terraform.tfstate.backup
      print_status "Deleted kit/terraform.tfstate.backup"
      FILES_DELETED=true
    fi

    if [ -d "kit/.terraform" ]; then
      rm -rf kit/.terraform
      print_status "Deleted kit/.terraform/"
      FILES_DELETED=true
    fi

    if ls kit/*.tfplan &> /dev/null; then
      rm -f kit/*.tfplan
      print_status "Deleted kit/*.tfplan files"
      FILES_DELETED=true
    fi

    if [ "$FILES_DELETED" = false ]; then
      print_info "No configuration files found to delete"
    fi
  else
    print_info "Skipping configuration file deletion (user cancelled)"
  fi
fi

# Display current status
if [ "$K8S_AVAILABLE" = true ]; then
  print_section "Current Cluster Status"
else
  print_section "Cleanup Status"
fi

if [ "$K8S_AVAILABLE" = true ]; then

echo ""
echo "Namespaces:"
kubectl get namespaces | grep -E "NAME|default|monitoring|harness" || echo "  Default namespaces only"

echo ""
echo "Deployments in default namespace:"
DEPLOYMENTS=$(kubectl get deployments --no-headers 2>/dev/null | wc -l)
if [ "$DEPLOYMENTS" -eq 0 ]; then
  echo "  No deployments found"
else
  kubectl get deployments
fi

echo ""
echo "Services in default namespace:"
SERVICES=$(kubectl get services --no-headers 2>/dev/null | grep -v kubernetes | wc -l)
if [ "$SERVICES" -eq 0 ]; then
  echo "  No services found (except kubernetes default)"
else
  kubectl get services | grep -v kubernetes
fi

fi  # End of K8S_AVAILABLE check for status display

# Stop cluster (optional)
# Allow stopping if K8S_AVAILABLE is true OR if we detected a cluster directly (K8S_TYPE is set)
if [ "$STOP_CLUSTER" = true ] && ([ "$K8S_AVAILABLE" = true ] || [ -n "$K8S_TYPE" ]); then
  if [ "$K8S_TYPE" = "colima" ]; then
    print_section "Stopping Colima"

    print_info "Stopping Colima cluster..."
    colima stop
    print_status "Colima stopped"

    # Delete Colima VM if requested (from custom menu or complete cleanup)
    if [ "$DELETE_COLIMA_VM" = true ]; then
      print_info "Deleting Colima VM..."
      colima delete -f --data
      print_status "Colima VM and its data disk deleted"
      echo ""
      print_info "To start fresh, run: ./start-demo.sh (it creates Colima in your chosen mode)"
    elif [ "$DELETE_HARNESS_PROJECT" = true ] && [ "$DELETE_PROMETHEUS" = true ]; then
      # For complete cleanup (option 5), offer to delete the Colima VM
      echo ""
      read -p "Delete Colima VM for a completely fresh start? [Y/n]: " DELETE_VM_PROMPT
      DELETE_VM_PROMPT=${DELETE_VM_PROMPT:-yes}

      if [[ "$DELETE_VM_PROMPT" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        print_info "Deleting Colima VM..."
        colima delete -f --data
        print_status "Colima VM and its data disk deleted"
        echo ""
        print_info "To start fresh, run: ./start-demo.sh (it creates Colima in your chosen mode)"
      fi
    fi
  elif [ "$K8S_TYPE" = "minikube" ]; then
    print_section "Stopping minikube"

    print_info "Stopping minikube cluster..."
    minikube stop
    print_status "minikube stopped"
  elif [ "$K8S_TYPE" = "rancher-desktop" ]; then
    print_info "Cannot automatically stop Rancher Desktop"
    print_info "Please stop it manually through the Rancher Desktop UI"
  elif [ "$K8S_TYPE" = "docker-desktop" ]; then
    print_info "Cannot automatically stop Docker Desktop"
    print_info "Please stop it manually through the Docker Desktop UI"
  else
    print_info "Cluster type '$K8S_TYPE' - not stopping automatically"
  fi
else
  if [ "$K8S_TYPE" = "colima" ]; then
    print_info "Keeping Colima running (use --stop-cluster to stop)"
  elif [ "$K8S_TYPE" = "minikube" ]; then
    print_info "Keeping minikube running (use --stop-cluster to stop)"
  fi
fi

# Display completion message
print_section "Cleanup Summary"
echo ""
echo "Cleanup complete! 🧹"
echo ""
echo "What was removed:"

if [ "$K8S_AVAILABLE" = true ]; then
  echo "  ✓ Frontend deployment and service"
  echo "  ✓ Backend deployment and service"
fi

if [ "$DELETE_PROMETHEUS" = true ]; then
  echo "  ✓ Prometheus monitoring"
elif [ "$K8S_AVAILABLE" = true ]; then
  echo "  ⊘ Prometheus monitoring (still running)"
fi

if [ "$HARNESS_DELETE_SUCCESS" = true ]; then
  echo "  ✓ Harness '$PROJECT_NAME' project"
elif [ "$DELETE_HARNESS_PROJECT" = true ]; then
  echo "  ✗ Harness '$PROJECT_NAME' project (deletion failed — project still exists)"
else
  echo "  ⊘ Harness project (still exists)"
fi

if [ "$DELETE_DOCKER_REPO" = true ]; then
  echo "  ✓ Docker Hub repository (harness-demo)"
else
  echo "  ⊘ Docker Hub repository (still exists)"
fi

if [ "$DELETE_CONFIG_FILES" = true ]; then
  echo "  ✓ Configuration files (.demo-config, se-parms.tfvars, state files)"
else
  echo "  ⊘ Configuration files (still exist)"
fi

if [ "$STOP_CLUSTER" = true ] && ([ "$K8S_TYPE" = "minikube" ] || [ "$K8S_TYPE" = "colima" ]); then
  echo "  ✓ Kubernetes cluster ($K8S_TYPE stopped)"
elif [ "$K8S_AVAILABLE" = true ]; then
  echo "  ⊘ Kubernetes cluster (still running)"
fi

echo ""
echo "What remains:"
ANYTHING_REMAINS=false

if [ "$DELETE_PROMETHEUS" = false ] && [ "$K8S_AVAILABLE" = true ]; then
  echo "  • Prometheus monitoring (in 'monitoring' namespace)"
  ANYTHING_REMAINS=true
fi

if [ "$STOP_CLUSTER" = false ] && [ "$K8S_AVAILABLE" = true ]; then
  echo "  • Kubernetes cluster ($(kubectl config current-context))"
  ANYTHING_REMAINS=true
fi

if [ "$DELETE_HARNESS_PROJECT" = false ] || [ "$HARNESS_DELETE_SUCCESS" = false ]; then
  if [ "$HARNESS_DELETE_SUCCESS" = false ] && [ "$DELETE_HARNESS_PROJECT" = true ]; then
    echo "  • Harness '$PROJECT_NAME' project (deletion failed — delete manually or retry with a fresh PAT)"
  else
    echo "  • Harness '$PROJECT_NAME' project (manage via Harness UI or IaC)"
  fi
  ANYTHING_REMAINS=true
fi

if [ "$DELETE_DOCKER_REPO" = false ]; then
  echo "  • Docker Hub repository (use 'docker images' to view local images)"
  ANYTHING_REMAINS=true
fi

if [ "$DELETE_CONFIG_FILES" = false ]; then
  echo "  • Configuration files (.demo-config, kit/se-parms.tfvars, state files)"
  ANYTHING_REMAINS=true
fi

if [ "$ANYTHING_REMAINS" = false ]; then
  echo "  Nothing - complete cleanup performed!"
fi

echo ""

# Show helpful restart instructions if Harness resources were preserved
if [ "$DELETE_HARNESS_PROJECT" = false ] && [ "$DELETE_PROMETHEUS" = false ]; then
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}Ready to restart the demo!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Your Harness resources are preserved. To restart the demo:"
  echo ""

  if [ "$STOP_CLUSTER" = true ]; then
    echo -e "${CYAN}1. Start your Kubernetes cluster:${NC}"
    if [ "$K8S_TYPE" = "colima" ]; then
      echo "   colima start   (restarts the existing VM with its saved settings)"
    elif [ "$K8S_TYPE" = "minikube" ]; then
      echo "   minikube start"
    fi
    echo ""
    echo -e "${CYAN}2. Run the demo startup:${NC}"
    echo "   ./start-demo.sh --skip-terraform"
  else
    echo -e "${CYAN}Run the demo startup:${NC}"
    echo "   ./start-demo.sh --skip-terraform"
  fi
  echo ""
  echo "The --skip-terraform flag will skip Harness resource creation"
  echo "and just rebuild/push images and deploy to your local cluster."
  echo ""
fi

# Show options for additional cleanup
SUGGEST_FULL_CLEANUP=false
if [ "$DELETE_PROMETHEUS" = false ] || [ "$STOP_CLUSTER" = false ] || [ "$DELETE_HARNESS_PROJECT" = false ] || [ "$DELETE_DOCKER_REPO" = false ] || [ "$DELETE_CONFIG_FILES" = false ]; then
  SUGGEST_FULL_CLEANUP=true
fi

if [ "$SUGGEST_FULL_CLEANUP" = true ]; then
  echo "For additional cleanup options, run:"
  echo "  ./stop-demo.sh"
  echo ""
  echo "Or use command-line flags:"
  if [ "$DELETE_HARNESS_PROJECT" = false ]; then
    echo "  ./stop-demo.sh --delete-harness-project    # Delete Harness project"
  fi
  if [ "$DELETE_DOCKER_REPO" = false ]; then
    echo "  ./stop-demo.sh --delete-docker-repo        # Delete Docker Hub repo"
  fi
  if [ "$DELETE_CONFIG_FILES" = false ]; then
    echo "  ./stop-demo.sh --delete-config-files       # Delete local config files"
  fi
  if [ "$DELETE_PROMETHEUS" = false ] && [ "$K8S_AVAILABLE" = true ]; then
    echo "  ./stop-demo.sh --delete-prometheus         # Delete Prometheus"
  fi
  if [ "$STOP_CLUSTER" = false ] && ([ "$K8S_TYPE" = "minikube" ] || [ "$K8S_TYPE" = "colima" ]); then
    echo "  ./stop-demo.sh --stop-cluster              # Stop $K8S_TYPE"
  fi
  echo "  ./stop-demo.sh --full-cleanup              # Delete everything"
  echo ""
fi

print_status "Shutdown complete!"
echo ""
