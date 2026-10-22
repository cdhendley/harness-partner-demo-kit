# Harness Partner Demo Kit
## Partner Technical Sales Enablement Training
Demo Kit for Partner SE Enablement.

## Video
Can watch [this video](https://www.youtube.com/watch?v=zDi5Nrj6_I4) that is the overall goal and how to execute this Partner Demo Kit. 

## Overview
This repository is your complete training environment for mastering Harness demonstrations and sales enablement. Designed for both **potential partners** evaluating Harness partnership opportunities and **current partners** seeking sales engineering enablement training, this kit provides everything needed to deliver compelling Harness.io demonstrations using local resources, without requiring complex cloud infrastructure or specialized environments.

Built from our Unscripted conference workshop materials, this hands-on training culminates in a **customer pitch recording** where you demonstrate your ability to sell Harness to prospective clients.

All demo resources are created in one shared Harness project, **"Onboarding"**, which keeps demo activities segregated from other projects. Everyone works in that same project: setup asks each person for a short **name/ID** (e.g. `alex`) and adds it to everything it creates for them (`workshop_k8s_alex`, `alex-k8s-delegate`, ...), so nobody's resources collide. You need the **Project Admin** role on Onboarding; you do not need (and won't get) org-level rights.

**New here? Follow [HOWTO.md](HOWTO.md)** — the step-by-step setup checklist, including what to answer at each prompt and what to do if a run fails. This README is the full reference.

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
- **Project Segregation**: All resources live in the dedicated Onboarding project, tagged with each person's name/ID

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
    Note: The native VM uses Apple's Virtualization.framework and is fast; amd64-only container images still run inside it via Rosetta. `start-demo.sh` always uses the native VM on Apple Silicon (it doesn't ask), detects missing Colima dependencies and offers to install them with Homebrew. (An amd64-emulated VM exists only behind the `--colima-arch amd64` flag; on Apple Silicon that is qemu software emulation — very slow and can be unstable.)
  - **macOS (Intel)**: Choose one - [minikube](https://minikube.sigs.k8s.io/docs/start/), [Colima](https://github.com/abiosoft/colima), [Docker Desktop](https://www.docker.com/products/docker-desktop), or [Rancher Desktop](https://rancherdesktop.io/)
  - **Windows**: [minikube](https://minikube.sigs.k8s.io/docs/start/) (recommended), [Docker Desktop](https://www.docker.com/products/docker-desktop), or [Rancher Desktop](https://rancherdesktop.io/)
  - **Linux**: [minikube](https://minikube.sigs.k8s.io/docs/start/) or your preferred K8s distribution
- **Minimum Cluster Resources**: 4 CPU cores and 8GB memory
  - The `start-demo.sh` script validates cluster resources and provides remediation guidance if insufficient
- **kubectl**: Kubernetes CLI (usually included with above tools)
- **Helm**: Kubernetes package manager (**required** — `start-demo.sh` uses it to install the Harness delegate; it is only checked at that step, so install it up front)
- **Docker buildx plugin**: Used to build multi-architecture images. Docker Desktop includes it; Homebrew's `docker` CLI does not:
  ```bash
  brew install docker-buildx
  mkdir -p ~/.docker/cli-plugins && ln -sfn "$(brew --prefix)/opt/docker-buildx/bin/docker-buildx" ~/.docker/cli-plugins/docker-buildx
  ```
  `start-demo.sh` offers to do this for you. Without buildx, `docker build` falls back to the deprecated legacy builder (single architecture only).
- **Terraform**: Infrastructure as Code tool (v1.0+). OpenTofu works too; if both are installed the script asks which to use
- **Python 3, callable as `python3`**: **required** — the setup scripts use it to read Harness API responses (organization and project lists, delegate status), check tokens and personalize the lab guides. macOS and Linux have it; on Windows see the Windows notes below
- **curl**: used for all Harness and Docker Hub API calls (included with macOS, Linux and Git for Windows)
- **Node.js & npm** (Node 20+) and **Python 3.8+ with pip**: only for developing the frontend/backend apps locally — not needed to run the demo

### Required Accounts
- **Harness Account**: Sign up at [app.harness.io](https://app.harness.io)
  - Enable modules: CI (Continuous Integration), CD (Continuous Delivery), Code Repository
  - **Important**: Harness Cloud requires credit card verification (free tier available)
  - Add credit card in Account Settings > Billing to enable Harness Cloud for CI builds
  - **Access to the Onboarding project**: the **Project Admin** role on it. That is enough; org rights are not needed
  - **Harness API token (required for setup and cleanup)** — create before running `start-demo.sh`:
    1. If your login belongs to more than one Harness account, switch to the right account first — tokens only work in the account they were created in
    2. Click your profile (bottom-left) → **My API Keys & Tokens**
    3. Create an API key if needed (**+ API Key**), e.g. `partner-kit-key`
    4. Click **+ Token** on that key — **an API key alone is not enough**; you need a token under it
    5. Copy the token immediately — it starts with `pat.` and is shown only once
    6. Paste it when `start-demo.sh` asks. It is checked on the spot (an API key pasted by mistake gets its own message) and saved for later runs. `export DEMO_BASE_PAT="pat.xxx"` before running pre-answers the question
  - **Updating your token**: when the saved token stops working, `start-demo.sh` says so and asks for a new one; create a new **+ Token** and paste it
- **Docker Hub Account**: Sign up at [hub.docker.com](https://hub.docker.com)
  - Create a repository named `harness-demo`
  - Create a **Personal access token** (Account settings → Personal access tokens) with **Read & Write** access (add **Delete** if you want `stop-demo.sh` to be able to delete the repository). `start-demo.sh` asks for it once and checks it with Docker Hub. **Being logged in to Docker Desktop is not enough**: Harness's Docker connector (used by the Lab 2 pipeline to push images) and your cluster's image pulls need the token itself

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
- Colima is **required**; `start-demo.sh` always uses a **native arm64** VM (no question)
- Native mode: `colima start --vm-type=vz --vz-rosetta --arch aarch64 ...` — fast, and amd64-only images still run via Rosetta
- If an old x86_64 Colima VM is found (e.g. from an earlier version of this kit), the script offers to recreate it as native arm64
- amd64 mode exists only behind the `--colima-arch amd64` flag: a qemu software-emulated x86 VM — very slow and can be unstable; needs `qemu` and `lima-additional-guestagents`
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
- Install Docker Desktop, kubectl, helm, Terraform, minikube and Python 3 **in Windows** (not WSL) — see "Installing the tools" below
- Run all commands in Git Bash terminal
- Docker Desktop's Kubernetes integration works seamlessly
- ✅ **Pros**: Simpler setup, native Windows Docker performance
- ⚠️ **Note**: Some Unix commands may have limited functionality

**Option 2: WSL2 (Recommended for Advanced Users)**
- Install [Windows Subsystem for Linux 2 (WSL2)](https://docs.microsoft.com/en-us/windows/wsl/install)
- Install Docker Desktop for Windows with WSL2 integration enabled
- Install kubectl, helm, and Terraform **inside WSL** using Linux package managers (Python 3 is normally already there)
- Run all commands in WSL terminal (Ubuntu, Debian, etc.)
- ✅ **Pros**: Full Linux compatibility, better for complex workflows
- ⚠️ **Networking**: WSL2 localhost forwarding handles port access automatically
- ⚠️ **Paths**: Use Linux paths (`/home/user/`) not Windows paths (`C:\Users\`)

**Installing the tools (Git Bash option)**

With the Windows Package Manager, from PowerShell or Command Prompt (package IDs from the [winget-pkgs](https://github.com/microsoft/winget-pkgs) repository):
```powershell
winget install Git.Git
winget install Docker.DockerDesktop
winget install Kubernetes.kubectl
winget install Helm.Helm
winget install Hashicorp.Terraform
winget install Kubernetes.minikube
winget install Python.Python.3.14
```
Then **close every terminal and open a new Git Bash**, so the new programs are on your `PATH`. (Python's winget ID includes the minor version; any current 3.x works.)

**Installing minikube** (where people most often get stuck) — the [minikube Get Started page](https://minikube.sigs.k8s.io/docs/start/) lists three ways for Windows x86-64:
- **winget**: `winget install Kubernetes.minikube`
- **Chocolatey**: `choco install minikube`
- **.exe installer**: download and run the [latest minikube-installer.exe](https://storage.googleapis.com/minikube/releases/latest/minikube-installer.exe). If you instead download the plain `minikube.exe`, minikube's instructions add its folder to the system `PATH` with a PowerShell command that must be run **as Administrator**

Whichever you use, minikube's docs say to **close the terminal and open a new one** before running `minikube` — a terminal opened before the install doesn't see it. Check in a new Git Bash: `minikube version`.

**minikube drivers on Windows** (from minikube's [driver docs](https://minikube.sigs.k8s.io/docs/drivers/)):
- **Docker** (uses Docker Desktop, which you need anyway): Docker Desktop must be running and set to **Linux containers**, not Windows containers. Check: `docker info --format '{{.OSType}}'` prints `linux`
- **Hyper-V**: only on 64-bit Windows 10/11 **Enterprise, Pro or Education** with Hyper-V enabled — not Windows Home
- The demo needs 4 CPUs and 8 GB for the cluster: `minikube start --cpus=4 --memory=8g` (the script offers to recreate a smaller cluster with these values). With the Docker driver the cluster runs inside Docker Desktop, so Docker Desktop itself must have that much available: `docker info --format '{{.NCPU}} CPUs, {{.MemTotal}} bytes'`

**Python 3 under Git Bash** — the scripts call `python3`, and they stop with a cryptic error without it. Check in Git Bash:
```bash
python3 --version
```
It must print a version. If it says the command isn't found, or opens the Microsoft Store, Python isn't installed or Windows' placeholder is in the way: install Python (above or from [python.org](https://www.python.org/downloads/)), then in Windows open Start → **Manage app execution aliases** and check the Python entries (Python's own Windows docs point there for this problem), and open a new Git Bash.

**Kubernetes Options for Windows:**
- **minikube** (recommended by the script) - Works with both Git Bash and WSL2. Keep `minikube tunnel` running in a separate terminal while you use the demo (it may ask for your password)
- **Docker Desktop** - Enable Kubernetes in settings (Settings > Kubernetes > Enable Kubernetes)
- **Rancher Desktop** - Alternative to Docker Desktop with built-in Kubernetes

If minikube isn't installed, `start-demo.sh` asks whether you have Docker Desktop or Rancher Desktop with Kubernetes instead; answer **y** only if Kubernetes is actually enabled there.

**Verification:**
After choosing your approach, verify your bash environment works:
```bash
# In Git Bash or WSL terminal
bash --version              # Should show bash version
docker --version            # Should show Docker version
docker info --format '{{.OSType}}'   # Should print: linux
kubectl version --client    # Should show kubectl version
helm version                # Should show helm version
terraform version           # Should show Terraform version
python3 --version           # Should show Python 3.x
minikube version            # If you use minikube
```

## Quick Start Guide

### Step 1: Clone the Repository

```bash
# Clone this repository (the fix/acn-nfr branch has the current setup scripts)
git clone -b fix/acn-nfr https://github.com/cdhendley/harness-partner-demo-kit.git partner-demo-kit
cd partner-demo-kit

# Already cloned? Get the latest:
git fetch && git checkout fix/acn-nfr && git pull
```

> **Use this branch.** The upstream `harness-community/partner-demo-kit` `main` branch still has the old setup script, which tries to create a new Harness project (a 403 for anyone who is only Project Admin) and whose cleanup can delete a shared project.

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

The `start-demo.sh` script automates the **complete demo setup**, from local infrastructure to Harness resources. In the order it runs:

**1. Platform & Kubernetes**
- Detects your operating system and architecture (macOS/Windows/Linux, ARM64/AMD64)
- Checks for the right Kubernetes tool for your platform:
  - Apple Silicon Macs: Colima, always a native arm64 VM (offers to `brew install` missing pieces, starts Colima, and offers to recreate an old x86_64 VM as native)
  - Windows: minikube recommended; Docker Desktop or Rancher Desktop with Kubernetes enabled also work (the script asks)
  - Intel Macs and Linux: minikube, Colima, Docker Desktop or Rancher Desktop
- Checks that Docker and kubectl are installed and the Docker daemon is running
- Starts minikube if it's your cluster and isn't running; verifies the cluster answers
- **Validates cluster resources** (minimum 4 CPU cores, 8GB memory) and offers to recreate Colima/minikube with enough

**2. Background work**
- Creates the `dockerhub-pull` image pull secret if a verified Docker Hub token is already saved
- **Deploys Prometheus in the background** (for continuous verification) while the rest runs

**3. Harness settings** (asked once, up front)
- Harness **account ID**
- Harness **API token**: checked locally first (must look like `pat.<account>.<id>.<secret>` — an API key pasted by mistake gets a specific message), then with Harness
- **Organization**: a numbered list of the orgs your token can see
- **Project**: a numbered list of only the projects in that org where you have the permissions the kit needs (Project Admin). "Create a NEW project" is offered only if you are allowed to create projects
- **Your name/ID**: a short tag, e.g. `alex`, added to everything the kit creates for you; refused if someone else in the project already uses it

**4. Docker Hub and images**
- Asks whether to build images (**Y** on the first run; **n** later saves time)
- Asks for your Docker Hub **access token** (once; checked with Docker Hub, saved) and logs in with it
- Checks for the Docker buildx plugin (offers to install it on macOS)
- **Builds backend, test and docs images in parallel** with docker buildx for **linux/amd64 and linux/arm64** under the same tag (works on Harness Cloud and Apple Silicon), personalizes the lab guides with your project and name/ID, and pushes to your Docker Hub `harness-demo` repository
- Refreshes the `dockerhub-pull` secret in the `default` and `harness-delegate-ng` namespaces with the verified token

**5. Harness resources (Terraform/OpenTofu)**
- Writes `kit/se-parms.tfvars` from your answers
- **Pre-flight checks** before Terraform: token shape, token account matches your account ID, org exists, permissions (project-create for a new project; project-scoped edit rights for an existing one), and name/ID collisions. Bypass with `DEMO_SKIP_PREFLIGHT=true`
- On re-runs, asks whether to re-run Terraform (default: yes)
- Imports the existing project into Terraform state (never recreates it), and **reuses the `partner_demo_kit` code repository if it already exists in the project**; otherwise Harness imports it from GitHub
- Runs init, plan and apply. If Harness's GitHub import fails with *"Access denied … at github"* (Harness's anonymous GitHub access is throttled), the apply is retried a few times; if it still fails, the script prints how to import the repository in the Harness UI, after which a re-run reuses it

**6. Lab documentation**
- Deploys the docs site on every run (also with `--skip-docker-build`, using the existing docs image) at http://localhost:30001
- Uses `imagePullPolicy: Always` plus a rollout restart so a rebuilt `docs-latest` is picked up

**7. Harness delegate**
- If the delegate your connectors expect isn't connected, offers to install it
- Fetches the project's delegate token (`default_token`), the manager endpoint and the latest delegate image from the Harness API
- Installs it with Helm at **project scope** into the `harness-delegate-ng` namespace, named to match the connectors: `<name/ID>-k8s-delegate` (or `local-k8s-delegate` with no name/ID), and waits until Harness shows it connected. Skip with `--skip-delegate`; the manual fallback is in Lab 0

**8. Status and next steps**
- Shows cluster, Prometheus and Terraform status and what to do next

### Script Options

```bash
# Skip Docker image build (if you already have the backend image)
./start-demo.sh --skip-docker-build

# Skip Terraform/Harness setup (useful for infrastructure-only testing)
./start-demo.sh --skip-terraform

# Skip the automatic Harness delegate install
./start-demo.sh --skip-delegate

# Pre-answer the organization question
./start-demo.sh --org my_org

# Pre-answer the name/ID question (see "Sharing One Harness Project" below)
./start-demo.sh --participant alex

# Apple Silicon: force a qemu-emulated amd64 Colima VM (slow; without the flag it is always native)
./start-demo.sh --colima-arch amd64

# Combine options
./start-demo.sh --skip-docker-build --skip-terraform
```

All of these are optional and nobody needs them: the script asks for every setting interactively (organization, project, name/ID, whether to build images, whether to re-run Terraform, delegate install) and offers your previous answers as defaults. Flags only pre-answer those questions.

Shared helper functions live in [scripts/demo-lib.sh](scripts/demo-lib.sh) (bash 3.2 compatible, so it runs with the macOS system bash).

### Sharing One Harness Project

Everyone works in the one **Onboarding** project without colliding:
- Each person types a **name/ID** — just their name, e.g. `alex`: 1-20 lowercase letters/digits, starting with a letter. Asked on every run (previous answer is the default), saved as `PARTICIPANT_ID` in `.demo-config`. Use the same one every time
- Terraform appends `_<id>` to identifiers and ` <id>` to names of everything the kit creates for you — connectors `workshop_k8s_<id>` / `workshopdocker_<id>` / `prometheus_<id>`, secrets, environments, infrastructure, backend service, template and monitored services
- Your delegate becomes `<id>-k8s-delegate`, and the lab guides at http://localhost:30001 are personalized with your names
- The code repository is the exception: there is **one** `partner_demo_kit` per project, shared by everyone. Whoever runs first (or the workshop lead, ideally) creates it; everyone else's run reuses it
- The script refuses a name/ID someone else in the project already uses and asks for another
- You pick the project from a list of the projects you can administer; an existing project is imported into Terraform, never recreated
- `stop-demo.sh` never deletes a shared or pre-existing project, or the shared repository — it only destroys your own resources
- Type `none` as the name/ID only if nobody else uses the project; you then get the original single-user names (`workshop_k8s`, `local-k8s-delegate`, ...)

### First Run vs Subsequent Runs

**First Run (Complete Setup):**
- Asks for: Harness account ID and API token, organization and project (numbered lists), your name/ID, whether to build images, Docker Hub username (unless Docker Desktop already knows it) and access token, and whether to install the delegate
- Checks both tokens as you paste them; nothing is saved until it is accepted
- Saves your answers and tokens to `.demo-config`
- Creates your Harness resources with Terraform and installs your delegate
- Takes roughly 10-20 minutes, mostly downloads and image builds

**Subsequent Runs:**
- Offers every previous answer as the default — press Enter to keep it
- Re-checks the saved tokens and asks again only if one is rejected
- Asks whether to re-run Terraform (**2**, the default, re-runs it and only changes what's different; **1** skips it)
- Answer **n** to *Build images?* unless you changed code, your project or your name/ID
- Redeploys the docs and reinstalls the delegate if it's missing

### Credential Management

The script stores your answers in `.demo-config` (git-ignored, readable only by you):
- **Harness account ID, organization, project and your name/ID**
- **Harness API token** (`HARNESS_PAT`; `export DEMO_BASE_PAT=...` overrides it)
- **Docker Hub username and access token** (`DOCKER_PAT`) — also written to `kit/se-parms.tfvars`, from which Terraform stores it in Harness as the secret your Docker connector uses, and into the cluster's `dockerhub-pull` image pull secret

**Security Notes:**
- `.demo-config` and `kit/se-parms.tfvars` are excluded from Git via `.gitignore` — never commit or share them
- Use access tokens, not passwords: Docker Hub tokens at https://hub.docker.com/settings/security; Harness tokens under Profile > My API Keys & Tokens
- To be asked for everything again: `rm .demo-config` and re-run

### When Finished with the Demo

```bash
# Interactive cleanup menu (RECOMMENDED)
./stop-demo.sh
```

> **Shared project (Onboarding)?** Only options **1–3** are purely local. Options 4–7 also remove *your own* Harness resources; they never delete the shared project, the shared `partner_demo_kit` repository or anyone else's resources. When in doubt, use option 1.

**Interactive Cleanup Menu:**

When you run `./stop-demo.sh` without arguments, you'll see a menu:

1. **Stop K8s deployments only** (default, recommended)
   - Removes frontend and backend deployments/services
   - Keeps your Harness resources, Prometheus and the cluster running
   - Restart later with `./start-demo.sh`

2. **Stop K8s deployments + Delete Prometheus**

3. **Stop K8s deployments + Stop cluster**
   - Also stops Colima/minikube; Harness resources stay

4. **Full cleanup (delete all Harness resources)**
   - Destroys the Harness resources **you** created with Terraform. In a shared or pre-existing project (a name/ID set, or `PROJECT_PREEXISTING=true`), the project and the shared repository are removed from Terraform state first, so they are left alone (the menu text still says "Removes: Harness project")
   - Tries to delete your Docker Hub `harness-demo` repository (needs a Docker Hub token with **Delete** access; otherwise it is skipped)
   - Removes Prometheus; keeps the cluster running and your config files

5. **Complete cleanup (everything including cluster)**
   - Same as option 4, plus stops the cluster and offers to delete the Colima VM and its data disk (`colima delete -f --data`)

6. **Force delete Harness project via API** (bypasses Terraform state)
   - For a project the kit created itself when Terraform state is broken. **Refuses** to delete a shared or pre-existing project (it then only cleans up locally)

7. **Custom cleanup options**
   - Asks about each step separately

0. **Exit without doing anything**

**Command-Line Flags (Skip Interactive Menu):**

For automated/scripted use:
- `./stop-demo.sh --delete-prometheus` - Also remove Prometheus monitoring
- `./stop-demo.sh --stop-cluster` - Also stop the cluster (Colima or minikube)
- `./stop-demo.sh --delete-harness-project` - Destroy your Harness resources via Terraform (same protection for shared projects as option 4)
- `./stop-demo.sh --force-api-delete` - Option 6 (refused for shared/pre-existing projects)
- `./stop-demo.sh --delete-docker-repo` - Delete the Docker Hub `harness-demo` repository via API
- `./stop-demo.sh --delete-config-files` - Delete `.demo-config`, `se-parms.tfvars` and the Terraform state files
- `./stop-demo.sh --full-cleanup` - Prometheus, cluster stop, Harness resources and Docker Hub repo (keeps config files)
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
> 1. Check the setup: [HOWTO.md Part D](HOWTO.md#part-d-check-it-worked) (lab guides, delegate, the three connector tests, the code repository)
> 2. Navigate to [app.harness.io](https://app.harness.io) and select the **Onboarding** project
> 3. Configure Harness Code Repository (see Step 8 in Manual Setup below)
> 4. Follow the lab guides at http://localhost:30001 (also in the [markdown/](markdown/) directory, without your personalized names)

---

## Manual Setup

If you prefer manual control or need to troubleshoot, follow these detailed steps:

### Step 2: Set Up Kubernetes

Use the cluster recommended for your platform (see Prerequisites): **Colima** on Apple Silicon (native arm64 — see the Colima commands in Prerequisites), **minikube** on Windows, any of the options below elsewhere.

**Option A: Rancher Desktop**
1. Download and install [Rancher Desktop](https://rancherdesktop.io/)
2. Open Rancher Desktop preferences
3. Enable Kubernetes
4. Wait for Kubernetes to start (green indicator)
5. Services will be automatically accessible at `localhost`

**Option B: minikube**
```bash
# Start minikube with the resources the demo needs
minikube start --cpus=4 --memory=8g

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

**Critical**: Replace `dockerhubaccountid` with your Docker Hub username in:
1. The Docker build/push commands above
2. Your Harness pipeline's Test Intelligence step, which uses the `test-latest` image

(`kit/main.tf` needs no edit: the backend service's image path is built from the `docker_username` Terraform variable.)

### Step 5: Configure Harness Account

1. **Log in to Harness**: [app.harness.io](https://app.harness.io)

2. **Enable Required Modules**:
   - Navigate to Account Settings > Subscriptions
   - Enable: **CI**, **CD**, and **Code Repository**

3. **Harness Delegate**:
   - `start-demo.sh` **installs the delegate automatically** with Helm at **project scope**, named `<name/ID>-k8s-delegate` (or `local-k8s-delegate` with no name/ID), and waits for it to connect
   - Manual fallback (only if the script couldn't, or you used `--skip-delegate`): see **Lab 0** ([markdown/0-login.md](markdown/0-login.md)) — in **Project Settings > Delegates > New Delegate > Kubernetes > Helm Chart**, run all three commands, and set both the Helm release name and `--set delegateName=` to your delegate name so the connectors find it

4. **Get Your Harness Account ID**:
   - It's the part right after `/account/` in any Harness URL: `https://app.harness.io/ng/account/<ACCOUNT_ID>/...`

5. **Create a Harness API Token**:
   - Profile (bottom-left) > **My API Keys & Tokens** > your API key > **+ Token** (see Required Accounts above — an API key alone is not a token)
   - Save the `pat.…` value securely; it is shown only once

### Step 6: Configure IaC Variables

> **Note**: The automated `start-demo.sh` script handles this step automatically. Only follow these manual steps if you skipped the automated setup or used `--skip-terraform`.

```bash
# Navigate to kit directory
cd ../kit

# Edit se-parms.tfvars
# Replace the placeholder values with your actual values:
```

**se-parms.tfvars** (this is exactly what `start-demo.sh` writes):
```hcl
account_id = "your-harness-account-id"

docker_username = "your-dockerhub-username"
DOCKER_PAT = "your-dockerhub-access-token"

project_name = "Onboarding"
project_identifier = "Onboarding"

org_id = "your-org-identifier"

participant_id = "your-name-id"
```

- `org_id`: the organization's **identifier** (the part after `/orgs/` in the project's URL), not its display name
- `participant_id`: your name/ID (e.g. `alex`); `""` gives the original single-user names
- `DOCKER_PAT` must be a real Docker Hub access token: Terraform stores it in Harness as the secret the Docker connector uses
- An existing project must be imported before `apply`, or Terraform tries to create it: `terraform import -var="pat=$DEMO_BASE_PAT" -var-file="se-parms.tfvars" harness_platform_project.base_demo "<org_id>/Onboarding"`. If the project already has the `partner_demo_kit` repository, import that too: `terraform import -var="pat=$DEMO_BASE_PAT" -var-file="se-parms.tfvars" harness_platform_repo.partner_demo_kit "<org_id>/Onboarding/partner_demo_kit"`

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

**What Gets Created** (all in the Onboarding project; with a name/ID, identifiers get `_<id>` and names get ` <id>`):
- Harness project (an existing project is imported, not recreated)
- Kubernetes connector (workshop_k8s)
- Docker Hub connector (workshopdocker)
- Prometheus connector
- Docker credentials (secrets)
- "Compile Application" template
- Dev and Prod environments
- K8s Dev infrastructure
- Backend service
- Monitored services for continuous verification
- Code repository `partner_demo_kit` (one per project, never suffixed): imported from GitHub by the first run, reused by everyone after that

### Step 8: Configure Harness Code Repository

1. Navigate to Harness UI > **Code Repository** module
2. Select the **Onboarding** project
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
- **Colima, Rancher Desktop, Docker Desktop**: http://localhost:8080 (automatic)
- **minikube**: http://localhost:8080 (requires `minikube tunnel` running in a separate terminal)

## Directory Structure

```
.
├── README.md              # Complete reference (this file)
├── HOWTO.md               # Step-by-step setup checklist and troubleshooting by error message
├── SETUP-IMPROVEMENTS.md  # What the setup scripts do and why (native Colima, buildx, delegate, sharing)
├── PREEXISTING-PROJECT-SUPPORT.md  # Reusing an admin-created project; non-default orgs
├── CLAUDE.md              # Instructions for Claude Code AI assistant
├── start-demo.sh          # Automated startup script for local infrastructure
├── stop-demo.sh           # Automated shutdown script for cleanup
├── scripts/
│   └── demo-lib.sh        # Shared helpers (org/project lists, name/IDs, token checks, pre-flight, Colima, buildx, docs, delegate)
├── kit/                   # Terraform Infrastructure as Code
│   ├── main.tf            # Main IaC configuration
│   ├── se-parms.tfvars    # Your configuration (written by start-demo.sh; git-ignored)
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
│   ├── frontend/          # Frontend K8s resources
│   └── docs/              # Lab documentation site (localhost:30001)
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
- **Note**: `start-demo.sh` checks the saved token on every run and asks for a new one if it is rejected. For the exact messages (*That isn't an API token*, *looks incomplete*, *Harness rejected this token*) see [HOWTO.md Part F](HOWTO.md#part-f-already-ran-it-and-it-failed)

**Issue**: Cleanup says Harness project was deleted, but it still exists in the UI
- **Cause**: Usually an expired/invalid cached PAT in `.demo-config` — the old script reported intent, not actual success
- **Solution** (only for a project the kit created for you alone — never for the shared Onboarding project, which the script refuses to delete anyway):
  ```bash
  export DEMO_BASE_PAT="pat.your-new-token"
  ./stop-demo.sh --force-api-delete
  ```

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
- **Solution**: Re-run `./start-demo.sh`; without the `--colima-arch amd64` flag it uses the native VM and offers to recreate the old one. amd64-only images still run inside it via Rosetta

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

**Issue**: Docker image push fails, Docker Hub token rejected, or the **Workshop Docker** connector test fails with invalid credentials
- **Cause**: wrong username (use your Docker Hub username, not your email), an expired/revoked token, or a setup done with an older copy of this kit, which stored a placeholder instead of the token when Docker Desktop was already logged in
- **Solution**: create a new Docker Hub access token (Read & Write), update to the current kit, re-run `./start-demo.sh` and answer **2** (re-run Terraform). The script checks the saved token, asks for a new one if it's rejected, and updates the Harness secret and the cluster's pull secret

**Issue**: Terraform fails with *"Access denied to harness-community/partner-demo-kit at github"*
- **Cause**: Harness imports the demo repository from GitHub without credentials, and Harness's anonymous GitHub access gets throttled (Harness's import documentation recommends "Requires Authorization" for reliable imports). It is on Harness's side
- **Solution**: the script retries a few times. If it still fails, in the Harness UI open the project → **Code Repository** → dropdown next to **New Repository** → **Import Repository**, repository `harness-community/partner-demo-kit`, name `partner_demo_kit`, tick **Requires Authorization** and enter a GitHub token; then re-run `./start-demo.sh`, which reuses that repository. Workshop leads can do this once per project up front

**Issue**: Image pull error: "pull access denied for harness-demo"
- **Cause**: the image isn't in your Docker Hub `harness-demo` repository (images never built/pushed), the repository name differs, or a pipeline step still uses the placeholder `dockerhubaccountid`
- **Solution**:
  1. Check https://hub.docker.com that `YOUR-USERNAME/harness-demo` has the `backend-latest` tag; if not, re-run `./start-demo.sh` and answer **Y** to *Build images?*
  2. In Harness UI, verify the backend service's artifact shows `YOUR-USERNAME/harness-demo:backend-latest` (Terraform sets this from your Docker Hub username)
  3. Replace any `dockerhubaccountid` you typed into a pipeline step with your username, then re-run the pipeline

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
- The connectors expect the delegate name `<name/ID>-k8s-delegate` (or `local-k8s-delegate` with no name/ID); re-run `./start-demo.sh` (answer **n** to images, **1** to skip Terraform) and it offers to reinstall it, or follow the manual steps in Lab 0
- A delegate installed under any other name connects but the connector tests fail

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
- Destroy the Harness resources you created (Terraform) — the shared Onboarding project and the shared `partner_demo_kit` repository are never deleted
- Delete the Docker Hub `harness-demo` repository via API (needs a token with Delete access; otherwise skipped)
- Remove Kubernetes deployments (frontend/backend)
- Remove Prometheus monitoring
- Stop the cluster (Colima or minikube)
- **Keep** your configuration files; add `--delete-config-files` to remove `.demo-config`, `se-parms.tfvars` and the state files too

### Option 2: Selective Automated Cleanup

Choose specific cleanup operations:

```bash
# Clean up only cloud resources (your Harness resources + Docker Hub)
./stop-demo.sh --delete-harness-project --delete-docker-repo

# Clean up cloud resources and local config (keeps K8s running)
./stop-demo.sh --delete-harness-project --delete-docker-repo --delete-config-files

# Clean up only local resources (keeps your Harness resources)
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

> **⚠️ Shared project:** in the Onboarding project, **do not** delete the project or the `partner_demo_kit` repository — they belong to everyone. Remove only your own resources (the ones ending in `_<your name/ID>`), preferably with `./stop-demo.sh` option 4, which does exactly that.

For a project used only by you:
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

# For Colima
colima stop

# For Rancher Desktop / Docker Desktop - stop through the UI
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
- **Local Kubernetes**: Colima (Apple Silicon, native arm64), minikube (recommended on Windows), or Docker Desktop / Rancher Desktop
- **Monitoring**: Prometheus for continuous verification metrics
- **CI/CD**: Harness Cloud for builds, local K8s for deployments
- **Image Storage**: Docker Hub

## Contributing

We welcome contributions and suggestions to improve this demo kit. Please submit pull requests or open issues for any enhancements.

---

*Note: This demo kit is maintained by Harness.io for partner use. While it's designed to be self-contained, partners are encouraged to customize and extend it based on specific customer needs.*
