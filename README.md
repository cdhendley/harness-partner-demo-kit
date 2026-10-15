# Harness Partner Demo Kit
## Partner Technical Sales Enablement Training
Demo Kit for Partner SE Enablement.

## Video
Can watch [this video](https://www.youtube.com/watch?v=zDi5Nrj6_I4) that is the overall goal and how to execute this Partner Demo Kit. 

## Overview
This repository is your complete training environment for mastering Harness demonstrations and sales enablement. Designed for both **potential partners** evaluating Harness partnership opportunities and **current partners** seeking sales engineering enablement training, this kit provides everything needed to deliver compelling Harness.io demonstrations using local resources, without requiring complex cloud infrastructure or specialized environments.

Built from our Unscripted conference workshop materials, this hands-on training culminates in a **customer pitch recording** where you demonstrate your ability to sell Harness to prospective clients.

All demo resources are created in a dedicated Harness project (default: **"Base Demo"**, customizable during setup) to keep demo activities segregated from other projects. Please note that if you using a partner licensed Harness instance, it will be important to name your project something other than the default as other colleagues may have already created a project named "Base Demo".

## Training Objectives

After completing this training, you will be able to:

✅ **Independently execute a complete Harness demonstration**
✅ **Implement a Harness demo environment** with version-controlled sample applications and pipelines
✅ **Construct customer-specific demonstrations** by mapping appropriate Harness features to identified pain points and creating relevant proof-of-concept environments

## Key Training Takeaways
- **Harness Skills**: Hands-on experience with CI/CD, Code Repository, Continuous Verification, and Security Testing
- **Harness Home Lab**: Your own local demonstration environment ready for customer presentations

## Training Path

This training consists of four progressive sections:

1. **[3-Minute Guide to Partner Technical Sales Training](#quick-start-guide)** - Get started quickly with automated setup
2. **[Hands-On Lab: Navigate the {Unscripted} Demo Track](#step-9-run-the-demo)** - Complete the guided demo labs
3. **[Infrastructure Setup: Building Your Harness Home Lab](#manual-setup)** - Deep dive into manual configuration
4. **[Final: Create and Submit Your Custom Demo Recording](#next-steps)** - Demonstrate your mastery

**Next Steps**: After completing the training, you'll have a fully functional Harness demo environment and the skills to customize demonstrations for customer engagements.

---

## Key Benefits
- **Minimal Prerequisites**: Runs on standard developer workstation using common tools
- **Self-Contained**: All necessary components included (Terraform configs, sample application code)
- **Customizable**: Use as a foundation for building customer-specific demonstrations
- **Field-Tested**: Based on materials from Harness Unscripted workshops
- **Project Segregation**: All resources created in a dedicated project (customizable name)

## What This Demo Showcases

1. **Code Repository Secret Scanning** - Block sensitive data from being committed
2. **CI Pipeline with Test Intelligence** - Automated testing and Docker image builds (**Harness Cloud**)
3. **Continuous Deployment** - Rolling and canary deployment strategies (local Kubernetes)
4. **Continuous Verification** - Automated deployment validation using Prometheus metrics
5. **Security Testing** - Available with licensed partner organization
6. **Policy Enforcement (OPA)** - Available with licensed partner organization

## Architecture Overview

![Harness Partner Demo Kit Architecture](markdown/images/kit-architecture.jpg)

The demo kit consists of:
- **Harness Manager (SaaS)** - CI/CD pipelines, connectors, and built-in features (Harness Cloud, Code Repository, Artifact Registry)
- **Local Machine** - Kubernetes cluster (Colima/Rancher/minikube/Docker Desktop) running the delegate, lab documentation, and demo applications
- **Docker Hub** - Container image storage with authentication via Harness Platform
- **Local Browser** - Access documentation at localhost:30001 and the demo app at localhost:8080

## Infrastructure Requirements

- **CI Builds**: Harness Cloud (requires credit card for account verification - free tier available)
- **CD Deployments**: Local Kubernetes (Colima for Apple Silicon, minikube/Docker Desktop/Rancher Desktop for others)

## Prerequisites

### Required Tools
- **Git**: Version control
- **Docker**: Container runtime ([Docker Desktop](https://www.docker.com/products/docker-desktop) or Docker Engine)
- **Kubernetes** (platform-specific):
  - **macOS (Apple Silicon M1/M2/M3/M4)**: [Colima](https://github.com/abiosoft/colima) (**REQUIRED**), running a **native arm64 VM by default**
    ```bash
    brew install colima docker kubectl
    colima start --vm-type=vz --vz-rosetta --arch aarch64 --cpu 4 --memory 8 --kubernetes --runtime docker
    ```
    Note: The native VM uses Apple's Virtualization.framework and is fast; amd64-only container images still run inside it via Rosetta. An amd64-emulated VM is available with `./start-demo.sh --colima-arch amd64` (also needs `brew install qemu lima-additional-guestagents`), but on Apple Silicon `--arch x86_64` runs a qemu software-emulated VM that is very slow and can be unstable — native is recommended. The `start-demo.sh` script will detect missing dependencies and offer to install them automatically.
  - **macOS (Intel)**: Choose one - [minikube](https://minikube.sigs.k8s.io/docs/start/), [Colima](https://github.com/abiosoft/colima), [Docker Desktop](https://www.docker.com/products/docker-desktop), or [Rancher Desktop](https://rancherdesktop.io/)
  - **Windows**: [minikube](https://minikube.sigs.k8s.io/docs/start/) (recommended), [Docker Desktop](https://www.docker.com/products/docker-desktop), or [Rancher Desktop](https://rancherdesktop.io/)
  - **Linux**: [minikube](https://minikube.sigs.k8s.io/docs/start/) or your preferred K8s distribution
- **Minimum Cluster Resources**: 4 CPU cores and 8GB memory
  - The `start-demo.sh` script validates cluster resources and provides remediation guidance if insufficient
- **kubectl**: Kubernetes CLI (usually included with above tools)
- **Helm**: Kubernetes package manager (**required** — `start-demo.sh` uses it to install the Harness delegate)
- **Docker buildx plugin**: Used to build multi-architecture images. Docker Desktop includes it; Homebrew's `docker` CLI does not:
  ```bash
  brew install docker-buildx
  mkdir -p ~/.docker/cli-plugins && ln -sfn "$(brew --prefix)/opt/docker-buildx/bin/docker-buildx" ~/.docker/cli-plugins/docker-buildx
  ```
  `start-demo.sh` offers to do this for you. Without buildx, `docker build` falls back to the deprecated legacy builder (single architecture only).
- **Terraform**: Infrastructure as Code tool (v1.0+)
- **Node.js & npm**: For frontend application (Node 20+)
- **Python**: For backend application (Python 3.8+)

### Required Accounts
- **Harness Account**: Sign up at [app.harness.io](https://app.harness.io)
  - Enable modules: CI (Continuous Integration), CD (Continuous Delivery), Code Repository
  - **Important**: Harness Cloud requires credit card verification (free tier available)
  - Add credit card in Account Settings > Billing to enable Harness Cloud for CI builds
  - **Harness API token (required for setup and cleanup)** — create before running `start-demo.sh`:
    1. Click your profile (bottom-left) → **My API Keys & Tokens**
    2. Create an API key if needed (**+ API Key**), e.g. `partner-kit-key`
    3. Click **+ Token** on that key — **an API key alone is not enough**; you need a token under it
    4. Set permissions to **All resources / All scopes** (or Admin/API access)
    5. Copy the token immediately — it starts with `pat.` and is shown only once
    6. Paste it when `start-demo.sh` prompts, or set `export DEMO_BASE_PAT="pat.xxx"`
  - **Updating your token**: If cleanup or Terraform fails with `401 Unauthorized`, generate a new **+ Token** and re-run with `export DEMO_BASE_PAT="pat.xxx"` or delete `.demo-config` to re-enter credentials
- **Docker Hub Account**: Sign up at [hub.docker.com](https://hub.docker.com)
  - Create a repository named `harness-demo`
  - Generate a Personal Access Token (Settings > Security > Personal Access Tokens)

### System Requirements

#### Supported Operating Systems

| OS | Version | Architecture | Kubernetes Option | Notes |
|----|---------|--------------|-------------------|-------|
| **macOS** | 12.0+ (Monterey) | Apple Silicon (M1/M2/M3/M4) | Colima (**required**) | Native arm64 VM by default; amd64 images run via Rosetta |
| **macOS** | 12.0+ (Monterey) | Intel | Colima, minikube, Docker Desktop, Rancher Desktop | Any K8s option works |
| **Linux** | Ubuntu 20.04+, Debian 11+, Fedora 36+ | x86_64 | minikube, Docker Desktop, Rancher Desktop | Native AMD64, no emulation needed |
| **Windows** | 10 (Build 19041+), 11 | x86_64 | minikube, Docker Desktop, Rancher Desktop | Requires WSL2 or Git Bash for scripts |

#### Hardware Requirements

| Resource | Minimum | Recommended | Notes |
|----------|---------|-------------|-------|
| **CPU** | 4 cores | 6+ cores | Required for Kubernetes cluster + builds |
| **RAM** | 8 GB | 16 GB | K8s cluster needs 4-8GB allocation |
| **Disk** | 20 GB free | 40 GB free | Docker images + K8s storage |

#### Platform-Specific Notes

**🍎 Apple Silicon (M1/M2/M3/M4):**
- Colima is **required**; `start-demo.sh` asks which VM architecture to use (default: **native arm64**) and remembers the choice (`COLIMA_ARCH_MODE` in `.demo-config`)
- Native mode: `colima start --vm-type=vz --vz-rosetta --arch aarch64 ...` — fast, and amd64-only images still run via Rosetta
- amd64 mode (`--colima-arch amd64`): a qemu software-emulated x86 VM — very slow and can be unstable; needs `qemu` and `lima-additional-guestagents`
- The script checks the Docker daemon's real architecture (`docker info --format '{{.Architecture}}'`), not Colima's config
- **Switching architectures requires deleting Colima's data disk**: `colima delete --data` (plain `colima delete` keeps it, and the old cluster's data breaks Kubernetes on the new VM)
- Images are built for both linux/amd64 and linux/arm64, so the same tags work on Harness Cloud and on Apple Silicon clusters

**🐧 Linux:**
- Any modern distribution with Docker support works
- minikube is the simplest option for most users
- Ensure your user is in the `docker` group: `sudo usermod -aG docker $USER`

**🪟 Windows:**
- WSL2 or Git Bash required to run the setup scripts (bash)
- Docker Desktop with WSL2 backend recommended
- See "Windows Users - Important Setup Notes" below for detailed setup

### Windows Users - Important Setup Notes

The automation scripts (`start-demo.sh` and `stop-demo.sh`) are bash scripts that require a bash-compatible environment on Windows. You have two options:

**Option 1: Git Bash (Recommended for Simplicity)**
- Install [Git for Windows](https://git-scm.com/download/win) which includes Git Bash
- Install Docker Desktop, kubectl, helm, and Terraform **in Windows** (not WSL)
- Run all commands in Git Bash terminal
- Docker Desktop's Kubernetes integration works seamlessly
- ✅ **Pros**: Simpler setup, native Windows Docker performance
- ⚠️ **Note**: Some Unix commands may have limited functionality

**Option 2: WSL2 (Recommended for Advanced Users)**
- Install [Windows Subsystem for Linux 2 (WSL2)](https://docs.microsoft.com/en-us/windows/wsl/install)
- Install Docker Desktop for Windows with WSL2 integration enabled
- Install kubectl, helm, and Terraform **inside WSL** using Linux package managers
- Run all commands in WSL terminal (Ubuntu, Debian, etc.)
- ✅ **Pros**: Full Linux compatibility, better for complex workflows
- ⚠️ **Networking**: WSL2 localhost forwarding handles port access automatically
- ⚠️ **Paths**: Use Linux paths (`/home/user/`) not Windows paths (`C:\Users\`)

**Kubernetes Options for Windows:**
- **minikube** (recommended by the script) - Works with both Git Bash and WSL2
- **Docker Desktop** - Enable Kubernetes in settings (Settings > Kubernetes > Enable Kubernetes)
- **Rancher Desktop** - Alternative to Docker Desktop with built-in Kubernetes

**Verification:**
After choosing your approach, verify your bash environment works:
```bash
# In Git Bash or WSL terminal
bash --version    # Should show bash version
docker --version  # Should show Docker version
kubectl version   # Should show kubectl version
```

## Quick Start Guide

### Step 1: Clone the Repository

```bash
# Clone this repository
git clone https://github.com/harness-community/partner-demo-kit.git
cd partner-demo-kit
```

**Recommended Location**: Save in an easily accessible location like:
- `~/projects/partner-demo-kit`
- `~/Documents/partner-demo-kit`

## Automated Setup (Recommended)

For a faster setup experience, use the provided automation scripts:

### Quick Start with Scripts

```bash
# Make scripts executable (first time only)
chmod +x start-demo.sh stop-demo.sh

# Start all local infrastructure
./start-demo.sh
```

### Demo Access URLs

Once the startup script completes, access the demo at these URLs:

| Service | URL | Description |
|---------|-----|-------------|
| **Lab Documentation** | http://localhost:30001 | Interactive lab guides for the demo walkthrough |
| **Demo Application** | http://localhost:8080 | Frontend web application (after deployment) |
| **Harness UI** | https://app.harness.io | Harness platform - select your demo project |

**Recommended Setup**: Use Chrome's **split tab view** (or two browser windows side-by-side) with:
- **Left side**: Harness UI at https://app.harness.io
- **Right side**: Lab documentation at http://localhost:30001

This allows you to follow the lab instructions while working in the Harness platform without switching tabs.

![Chrome Split Tab View - Harness UI and Lab Documentation side by side](markdown/images/2026-01-09_13-43-59.jpg)

> **Note for minikube users**: Run `minikube tunnel` in a separate terminal to access services at localhost.

### What the Startup Script Does

The `start-demo.sh` script automates the **complete demo setup** from local infrastructure to Harness resources:

**1. Prerequisites Check**
- Verifies Docker, kubectl, helm, Terraform, and other required tools are installed
- Checks for the Docker buildx plugin (offers to install/link it)
- Checks that Docker daemon is running

**2. Platform & Kubernetes Detection**
- Detects your operating system and architecture (macOS/Windows/Linux, ARM64/AMD64)
- Validates Kubernetes tool based on platform:
  - Apple Silicon Macs: Requires Colima; prompts for native arm64 (default) or amd64 emulation
  - Windows: Recommends minikube (allows Docker Desktop/Rancher Desktop)
  - Other platforms: Flexible (minikube, Colima, Docker Desktop, Rancher Desktop)
- Automatically starts Colima/minikube if needed
- Verifies the Docker daemon's actual architecture matches the chosen Colima mode
- **Validates cluster resources** (minimum 4 CPU cores, 8GB memory) with remediation guidance

**3. Prometheus Deployment** (Background)
- Creates monitoring namespace if it doesn't exist
- **Deploys Prometheus in background** (non-blocking - runs while Docker builds)
- Verifies Prometheus status at end of script

**4. Docker Hub Authentication** (Smart Detection)
- **If already logged in** (via Docker Desktop): Uses existing credentials automatically
- **If not logged in**: Checks for saved username in these locations (in order):
  1. Local `.demo-config` file (from previous runs)
  2. `kit/se-parms.tfvars` (Terraform configuration)
  3. Interactive prompt (if not found)
- Saves your username to `.demo-config` for future runs
- Prompts for login with helpful instructions about using a Personal Access Token (PAT)

**5. Docker Image Builds** (Parallel!)
- **Builds all three images simultaneously** (backend, test, docs) in parallel
- Uses docker buildx (BuildKit) to build **linux/amd64 and linux/arm64** under the same tag, so images work on Harness Cloud (amd64) and Apple Silicon clusters
- Progress tracking shows status of each build in real-time
- Pushes to your Docker Hub repository
- Provides clear error messages if build or push fails
- **Saves 2-4 minutes** vs sequential builds

**6. Harness Configuration & IaC Provisioning** (Automated!)
- **Smart credential collection**: Reuses values from previous runs or prompts for:
  - Harness Account ID (from URL when viewing your profile)
  - Harness Personal Access Token (PAT)
  - Docker Hub password/PAT (if not already logged in)
- **Automatic configuration**: Updates `kit/se-parms.tfvars` with your values
- **Pre-flight checks** before Terraform: token shape (`pat.<account>.<id>.<secret>` — an API key alone is not a token), token account matches your Account ID, org exists, permissions (project-create for a new project; project-scoped edit permissions for an existing one), and participant-ID collisions. Bypass with `DEMO_SKIP_PREFLIGHT=true`
- **IaC execution**: Runs Terraform init, plan, and apply automatically
- **Idempotent**: Skips if state file already exists
- **Creates all Harness resources**: Project (or imports an existing one), connectors, environments, services, monitored services, code repository, etc.

**7. Harness Delegate Installation** (Automated!)
- Fetches the project's delegate token (`default_token`), the manager endpoint, and the latest delegate image from the Harness API
- Installs the delegate with Helm at **project scope** into the `harness-delegate-ng` namespace, named to match the connectors: `local-k8s-delegate`, or `<participant>-k8s-delegate` when a participant ID is set
- Waits until Harness shows it connected. Skip with `--skip-delegate`; the manual fallback is in Lab 0

**8. Lab Documentation**
- Deploys the docs site on every run (also with `--skip-docker-build`, using the existing docs image) at http://localhost:30001
- Uses `imagePullPolicy: Always` plus a rollout restart so a rebuilt `docs-latest` is picked up

**9. Status Display**
- Shows cluster status, Prometheus deployment, and Terraform results
- Provides clear next steps based on what was configured

### Script Options

```bash
# Skip Docker image build (if you already have the backend image)
./start-demo.sh --skip-docker-build

# Skip Terraform/Harness setup (useful for infrastructure-only testing)
./start-demo.sh --skip-terraform

# Skip the automatic Harness delegate install
./start-demo.sh --skip-delegate

# Set a participant ID (for sharing one Harness project - see below)
./start-demo.sh --participant alice

# Apple Silicon: choose the Colima VM architecture (default: native)
./start-demo.sh --colima-arch native
./start-demo.sh --colima-arch amd64

# Combine options
./start-demo.sh --skip-docker-build --skip-terraform
```

Shared helper functions live in [scripts/demo-lib.sh](scripts/demo-lib.sh) (bash 3.2 compatible, so it runs with the macOS system bash).

### Sharing One Harness Project

Several people can work in **one** Harness project without colliding:
- Each person picks a **participant ID**: 1-20 lowercase letters/digits, starting with a letter (prompted, or `--participant <id>`; saved as `PARTICIPANT_ID` in `.demo-config`)
- Terraform appends `_<id>` to identifiers and ` <id>` to names of everything the kit creates — e.g. repository `partner_demo_kit_<id>`, connectors `workshop_k8s_<id>` / `workshopdocker_<id>` / `prometheus_<id>`, environments, infrastructure, backend service, template, and monitored services
- Your delegate becomes `<id>-k8s-delegate`, and the lab guides at http://localhost:30001 are personalized with your names
- Leave the ID empty to use the original single-user names
- To reuse an existing project, enter its **exact display name** when prompted; it is imported into Terraform, never recreated
- `stop-demo.sh` never deletes a shared or pre-existing project — it only destroys your own resources

### First Run vs Subsequent Runs

**First Run (Complete Setup):**
- Prompts for:
  - **Project name** (default: "Base Demo") - customizable name for your Harness project
  - Docker Hub username (unless already logged in via Docker Desktop)
  - Docker Hub password/PAT
  - Harness Account ID
  - Harness Personal Access Token (PAT)
- Validates project name doesn't use reserved words or conflict with existing projects
- Saves all credentials to `.demo-config` for future runs
- Creates Harness resources via Terraform
- Takes ~6-10 minutes total (parallel Docker builds + IaC provisioning)

**Subsequent Runs:**
- Detects existing state file and skips Harness resource creation
- Reuses saved credentials from `.demo-config`
- Only prompts if saved credentials are missing or invalid
- Takes ~2-3 minutes for infrastructure verification

### Credential Management

The script stores credentials in `.demo-config` (git-ignored) for convenience:
- **Project name & identifier** - Your custom Harness project name
- **Docker Hub username** - Reused for subsequent runs
- **Harness Account ID** - Saved to avoid re-entering
- **Harness PAT** - Cached for convenience (can also use `DEMO_BASE_PAT` env var)
- **Docker Hub password/PAT** - Saved for Terraform configuration

**Security Notes:**
- `.demo-config` is automatically excluded from Git via `.gitignore`
- Use Personal Access Tokens (PATs) instead of passwords when possible
- Docker Hub PAT: https://hub.docker.com/settings/security
- Harness PAT: Profile > My API Keys & Tokens

**Using Docker Desktop:**
- If you log in to Docker Hub through Docker Desktop, the script detects this and reuses your session
- You won't be prompted for Docker credentials during the build phase

### When Finished with the Demo

```bash
# Interactive cleanup menu (RECOMMENDED)
./stop-demo.sh
```

**Interactive Cleanup Menu:**

When you run `./stop-demo.sh` without arguments, you'll see a user-friendly menu with the following options:

1. **Stop K8s deployments only** (Recommended - preserves Harness resources)
   - Removes frontend and backend deployments/services
   - Keeps Harness project, Prometheus, and cluster running
   - Easy to restart demo later with: `./start-demo.sh --skip-terraform`

2. **Stop K8s deployments + Delete Prometheus**
   - Same as option 1, but also removes Prometheus monitoring

3. **Stop K8s deployments + Stop cluster**
   - Stops local deployments and shuts down Colima/minikube
   - Preserves Harness resources for next time

4. **Full cleanup (delete all Harness resources)**
   - Deletes your Harness demo project — **unless** it was pre-existing or shared (`PROJECT_PREEXISTING=true` or a `PARTICIPANT_ID` set); then the project is removed from Terraform state before `destroy`, so only your own resources are destroyed
   - Uses your configured org (`HARNESS_ORG_ID`)
   - Deletes Docker Hub repository
   - Removes Prometheus
   - Keeps cluster running and config files

5. **Complete cleanup (everything including cluster)**
   - Same as option 4, but also stops the cluster
   - Option to delete Colima VM and its data disk for a fresh start (`colima delete -f --data`)

6. **Custom cleanup options**
   - Choose exactly what to cleanup

0. **Exit without doing anything**

**Command-Line Flags (Skip Interactive Menu):**

For automated/scripted use:
- `./stop-demo.sh --delete-prometheus` - Also remove Prometheus monitoring
- `./stop-demo.sh --stop-cluster` - Also stop Kubernetes cluster (Colima or minikube)
- `./stop-demo.sh --delete-harness-project` - Delete your Harness demo project via API
- `./stop-demo.sh --delete-docker-repo` - Delete Docker Hub harness-demo repository via API
- `./stop-demo.sh --delete-config-files` - Delete .demo-config, se-parms.tfvars, and IaC state files
- `./stop-demo.sh --full-cleanup` - Complete cleanup (all of the above except config files)
- `./stop-demo.sh --no-interactive` - Skip menu, use minimal cleanup

**Recommended Workflow:**

After running the demo, use the default interactive menu (option 1) to preserve Harness resources:
```bash
./stop-demo.sh  # Choose option 1 (default)
```

To restart the demo later without recreating Harness resources:
```bash
./start-demo.sh --skip-terraform
```

> **Next Steps**: After running `start-demo.sh` successfully:
> 1. Navigate to [app.harness.io](https://app.harness.io) and select your demo project
> 2. Configure Harness Code Repository (see Step 8 in Manual Setup below)
> 3. Follow the lab guides in the [markdown/](markdown/) directory

---

## Manual Setup

If you prefer manual control or need to troubleshoot, follow these detailed steps:

### Step 2: Set Up Kubernetes

**Option A: Rancher Desktop (Recommended)**
1. Download and install [Rancher Desktop](https://rancherdesktop.io/)
2. Open Rancher Desktop preferences
3. Enable Kubernetes
4. Wait for Kubernetes to start (green indicator)
5. Services will be automatically accessible at `localhost`

**Option B: minikube**
```bash
# Start minikube
minikube start

# Enable metrics-server addon
minikube addons enable metrics-server

# In a separate terminal, run minikube tunnel (required for service access)
# Keep this running during the demo
minikube tunnel
```

### Step 3: Deploy Prometheus (for Continuous Verification)

```bash
# Navigate to the kit directory
cd kit

# Create monitoring namespace
kubectl create namespace monitoring

# Deploy Prometheus
kubectl -n monitoring apply -f ./prometheus.yml

# Verify Prometheus is running
kubectl get pods -n monitoring
```

**Optional - Expose Prometheus with ngrok** (if Harness delegate can't reach cluster-local URL):
```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090

# In another terminal, expose via ngrok
ngrok http 9090
# Copy the HTTPS URL (e.g., https://abc123.ngrok.io)
# You'll use this URL in the Terraform configuration later
```

### Step 4: Build and Push Docker Images

> **✅ Automated**: The [start-demo.sh](start-demo.sh) script builds all images with docker buildx for **linux/amd64 and linux/arm64** under the same tag and pushes them. You can skip this step if using the automated script.

> **ℹ️ Manual Builds**: Build multi-arch images so the same tags work on Harness Cloud (amd64) and on Apple Silicon clusters. This requires the buildx plugin (see Prerequisites). An amd64-only image still runs on a native arm64 Colima VM via Rosetta, but multi-arch is preferred.

```bash
# Log in and create a multi-arch builder (once)
docker login -u dockerhubaccountid
docker buildx create --name harness-demo-builder --driver docker-container
```

#### Backend Application Image

```bash
# Replace "dockerhubaccountid" with YOUR Docker Hub username (run from the repo root)
docker buildx build --builder harness-demo-builder --platform linux/amd64,linux/arm64 \
  -t dockerhubaccountid/harness-demo:backend-latest --push backend
```

#### Test Image (for CI Pipeline)

```bash
docker buildx build --builder harness-demo-builder --platform linux/amd64,linux/arm64 \
  -t dockerhubaccountid/harness-demo:test-latest --push python-tests
```

**Important Docker Image Tags:**
- `backend-latest` - Django backend application (production runtime)
- `test-latest` - Python + pytest environment (CI testing only)
- `demo-base-<tag>` - Frontend Angular application

**Critical**: Remember to replace `dockerhubaccountid` in:
1. The Docker build/push commands above
2. [kit/main.tf](kit/main.tf) line ~300: `imagePath: dockerhubaccountid/harness-demo`
3. Your Harness pipeline's Test Intelligence step to use `test-latest` image

### Step 5: Configure Harness Account

1. **Log in to Harness**: [app.harness.io](https://app.harness.io)

2. **Enable Required Modules**:
   - Navigate to Account Settings > Subscriptions
   - Enable: **CI**, **CD**, and **Code Repository**

3. **Harness Delegate**:
   - `start-demo.sh` **installs the delegate automatically** with Helm at **project scope**, named `local-k8s-delegate` (or `<participant>-k8s-delegate`), and waits for it to connect
   - Manual fallback (only if the script couldn't, or you used `--skip-delegate`): see **Lab 0** ([markdown/0-login.md](markdown/0-login.md)) — in **Project Settings > Delegates > New Delegate > Kubernetes > Helm Chart**, run all three commands, and set both the Helm release name and `--set delegateName=` to your delegate name so the connectors find it

4. **Get Your Harness Account ID**:
   - Click on your profile (top right)
   - Your account ID is in the URL (e.g., `VEuU4vZ6QmSJZcgvnccqYQ`)

5. **Create a Harness API Token**:
   - Go to your profile > My API Keys & Tokens
   - Create a new token with appropriate permissions
   - Save this token securely

### Step 6: Configure IaC Variables

> **Note**: The automated `start-demo.sh` script handles this step automatically. Only follow these manual steps if you skipped the automated setup or used `--skip-terraform`.

```bash
# Navigate to kit directory
cd ../kit

# Edit se-parms.tfvars
# Replace the placeholder values with your actual values:
```

**se-parms.tfvars**:
```hcl
account_id = "your-harness-account-id"
docker_username = "your-dockerhub-username"
DOCKER_PAT = "your-dockerhub-pat"
project_name = "Base Demo"
project_identifier = "Base_Demo"
```

**Important**: Also update `dockerhubaccountid` in [kit/main.tf](kit/main.tf) (line ~300) with your Docker Hub username.

### Step 7: Run Terraform to Create Harness Resources

> **Note**: The automated `start-demo.sh` script handles this step automatically. Only follow these manual steps if you skipped the automated setup or used `--skip-terraform`.

```bash
# Set your Harness API token as an environment variable (Mac/Linux)
export DEMO_BASE_PAT="pat.your-actual-token-here"

# Verify it's set
echo $DEMO_BASE_PAT

# Initialize Terraform
terraform init

# Preview the changes
terraform plan -var="pat=$DEMO_BASE_PAT" -var-file="se-parms.tfvars" -out=plan.tfplan

# Apply the configuration
terraform apply -auto-approve plan.tfplan
```

**What Gets Created** (all in your demo project; with a participant ID, identifiers get `_<id>` and names get ` <id>`):
- Harness project (your custom name, default: "Base Demo"; an existing project is imported, not recreated)
- Kubernetes connector (workshop_k8s)
- Docker Hub connector (workshopdocker)
- Prometheus connector
- Docker credentials (secrets)
- "Compile Application" template
- Dev and Prod environments
- K8s Dev infrastructure
- Backend service
- Monitored services for continuous verification
- Code repository (partner_demo_kit) mirrored from GitHub

### Step 8: Configure Harness Code Repository

1. Navigate to Harness UI > **Code Repository** module
2. Select your demo project
3. Click on **"partner_demo_kit"** repository
4. Click **"Clone"** (top right) > **"+Generate Clone Credential"**
5. Save the generated username and token
6. Enable **Secret Scanning**:
   - Go to Manage Repository > Security
   - Turn on "Secret Scanning"
   - Save

### Step 9: Run the Demo

Follow the step-by-step lab guides in the `markdown/` directory which walk through:

1. **Secret Scanning Demo**: Try to push a secret and see it blocked
2. **Build Pipeline**: Create CI pipeline with test intelligence
3. **Frontend Deployment**: Deploy frontend with rolling strategy
4. **Backend Deployment**: Deploy backend with canary strategy
5. **Continuous Verification**: Verify deployments using Prometheus metrics

**Access the Demo Application**:
- **Rancher Desktop**: http://localhost:8080 (automatic)
- **minikube**: http://localhost:8080 (requires `minikube tunnel` running)

## Directory Structure

```
.
├── README.md              # Complete setup and demo guide
├── CLAUDE.md              # Instructions for Claude Code AI assistant
├── start-demo.sh          # Automated startup script for local infrastructure
├── stop-demo.sh           # Automated shutdown script for cleanup
├── scripts/
│   └── demo-lib.sh        # Shared helpers (participant IDs, pre-flight, Colima, buildx, delegate)
├── kit/                   # Terraform Infrastructure as Code
│   ├── main.tf            # Main IaC configuration
│   ├── se-parms.tfvars    # Your configuration variables
│   └── prometheus.yml     # Prometheus deployment
├── backend/               # Django backend application
│   ├── Dockerfile
│   └── requirements.txt
├── frontend-app/          # Angular frontend application
│   └── harness-webapp/
│       ├── Dockerfile
│       └── package.json
├── harness-deploy/        # Kubernetes manifests
│   ├── backend/           # Backend K8s resources
│   └── frontend/          # Frontend K8s resources
├── python-tests/          # Test suites for CI demo
└── markdown/              # Step-by-step lab guides (0-7)
    ├── 0-login.md         # Getting started and verification
    ├── 1-coderepo.md      # Secret scanning demo
    ├── 2-build.md         # CI pipeline setup
    ├── 3-cd-frontend.md   # Frontend deployment
    ├── 4-cd-backend.md    # Backend canary deployment
    ├── 5-security.md      # Security testing (licensed only)
    ├── 6-cv.md            # Continuous verification
    └── 7-opa.md           # OPA policy enforcement (licensed only)
```

## Troubleshooting

### Common Issues

**Issue**: Terraform fails with authentication error (`401 Unauthorized` / `INVALID_TOKEN`)
- **Cause**: Missing, expired, or revoked Harness API token — or you created an API key but never clicked **+ Token** under it
- **Solution**:
  1. In Harness: Profile → **My API Keys & Tokens** → your key → **+ Token**
  2. Copy the new `pat.*` value (shown only once)
  3. Either export it: `export DEMO_BASE_PAT="pat.xxx"` and re-run the script
  4. Or delete `.demo-config` and run `./start-demo.sh` again to re-enter credentials
- **Note**: `start-demo.sh` and `stop-demo.sh` now validate cached tokens and will prompt for a fresh one if invalid

**Issue**: Cleanup says Harness project was deleted, but it still exists in the UI
- **Cause**: Usually an expired/invalid cached PAT in `.demo-config` — the old script reported intent, not actual success
- **Solution**:
  ```bash
  export DEMO_BASE_PAT="pat.your-new-token"
  ./stop-demo.sh --force-api-delete
  ```
  Or delete manually: Harness UI → Projects → your project → ⋮ → Delete Project

**Issue**: Terraform not found
- **Solution**: Install Terraform from https://www.terraform.io/downloads

**Issue**: Services not accessible at localhost:8080
- **Solution** (Colima): Services should be automatically accessible. If not, check that Colima is running with `colima status`
- **Solution** (minikube): Ensure `minikube tunnel` is running in a separate terminal
- **Solution** (Rancher Desktop): Check that Kubernetes is enabled in preferences

**Issue**: Colima fails to start (Apple Silicon)
- **Cause**: Missing dependencies — native mode needs `colima docker kubectl`; amd64 mode also needs `qemu` and `lima-additional-guestagents`
- **Solution**: Install the dependencies and start fresh (native, recommended):
  ```bash
  brew install colima docker kubectl
  colima delete --data -f
  colima start --vm-type=vz --vz-rosetta --arch aarch64 --cpu 4 --memory 8 --kubernetes --runtime docker
  ```
- Verify: `kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.architecture}'` should print `arm64`

**Issue**: Colima/Kubernetes is very slow or unstable (Apple Silicon)
- **Cause**: The VM was started with `--arch x86_64` (or `--colima-arch amd64`). On Apple Silicon that is a qemu software-emulated x86 VM, not Rosetta — it is very slow and can be unstable
- **Solution**: Switch to the native VM (`./start-demo.sh --colima-arch native`). amd64-only images still run inside it via Rosetta

**Issue**: Kubernetes broken after switching Colima architecture (native ↔ amd64)
- **Cause**: Plain `colima delete` keeps Colima's data disk; the old cluster's data breaks Kubernetes on the new VM
- **Solution**: Delete the data disk too, then start again:
  ```bash
  colima delete -f --data
  ./start-demo.sh
  ```

**Issue**: Colima fails during Kubernetes provisioning (k3s download error)
- **Symptoms**: Errors like:
  - `error provisioning kubernetes: error at 'downloading and installing'`
  - `resolve redirect failed` or `EOF` when downloading from `github.com/k3s-io/k3s`
- **Cause**: Transient network interruption, VPN/proxy interference, DNS issues, or stale Colima cache — not missing demo prerequisites
- **Solution** (try in order):
  1. **Retry with a clean reset** (fixes most cases):
     ```bash
     colima delete --data -f
     colima start --vm-type=vz --vz-rosetta --arch aarch64 --cpu 4 --memory 8 --kubernetes --runtime docker
     ```
  2. **Clear Colima cache** if retry alone fails:
     ```bash
     rm -rf ~/Library/Caches/colima/caches/*
     colima delete --data -f
     colima start --vm-type=vz --vz-rosetta --arch aarch64 --cpu 4 --memory 8 --kubernetes --runtime docker
     ```
  3. **Pin a k3s version** if the default keeps failing:
     ```bash
     colima start --vm-type=vz --vz-rosetta --arch aarch64 --cpu 4 --memory 8 --kubernetes --runtime docker --kubernetes-version="v1.34.1+k3s1"
     ```
  4. **Check network/DNS** — disable VPN, try a different network, or switch DNS to a public resolver (e.g. `1.1.1.1` / `8.8.8.8`)

**Issue**: Prometheus connector fails in Harness
- **Solution**: Use ngrok to expose Prometheus and update the connector URL to the ngrok HTTPS URL

**Issue**: Docker image push fails
- **Solution**: Verify you're logged in to Docker Hub: `docker login -u your-username`

**Issue**: Image pull error: "pull access denied for harness-demo"
- **Cause**: The placeholder `dockerhubaccountid` was not replaced with your actual Docker Hub username
- **Solution**:
  1. Update [kit/main.tf](kit/main.tf) line ~300 to use your Docker Hub username: `imagePath: YOUR-USERNAME/harness-demo`
  2. In Harness UI, verify the service artifact configuration shows `YOUR-USERNAME/harness-demo:backend-latest`
  3. Re-run the deployment pipeline

**Issue**: Test Intelligence step fails with "pytest: not found"
- **Cause**: The Test Intelligence step is not using the correct container image
- **Solution**:
  1. Build and push the multi-arch test image (see Step 4):
     ```bash
     docker buildx build --builder harness-demo-builder --platform linux/amd64,linux/arm64 -t YOUR-USERNAME/harness-demo:test-latest --push python-tests
     ```
  2. In Harness pipeline, update Test Intelligence step to use image: `YOUR-USERNAME/harness-demo:test-latest`
  3. Do NOT use `backend-latest` for testing - use `test-latest`

**Issue**: Test Intelligence fails with "exec /usr/bin/sh: exec format error"
- **Cause**: Docker image was built for a single architecture (e.g. arm64 only) that doesn't match Harness Cloud (amd64) — typically a legacy-builder `docker build` on Apple Silicon without buildx
- **Solution**: Install the buildx plugin (see Prerequisites) and rebuild multi-arch:
  ```bash
  docker buildx build --builder harness-demo-builder --platform linux/amd64,linux/arm64 -t YOUR-USERNAME/harness-demo:test-latest --push python-tests
  ```

**Issue**: Pipeline setup or build infrastructure questions
- **Solution**: The demo uses **Harness Cloud for CI builds** (test and compile steps)
- Requires: Harness account with credit card verification (free tier available)
- In pipeline infrastructure, select:
  - Platform: "Harness Cloud"
  - OS: "Linux"
  - Architecture: "Amd64"

**Issue**: Harness delegate not connecting
- **Solution**: Check delegate pod status: `kubectl get pods -n harness-delegate-ng`
- The connectors expect the delegate name `local-k8s-delegate` (or `<participant>-k8s-delegate`); re-run `./start-demo.sh --skip-docker-build --skip-terraform` to reinstall it, or follow the manual steps in Lab 0

### Verifying Your Setup

```bash
# Check Kubernetes is running
kubectl cluster-info

# Check Prometheus is deployed
kubectl get pods -n monitoring

# Check deployments (after running demo)
kubectl get pods -A | grep deployment
kubectl get services -A | grep svc

# Check Harness delegate
kubectl get pods -n harness-delegate-ng
```

## Resetting the Demo

To start fresh and reset everything, you have several options:

### Option 1: Complete Automated Cleanup (Recommended)

```bash
# Clean up EVERYTHING (Harness project, Docker repo, local files, K8s resources)
./stop-demo.sh --full-cleanup
```

This single command will:
- Delete your Harness demo project via API (with confirmation prompt) — a pre-existing or shared project is never deleted; only your own resources are destroyed
- Delete the Docker Hub `harness-demo` repository via API (with confirmation prompt)
- Delete configuration files (.demo-config, se-parms.tfvars, state files)
- Remove Kubernetes deployments (frontend/backend)
- Remove Prometheus monitoring
- Stop Kubernetes cluster (minikube only)

### Option 2: Selective Automated Cleanup

Choose specific cleanup operations:

```bash
# Clean up only cloud resources (Harness + Docker Hub)
./stop-demo.sh --delete-harness-project --delete-docker-repo

# Clean up cloud resources and local config (keeps K8s running)
./stop-demo.sh --delete-harness-project --delete-docker-repo --delete-config-files

# Clean up only local resources (keeps Harness project)
./stop-demo.sh --delete-prometheus --stop-cluster --delete-config-files
```

### Option 3: Manual Cleanup

**Step 1: Clean Kubernetes Resources**
```bash
# Delete deployed applications
kubectl delete deployment frontend-deployment --ignore-not-found=true
kubectl delete service web-frontend-svc --ignore-not-found=true
kubectl delete deployment backend-deployment --ignore-not-found=true
kubectl delete service web-backend-svc --ignore-not-found=true

# Delete Prometheus (optional)
kubectl delete -f kit/prometheus.yml -n monitoring --ignore-not-found=true
kubectl delete namespace monitoring --ignore-not-found=true
```

**Step 2: Delete Harness Resources**

> **Important**: Delete Harness resources through the UI **before** running `terraform destroy`. This ensures proper cleanup of all dependencies.

1. Navigate to Harness UI > **Code Repository** > Manage Repository
   - Delete **"partner_demo_kit"** repository
2. Navigate to **Projects**
   - Delete your demo project (this removes all project resources)

**Step 3: Clean IaC State**

After deleting Harness resources through the UI:

```bash
cd kit

# Option A: Destroy using Terraform (may have some errors - safe to ignore)
terraform destroy -var="pat=$DEMO_BASE_PAT" -var-file="se-parms.tfvars"

# Option B: Clean slate - remove all state files
git clean -dxf  # WARNING: Removes all untracked files including .tfstate files
```

> **Note**: The destroy command may show errors for resources already deleted through the Harness UI. This is expected and safe to ignore. The cleanup script handles this automatically.

**Step 4: Clean Docker Hub (Optional)**
- Navigate to Docker Hub
- Delete the **"harness-demo"** repository

**Step 5: Stop Kubernetes (Optional)**
```bash
# For minikube
minikube stop

# For Rancher Desktop - stop through the UI
```

## Next Steps

### What Happens After You Complete the Training

Once you've successfully completed the demo labs and built your Harness Home Lab, you're ready to:

1. **Create Your Custom Demo Recording**

   This is your final assessment - a customer pitch recording that demonstrates your mastery of Harness sales enablement. You'll create a 10-15 minute recording where you pitch Harness to a pretend client.

   **Recording Requirements:**
   - Choose a specific use case or industry vertical
   - Customize the demo to address relevant pain points for that vertical
   - Deliver a compelling sales pitch (not just a demo walkthrough)
   - Submit to your Harness Partner Manager for evaluation

   **Evaluation Rubric:**

   Your pitch will be evaluated on five key criteria:

   **1. Understanding of the Module**
   - Accurate description of Harness features and benefits
   - Clear explanation of how Harness addresses customer pain points
   - Technical accuracy and depth of knowledge

   **2. Articulation of Value Proposition**
   - Effective communication of Harness's unique differentiators
   - Ability to align Harness capabilities with specific customer needs
   - Clear ROI and business value messaging

   **3. Opportunity Identification**
   - Demonstration of how to spot potential use cases for Harness
   - Understanding of which customer scenarios are best suited for each module
   - Ability to qualify opportunities and map features to pain points

   **4. Presentation Skills**
   - Clear and confident delivery
   - Logical flow of information
   - Professional communication style
   - Engaging storytelling and customer-focused narrative

   **5. Customization and Internalization**
   - Evidence that you've made the pitch your own, not just repeating scripted content
   - Integration of training materials with your own insights and examples
   - Authenticity and personal style in delivery
   - Creative adaptation of demo scenarios to customer context

2. **Apply Your Skills**
   - Use this environment for customer proof-of-concepts
   - Adapt the demo for specific customer scenarios
   - Build additional demo scenarios using the same infrastructure

3. **Stay Current**
   - Join Harness partner community events and webinars
   - Access updated demo materials and best practices
   - Share your customizations and learnings with other partners

4. **Get Certified**
   - Complete Harness certification programs
   - Earn Harness professional badges
   - Advance your partner enablement journey

## Resources & Support

- **Lab Guides**: See [markdown/](markdown/) directory for step-by-step instructions
- **Harness Documentation**: [docs.harness.io](https://docs.harness.io)
- **Automation Scripts**: [start-demo.sh](start-demo.sh) and [stop-demo.sh](stop-demo.sh)

For questions or assistance:
- Contact your Harness Partner Manager
- Submit issues via [GitHub](https://github.com/harness-community/partner-demo-kit/issues)
- Join the Harness Partner Community

## Architecture Notes

- **Frontend**: Angular 17 application with Harness Feature Flags integration
- **Backend**: Django 5.0 REST API
- **Local Kubernetes**: Rancher Desktop (recommended) or minikube
- **Monitoring**: Prometheus for continuous verification metrics
- **CI/CD**: Harness Cloud for builds, local K8s for deployments
- **Image Storage**: Docker Hub

## Contributing

We welcome contributions and suggestions to improve this demo kit. Please submit pull requests or open issues for any enhancements.

---

*Note: This demo kit is maintained by Harness.io for partner use. While it's designed to be self-contained, partners are encouraged to customize and extend it based on specific customer needs.*
