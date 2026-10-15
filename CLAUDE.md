# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Harness.io Partner Demo Kit - a self-contained demonstration environment for showcasing Harness platform capabilities (CI/CD, Code Repository, Continuous Verification, Security Testing). The demo runs entirely on local infrastructure (Colima for Apple Silicon, minikube/Docker Desktop/Rancher Desktop for other platforms) to minimize external dependencies.

**Important**: All Harness resources are created in a dedicated project (customizable name, default: "Base Demo"). This segregates demo resources from production environments.

## Architecture

The repository contains three main components that work together:

### Frontend Application
- **Location**: [frontend-app/harness-webapp/](frontend-app/harness-webapp/)
- **Stack**: Angular 17, TypeScript
- **Purpose**: Demo web application with distribution testing UI and feature flag integration
- **Key dependencies**: Harness Feature Flags SDK (`@harnessio/ff-javascript-client-sdk`), ngx-charts for visualization

### Backend Application
- **Location**: [backend/](backend/)
- **Stack**: Django 5.0, Python, PostgreSQL
- **Purpose**: REST API backend serving the demo application
- **Structure**: Standard Django project with `backend/` (core) and `deploy/` (app) modules

### Infrastructure & Deployment
- **Terraform/OpenTofu configs**: [kit/](kit/) - Provisions Harness resources (connectors, environments, services, monitored services)
- **K8s manifests**: [harness-deploy/](harness-deploy/) - Deployment and service definitions for frontend and backend
- **Monitoring**: Prometheus configuration at [kit/prometheus.yml](kit/prometheus.yml)

## Demo Access URLs

Once the demo is running, access the following URLs in your browser:

| Service | URL | Description |
|---------|-----|-------------|
| **Lab Documentation** | http://localhost:30001 | Interactive lab guides for the demo walkthrough |
| **Demo Application** | http://localhost:8080 | Frontend web application (after deployment) |
| **Harness UI** | https://app.harness.io | Harness platform - select your demo project |

**Recommended Setup**: Use Chrome's **split tab view** (or two browser windows side-by-side) with:
- Left side: Harness UI at https://app.harness.io
- Right side: Lab documentation at http://localhost:30001

This allows you to follow the lab instructions while working in the Harness platform without switching tabs.

**Note for minikube users**: Run `minikube tunnel` in a separate terminal to access services at localhost.

## Build and Development Commands

### Frontend (Angular)
```bash
cd frontend-app/harness-webapp
npm install
npm run build          # Production build
npm run start          # Dev server
npm run test           # Run tests
```

### Backend (Django)
```bash
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

### Python Tests
The [python-tests/](python-tests/) directory contains test suites used in the CI/CD demo:
```bash
cd python-tests
pytest                 # Run all tests
```

### Docker Images
The repository uses three Docker images. Replace `dockerhubaccountid` with your Docker Hub account:

**✅ Automated**: The [start-demo.sh](start-demo.sh) script builds backend, test and docs images with docker buildx (BuildKit) for **linux/amd64 and linux/arm64** under the same tag and pushes them, so the same tags work on Harness Cloud (amd64) and Apple Silicon clusters. Manual builds are only needed if:
- Running the script with `--skip-docker-build`
- Rebuilding images after code changes
- Building the frontend image locally

**buildx required**: Docker Desktop includes it; Homebrew's `docker` CLI does not (the script offers to set it up):
```bash
brew install docker-buildx
mkdir -p ~/.docker/cli-plugins && ln -sfn "$(brew --prefix)/opt/docker-buildx/bin/docker-buildx" ~/.docker/cli-plugins/docker-buildx
```
Without buildx, `docker build` uses the deprecated legacy builder (single arch).

**Multi-arch builder** (once):
```bash
docker buildx create --name harness-demo-builder --driver docker-container
```

**Backend Application** (Django runtime, from the repo root):
```bash
docker buildx build --builder harness-demo-builder --platform linux/amd64,linux/arm64 -t dockerhubaccountid/harness-demo:backend-latest --push backend
```

**Test Image** (CI pipeline with pytest pre-installed):
```bash
docker buildx build --builder harness-demo-builder --platform linux/amd64,linux/arm64 -t dockerhubaccountid/harness-demo:test-latest --push python-tests
```

**Frontend Application** (Angular - built in CI, not locally):
```bash
# Only needed if building locally for testing
docker buildx build --builder harness-demo-builder --platform linux/amd64,linux/arm64 -t dockerhubaccountid/harness-demo:demo-base-<tag> --push frontend-app/harness-webapp
```

**Image Tag Reference:**
- `backend-latest` - Django backend application (production)
- `test-latest` - Python + pytest environment (CI only)
- `demo-base-<tag>` - Frontend Angular application

**Architecture Note**: Harness Cloud runs amd64, so every image must include linux/amd64. Multi-arch (amd64 + arm64) is preferred; an amd64-only image still runs on a native arm64 Colima VM via Rosetta.

## Infrastructure Commands

### Automated Setup (Recommended)

The repository includes automation scripts for complete demo setup:

**start-demo.sh** - Automated infrastructure and Harness resource setup:
```bash
# Make executable (first time only)
chmod +x start-demo.sh stop-demo.sh

# Run complete setup
./start-demo.sh

# Options:
./start-demo.sh --skip-docker-build   # Skip image builds (docs still deploy from the existing image)
./start-demo.sh --skip-terraform      # Skip Harness resource creation
./start-demo.sh --skip-delegate       # Skip the automatic Harness delegate install
./start-demo.sh --org <identifier>    # Harness organization (otherwise chosen from a prompted list)
./start-demo.sh --participant <id>    # Participant ID for a shared Harness project
./start-demo.sh --colima-arch native|amd64   # Apple Silicon Colima VM architecture (default: native)
```

Every setting is also prompted interactively (previous answers from `.demo-config` are the defaults); flags only pre-answer prompts. Don't add flag-only or env-var-only settings: inexperienced users forget them.

Shared helpers live in [scripts/demo-lib.sh](scripts/demo-lib.sh) (bash 3.2 compatible).

**What start-demo.sh automates:**
1. **Detects platform** (macOS/Windows/Linux) and architecture (ARM64/AMD64)
2. **Validates Kubernetes tool** based on platform:
   - Apple Silicon Macs: Requires Colima; prompts for native arm64 (default) or amd64 emulation, remembered as `COLIMA_ARCH_MODE` in `.demo-config`
   - Windows: Recommends minikube (allows Docker Desktop/Rancher Desktop)
   - Other platforms: Flexible (minikube, Colima, Docker Desktop, Rancher Desktop)
3. Checks prerequisites (Docker, docker buildx, kubectl, helm, Terraform/OpenTofu)
4. Detects and starts Kubernetes (Colima/minikube) if needed
5. **Verifies the Docker daemon's real architecture** (`docker info --format '{{.Architecture}}'`) matches the chosen Colima mode
6. **Validates cluster resources** (minimum 4 CPU cores, 8GB memory) with remediation guidance
7. **Creates Docker Hub secret** (`dockerhub-pull`) in Kubernetes for pulling Harness CI images
8. **Deploys Prometheus in background** (non-blocking) for continuous verification
9. Authenticates to Docker Hub (smart detection of existing login)
10. **Builds Docker images in parallel** (backend, test, docs) with buildx for linux/amd64 + linux/arm64, with progress tracking
11. **Starts Terraform/OpenTofu init early** (runs in background while collecting credentials)
12. **Updates Docker Hub secret** with authenticated credentials after login
13. **Collects Harness credentials** (Account ID, PAT, Docker password) and participant ID
14. **Updates kit/se-parms.tfvars** automatically
15. **Runs pre-flight checks**: token shape `pat.<account>.<id>.<secret>`, token account matches `HARNESS_ACCOUNT_ID`, org exists, permissions (project-create for a new project; project-scoped edit for an existing one), participant-ID collision. Bypass: `DEMO_SKIP_PREFLIGHT=true`
16. **Runs Terraform/OpenTofu** (plan, apply with spinners) to create all Harness resources (an existing project is imported, never recreated)
17. Saves configuration to `.demo-config` for subsequent runs
18. Deploys documentation to Kubernetes at http://localhost:30001 on every run (`imagePullPolicy: Always` + rollout restart picks up a rebuilt `docs-latest`)
19. **Installs the Harness delegate** with Helm at project scope: fetches the project `default_token`, manager endpoint and latest delegate image from the Harness API, names it `local-k8s-delegate` (or `<participant>-k8s-delegate`) to match the connectors, and waits until it's connected. Manual fallback: Lab 0

**Shared project / participant ID**: Several people can share one Harness project. Each picks an ID (1-20 lowercase letters/digits, starting with a letter; saved as `PARTICIPANT_ID`). Terraform appends `_<id>` to identifiers and ` <id>` to names of everything the kit creates (repo `partner_demo_kit_<id>`, connectors `workshop_k8s_<id>`/`workshopdocker_<id>`/`prometheus_<id>`, environments, infra, backend service, template, monitored services); the delegate becomes `<id>-k8s-delegate` and lab guides are personalized. Empty ID = original single-user names.

**Performance Optimizations:**
- Parallel Docker builds save 2-4 minutes vs sequential builds
- Background Prometheus deployment runs while Docker builds
- Early Terraform/OpenTofu init runs while collecting credentials
- Progress spinners provide feedback during long operations

**stop-demo.sh** - Interactive cleanup script with smart defaults:
```bash
./stop-demo.sh                    # Shows interactive menu (default: minimal cleanup)

# Interactive menu options:
# 1) Stop K8s deployments only (Recommended - preserves Harness resources)
# 2) Stop K8s deployments + Delete Prometheus
# 3) Stop K8s deployments + Stop cluster
# 4) Full cleanup (delete all Harness resources)
# 5) Complete cleanup (everything including cluster)
# 6) Custom cleanup options
# 0) Exit without doing anything

# Command-line flags (skip interactive menu):
./stop-demo.sh --delete-prometheus      # Also remove Prometheus
./stop-demo.sh --stop-cluster           # Also stop Colima/minikube
./stop-demo.sh --delete-harness-project # Delete Harness demo project
./stop-demo.sh --delete-docker-repo     # Delete Docker Hub repository
./stop-demo.sh --full-cleanup           # Complete cleanup (keeps credentials)
./stop-demo.sh --no-interactive         # Skip menu, use minimal cleanup
```

stop-demo.sh never deletes a project it didn't create or that is shared (`PROJECT_PREEXISTING=true` or `PARTICIPANT_ID` set): it removes the project from Terraform state before `destroy`, so only that user's resources are destroyed. It uses `HARNESS_ORG_ID` (not a hard-coded `default`), and its Colima "fresh start" runs `colima delete -f --data`.

**Recommended Workflow:**
- After running the demo, use the default interactive menu (option 1) to stop deployments
- Preserves Harness resources for easy restart: `./start-demo.sh --skip-terraform`
- Full cleanup only needed when completely resetting the demo environment

**Credential Management:**
- Credentials saved to `.demo-config` (git-ignored)
- Reuses values on subsequent runs
- Supports environment variable `DEMO_BASE_PAT` for Harness PAT
- Detects Docker Desktop login automatically

### Terraform/OpenTofu (Harness Resource Provisioning) - Manual Method

The demo supports both **Terraform** and **OpenTofu** for provisioning Harness resources. The IaC configuration files are fully compatible with both tools.

**Important**: Set the Harness PAT as an environment variable on Mac/Linux:
```bash
cd kit

# Export the PAT (required for Mac/Linux)
export DEMO_BASE_PAT="pat.SAn9tg9eRrWyEJyLZ01ibw.xx"

# Verify it's set correctly
echo $DEMO_BASE_PAT

# Run with Terraform:
terraform init
terraform plan -var="pat=$DEMO_BASE_PAT" -var-file="se-parms.tfvars" -out=plan.tfplan
terraform apply -auto-approve plan.tfplan

# OR run with OpenTofu:
tofu init
tofu plan -var="pat=$DEMO_BASE_PAT" -var-file="se-parms.tfvars" -out=plan.tfplan
tofu apply -auto-approve plan.tfplan
```

The IaC configuration creates a Harness project with configurable name (default: "Base Demo"):
- Harness project (customizable via `project_name` and `project_identifier` variables)
- K8s connector (`workshop_k8s`) - for local Kubernetes cluster (Colima/minikube/Rancher Desktop/Docker Desktop)
- Docker connector (`workshopdocker`) - for Docker Hub
- Prometheus connector - for continuous verification
- Docker username/password secrets
- "Compile Application" template
- Dev and Prod environments
- K8s Dev infrastructure definition
- Backend service (with K8s manifests from Harness Code Repository)
- Monitored services (backend_dev, backend_prod) for continuous verification
- Code repository (`partner_demo_kit`) mirrored from GitHub

### Kubernetes (Platform-Specific Setup)

**Apple Silicon (M1/M2/M3/M4) - Colima, native arm64 (REQUIRED, default):**
```bash
# Install Colima and required dependencies (native mode)
brew install colima docker kubectl

# Switching architectures (e.g. from an old x86_64 VM)? Delete the data disk too;
# plain `colima delete` keeps it and the old cluster's data breaks Kubernetes on the new VM
colima stop
colima delete --data

# Start a native arm64 VM (Virtualization.framework; amd64-only images still run via Rosetta)
colima start --vm-type=vz --vz-rosetta --arch aarch64 --cpu 4 --memory 8 --kubernetes --runtime docker

# Verify native architecture (should show "arm64")
kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.architecture}'
docker info --format '{{.Architecture}}'   # what start-demo.sh checks

# Optional amd64 VM: ./start-demo.sh --colima-arch amd64 (needs qemu lima-additional-guestagents).
# On Apple Silicon, --arch x86_64 is a qemu software-emulated VM, NOT Rosetta: very slow, can be unstable.

# Setup Prometheus (from kit/ directory)
cd kit
kubectl create namespace monitoring
kubectl -n monitoring apply -f ./prometheus.yml

# View deployments
kubectl get pods -A | grep deployment
kubectl get services -A | grep svc

# Cleanup
kubectl delete deployment frontend-deployment backend-deployment
kubectl delete service web-frontend-svc web-backend-svc

# Stop Colima
colima stop
```

**Windows - Minikube (Recommended):**
```bash
# Download from: https://minikube.sigs.k8s.io/docs/start/

# Start minikube and enable addons
minikube start
minikube addons enable metrics-server

# Setup Prometheus (from kit/ directory)
cd kit
kubectl create namespace monitoring
kubectl -n monitoring apply -f ./prometheus.yml

# View deployments
kubectl get pods -A | grep deployment
kubectl get services -A | grep svc

# Access services (requires minikube tunnel running in separate terminal)
minikube tunnel

# Cleanup
kubectl delete deployment frontend-deployment backend-deployment
kubectl delete service web-frontend-svc web-backend-svc
```

**Intel Mac / Linux - Flexible Options:**
```bash
# Option 1: Minikube
minikube start
minikube addons enable metrics-server

# Option 2: Colima (no need for architecture emulation)
colima start --cpu 4 --memory 8 --kubernetes

# Option 3: Rancher Desktop - Enable Kubernetes in preferences
# Option 4: Docker Desktop - Enable Kubernetes in settings

# Prometheus setup (same for all)
cd kit
kubectl create namespace monitoring
kubectl -n monitoring apply -f ./prometheus.yml

# Services automatically accessible with Rancher/Docker Desktop (no tunnel needed)
# For minikube: Run 'minikube tunnel' in a separate terminal
```

### Prometheus with ngrok (Optional)

If the Harness delegate cannot reach the cluster-local Prometheus URL, expose it via ngrok:

```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090

# In another terminal, expose via ngrok
ngrok http 9090

# Copy the ngrok HTTPS URL (e.g., https://abc123.ngrok.io)
# Update the Prometheus connector URL in Harness UI or kit/main.tf to use this ngrok URL
```

## Important Configuration Details

### Docker Hub Account ID Replacement
Throughout the codebase, replace the placeholder `dockerhubaccountid` with your actual Docker Hub account ID. This appears in:
- [kit/main.tf](kit/main.tf) - Line 300: `imagePath: dockerhubaccountid/harness-demo`
- Build commands in documentation
- Demo instructions

### IaC Variables
Configure [kit/se-parms.tfvars](kit/se-parms.tfvars) with:
- `account_id`: Your Harness account ID (found in URL when viewing your profile)
- `docker_username`: Docker Hub username
- `DOCKER_PAT`: Docker Hub password/PAT
- `project_name`: Display name for your Harness project (default: "Base Demo")
- `project_identifier`: Identifier for your project (alphanumeric + underscores, default: "Base_Demo")

### Environment Setup Requirements
- Docker and Docker Hub account with `harness-demo` repository created
- **Kubernetes** (platform-specific):
  - **Apple Silicon Macs**: Colima (REQUIRED), native arm64 VM by default; amd64 emulation optional
  - **Windows**: minikube (recommended), Docker Desktop, or Rancher Desktop
  - **Intel Mac/Linux**: minikube, Colima, Docker Desktop, or Rancher Desktop
- **Minimum Cluster Resources**: 4 CPU cores, 8GB memory (validated by start-demo.sh)
- **Terraform or OpenTofu** - IaC tool for provisioning Harness resources
- **Docker buildx plugin** (multi-arch builds)
- kubectl and helm (helm is required: start-demo.sh installs the delegate with it)
- Harness account with CD, CI, and Code Repo modules enabled
- Harness delegate at **project** scope — installed automatically by start-demo.sh (`local-k8s-delegate` or `<participant>-k8s-delegate`); manual fallback in Lab 0 (set both the Helm release name and `--set delegateName=` to that name)

### Harness Code Repository Git Credentials

After the IaC (Terraform/OpenTofu) creates the `partner_demo_kit` repository in Harness Code:

1. Navigate to Harness UI > Code Repository module > your demo project
2. Click on "partner_demo_kit" repository
3. Click "Clone" button (top right) > "+Generate Clone Credential"
4. Save the generated username and token
5. Use these credentials when cloning or pushing to the Harness Code Repository

The repository is initially mirrored from `harness-community/partner-demo-kit` on GitHub.

### Repository Clone Location

When cloning this repository locally for development:
- Recommended locations: `~/projects/partner-demo-kit` or `~/Documents/partner-demo-kit`
- Keep it accessible for easy navigation during demos

## Demo Flow

The complete demo workflow is documented in:
1. [base-resources.txt](base-resources.txt) - Initial setup and resource provisioning
2. [base-demo.txt](base-demo.txt) - Step-by-step demo execution guide (all in your demo project)
3. [markdown/](markdown/) - Individual demo module guides (0-7) - originally for Instruqt workshops

The demo demonstrates (all within your demo project):
1. **Code Repository Secret Scanning** - Demonstrates blocking sensitive commits (TOKEN in backend/entrypoint.sh)
2. **CI Pipeline** - Build stage with test intelligence, compile template, and Docker image push (uses **Harness Cloud** infrastructure)
3. **Frontend Deployment** - Rolling deployment strategy to local K8s
4. **Backend Deployment** - Canary deployment strategy to local K8s
5. **Continuous Verification** - Uses Prometheus metrics to verify canary deployments (5-minute duration)
6. **Security Scanning** - Requires licensed partner org (not available in free tier)
7. **OPA Policy Enforcement** - Requires licensed partner org (not available in free tier)

## Infrastructure Architecture

- **CI Builds**: Use Harness Cloud (requires credit card verification, works on all platforms)
- **CD Deployments**: Use local Kubernetes cluster
  - Apple Silicon: Colima, native arm64 VM by default (amd64 images run via Rosetta); `--colima-arch amd64` for a qemu-emulated VM
  - Other platforms: minikube, Docker Desktop, or Rancher Desktop
- **Images**: multi-arch (linux/amd64 + linux/arm64) under the same tags

## Reset/Cleanup Procedure

To reset the demo environment and start fresh:

**1. Harness Resources (in your demo project):**
```
- Navigate to Harness UI > Code Repo module > Manage Repository
  - Delete "partner_demo_kit" repository
- Navigate to Harness UI > Projects
  - Delete your demo project (this removes all project resources)
```

**2. Local IaC State:**
```bash
cd kit
git clean -dxf  # WARNING: Removes all untracked files including .tfstate files

# OR manually destroy with Terraform/OpenTofu first:
terraform destroy -var="pat=$DEMO_BASE_PAT" -var-file="se-parms.tfvars"
# OR with OpenTofu:
tofu destroy -var="pat=$DEMO_BASE_PAT" -var-file="se-parms.tfvars"
```

**3. Docker Hub:**
```
- Remove repository "dockerhubaccountid/harness-demo" from Docker Hub UI
```

**4. Kubernetes Resources:**
```bash
kubectl delete deployment frontend-deployment
kubectl delete service web-frontend-svc
kubectl delete deployment backend-deployment
kubectl delete service web-backend-svc
```

## Key Files for Customization

- Frontend Docker image tag pattern: `demo-base-<+pipeline.sequenceId>`
- Backend deployment includes canary verification with 5-minute duration
- The "canary" feature: A yellow cartoon graphic served by canary pods (visible in distribution test UI at localhost:8080)
- Prometheus metrics drive the continuous verification step in the backend deployment
- Architecture selection for Harness Cloud builds: Choose arm64 for Apple Silicon (M1/M2/M3) or amd64 for Intel

## Changes from Instruqt Version

This repository was originally created for Instruqt-based workshops. Key differences for local/partner use:

- **Removed**: Instruqt-specific connector named `instruqt_k8` → Renamed to `workshop_k8s` for local K8s
- **Removed**: Instruqt sandbox URLs in compile template → Changed to `http://localhost:8000`
- **Removed**: Instruqt variable references like `<+variable.sandbox_id>` → Simplified for local use
- **Added**: Platform-specific Kubernetes requirements (Colima for Apple Silicon, minikube for Windows)
- **Added**: OS and architecture detection in start-demo.sh
- **Changed**: Apple Silicon Colima runs native arm64 by default (`--colima-arch native|amd64`; choice saved as `COLIMA_ARCH_MODE`); architecture verified from the Docker daemon
- **Added**: Instructions for Mac/Linux PAT export
- **Added**: ngrok option for exposing Prometheus
- **Added**: Git credential setup for Harness Code Repository
- **Added**: Colima as primary option for macOS (especially Apple Silicon)
- **Added**: Rancher Desktop and Docker Desktop as alternatives
- **Clarified**: All resources go into a dedicated demo project for proper segregation
- **Added**: Customizable project name (prompted during start-demo.sh, with reserved word validation and existence check)
- **Added**: OpenTofu support as alternative to Terraform (scripts auto-detect and prompt if both are installed)
- **Added**: Multi-arch (amd64 + arm64) image builds with docker buildx
- **Added**: Automatic project-scoped Harness delegate install via Helm (`--skip-delegate` to skip)
- **Added**: Participant IDs for sharing one Harness project (`--participant <id>`); existing projects are imported, not recreated
- **Added**: Pre-flight checks before Terraform (token, account, org, permissions, participant collision; `DEMO_SKIP_PREFLIGHT=true` to bypass)
- **Changed**: stop-demo.sh never deletes a pre-existing or shared project; uses `HARNESS_ORG_ID`
- **Changed**: Docs site deploys on every run and picks up rebuilt `docs-latest`
- **Added**: Shared helper library `scripts/demo-lib.sh` (bash 3.2 compatible)
