# Lab 0: Getting Started

> **Lab Type**: BASE DEMO - Available with free Harness account

## About This Partner Demo Kit

This **Partner Demo Kit** includes two parts: 

1. **Base Demo** (Labs 1-4, 6) - Covers core Harness capabilities:
   - Code Repository with Secret Scanning
   - CI Pipeline with Test Intelligence
   - Continuous Deployment (Rolling and Canary strategies)
   - Continuous Verification with Prometheus

2. **Advanced Demo** (Labs 5, 7) - Extends the base kit with licensed features:
   - Security Testing Orchestration (STO)
   - Software Supply Chain Assurance (SSCA)
   - OPA Policy Enforcement
   - Advanced governance capabilities

> **Note**: The advanced features (Labs 5 and 7) require licenses for the STO and SCS modules in Harness. Please contact your Harness Partner Account Manager for more information. The base demo can be completed with a free Harness account.

## Overview

This guide helps you get started with the Harness Partner Demo Kit. The setup process is automated through a script that handles all infrastructure, Harness resource provisioning, and the Harness delegate installation. You'll then verify everything before proceeding with the individual labs.

## Prerequisites

Before starting, ensure you have:

1. **Harness Account**
   - Free (or paid) Harness account with CI, CD, and Code Repository modules
   - Harness Account ID (found in your account profile URL)
   - **Harness API token** — required for `start-demo.sh` and cleanup:
     1. Profile (bottom-left) → **My API Keys & Tokens**
     2. Create an API key if needed (**+ API Key**)
     3. Click **+ Token** on that key (the key alone is not a usable token)
     4. Copy the `pat.*` value immediately — shown only once
     5. Permissions: All resources / All scopes

2. **Local Environment**
   - Docker Engine running
   - Kubernetes cluster: Colima (macOS Apple Silicon), minikube, Docker Desktop, or Rancher Desktop
   - Terraform installed
   - kubectl and helm installed (helm is used to install the Harness delegate)
   - Docker buildx (BuildKit) for multi-architecture image builds — Docker Desktop includes it; with Homebrew's `docker` CLI run `brew install docker-buildx` (the setup script offers to do this)
   - Git client installed
   - **Windows Users**: Git Bash (included with Git for Windows) or WSL2 required to run setup scripts

3. **Docker Hub Account**
   - Docker Hub account created
   - Docker Hub repository `harness-demo` created
   - Docker Hub Personal Access Token (PAT) generated

## Run the Automated Setup

The demo includes an automated setup script that handles all infrastructure and resource provisioning:

**1. Make the script executable (first time only):**
```bash
chmod +x start-demo.sh
```

**2. Run the setup script:**
```bash
./start-demo.sh
```

The script will prompt you for:
- Harness Account ID
- Harness API token (`pat.*` from **+ Token** under your API key)
- Docker Hub username and password
- Your Harness project name (an existing project is reused — enter its exact display name)
- A **participant ID** — only needed when several people share one Harness project (see below)

> **Sharing one project with other people?** Each person picks a short participant ID (lowercase letters/digits, e.g. `alex`). Everything the kit creates gets that ID appended — connectors, environments, the backend service, the code repository, and your delegate (`alex-k8s-delegate`) — so nobody collides. These lab guides are personalized with *your* names automatically. If you are the only person using the project, leave the participant ID empty.

> **Important**: Creating an API key is not enough — you must click **+ Token** on the key and copy the token value. If you only see an API key with no tokens listed under it, setup and cleanup will fail with authentication errors.

> **Tip**: The script saves your configuration to `.demo-config` for future runs, so you won't need to re-enter credentials.

> **Note**: The setup script automatically personalizes the lab documentation with your Docker Hub username. Throughout the labs, when you see instructions referring to your Docker Hub images (e.g., `yourusername/harness-demo`), these will show your actual Docker Hub username instead of a placeholder like `dockerhubaccountid`. This personalization happens when the documentation is built and deployed to your local Kubernetes cluster.

**3. Wait for completion:**
The script may take several minutes to complete depending on the machine being used. Watch for the success message indicating all resources were created.

## What the Setup Script Did

The automated setup configured your complete demo environment:

1. **Detected and Started Kubernetes** - Identified your cluster (Colima, minikube, Docker Desktop, or Rancher Desktop) and ensured it's running
2. **Deployed Prometheus** - Installed Prometheus in the `monitoring` namespace for continuous verification
3. **Built and Pushed Docker Images** - Created the backend application, testing, and docs Docker images and pushed them to your Docker Hub
4. **Provisioned Harness Resources** - Used Terraform to create (or reuse) the "Base Demo" project with all connectors, environments, services, and monitored services
5. **Installed the Harness Delegate** - Installed `{{DELEGATE}}` into your cluster with Helm and waited for it to connect
6. **Saved Your Configuration** - Stored credentials in `.demo-config` for subsequent runs

## Access the Demo Documentation

The setup script deployed this documentation to your local Kubernetes cluster for easy access during the demo:

1. **Open the documentation** in your browser:
   ```
   http://localhost:30001
   ```

2. **Set up side-by-side viewing** for the best demo experience:

   **Option A: Two Browser Windows**
   - Open the documentation in one browser window: `http://localhost:30001`
   - Open Harness in another window: `https://app.harness.io`
   - Arrange them side-by-side on your screen

   **Option B: Chrome Split-View Tabs** (Chrome 135+)
   - Open both URLs in Chrome tabs
   - Right-click on either tab and select **"Move tab to new window with side-by-side"**
   - This creates a split-view within a single Chrome window for convenient navigation

> **Tip**: Having the documentation and Harness UI visible simultaneously makes it much easier to follow along with the labs step-by-step.

## Access Your Harness Account

Now that setup is complete, access your Harness account to verify resources:

1. Navigate to [app.harness.io](https://app.harness.io)
2. Log in with your Harness credentials
3. **Select the "Base Demo" project** from the project picker in the top navigation

> **Important**: All lab activities take place in the **"Base Demo"** project. This keeps demo resources separate from production environments.

## Verify Your Setup

Verify that the setup created all required resources:

### Harness Resources in "Base Demo" Project

Navigate to the **"Base Demo"** project and verify:

**Code Repository:**
- Using the module selection button ![](images/2026-01-07_10-33-10.jpg)
- Choose the **Code Repository** module
- Verify `partner_demo_kit{{ID}}` repository exists

**Continuous Delivery & Git Ops**
- Next, using the module selection button again, choose the **Continuous Delivery & Git Ops** module
- If the setup wizard dialog launches, you can simple **X** out of it at the upper-right corner

**Connectors:**
- On the left-side menu, go to **Project Settings** > **Connectors**
- Verify these connectors exist:
  - `Workshop Docker{{NAME}}` (`workshopdocker{{ID}}`) - Docker Hub connector
  - `Workshop K8s{{NAME}}` (`workshop_k8s{{ID}}`) - Kubernetes connector (for your local cluster)
  - `Prometheus{{NAME}}` (`prometheus{{ID}}`) - Prometheus connector (for continuous verification)
  - All should show **Success** once your delegate is connected (see below)

**Environments:**
- Go to **Environments**
- Verify `Dev{{NAME}}` environment exists
- Click into it and verify `K8s Dev{{NAME}}` infrastructure definition exists

**Services:**
- Go to **Services**
- Verify `backend{{NAME}}` service exists and is configured with K8s manifests

**Templates:**
- Go to **Templates** (under Project Settings)
- Verify `Compile Application{{NAME}}` step template exists

**Monitored Services:**
- Go to **Monitored Services**
- Verify `backend_dev{{ID}}` monitored service exists for continuous verification

### Local Infrastructure

Verify your local infrastructure is running:

**Kubernetes Cluster:**
```bash
kubectl cluster-info
# Should show Kubernetes control plane running
```

**Prometheus:**
```bash
kubectl get pods -n monitoring
# Should see a prometheus-deployment-... pod Running
```

## Harness Delegate

The Harness Delegate runs in your local cluster and lets Harness deploy to it and reach Prometheus. **The setup script installs it for you** as `{{DELEGATE}}` — the name your connectors are configured to use — and waits until Harness shows it connected.

### Verify the Delegate

**Check the pod:**
```bash
kubectl get pods -n harness-delegate-ng
# Expect a {{DELEGATE}}-... pod with READY 1/1 and STATUS Running (allow 1-2 minutes)
```

**Check in Harness:** **Project Settings** > **Delegates** — `{{DELEGATE}}` should show **Connected**.

### Verify Delegate Functionality

1. Go to **Project Settings** > **Connectors** in the "Base Demo" project
2. Click the `Workshop K8s{{NAME}}` connector, then **Test Connection** (top right)
3. Repeat for `Prometheus{{NAME}}`
4. Both tests should succeed, confirming Harness can reach your local cluster through the delegate

### Installing the Delegate Manually (only if the script couldn't)

Use **Project Settings** > **Delegates** > **New Delegate** > **Kubernetes** > **Helm Chart**. The page shows three commands; you need **all three**:

1. `helm repo add harness-delegate …` — registers the chart repository. `harness-delegate` here is only a local name for the repository; **don't change it**.
2. `helm repo update harness-delegate` — refreshes it.
3. The long `helm upgrade -i … --set …` command — **this is the one that actually installs the delegate**. It looks like a list of settings, but it is the install.

Before running the third command, make sure **both** of these say `{{DELEGATE}}` (the page may still show its default name even after you rename the delegate):
- the release name right after `helm upgrade -i`
- `--set delegateName=…`

The connectors only find a delegate with exactly that name. A wrong name still installs and connects, but connector tests and deployments fail later with "no delegate available".

## Troubleshooting

### Setup Script Failed

**If start-demo.sh fails during execution:**
1. Check the error message for specific issues
2. Verify all prerequisites are installed:
   ```bash
   docker --version
   kubectl version --client
   terraform --version
   helm version
   ```
3. Ensure Docker Engine is running
4. Verify Kubernetes cluster is accessible: `kubectl cluster-info`
5. Re-run the script after fixing issues: `./start-demo.sh`

### Harness API Token Invalid or Missing

**Symptoms:** Terraform fails with `401 Unauthorized`, cleanup reports project deleted but it still exists, or scripts say "Token is not valid"

**Common cause:** You created an API key but did not click **+ Token** under it. The screenshot in Harness will show your key (e.g. `partner-kit-key`) with a **+ Token** link and no tokens listed.

**Fix:**
1. Profile → **My API Keys & Tokens** → your key → **+ Token**
2. Copy the new `pat.*` value
3. Run: `export DEMO_BASE_PAT="pat.xxx"` then `./start-demo.sh` or `./stop-demo.sh --force-api-delete`
4. Or delete `.demo-config` and re-run `./start-demo.sh` to enter fresh credentials

### Can't Find "Base Demo" Project

1. Check if Terraform completed successfully in the script output
2. Verify the project exists: Harness UI > **Projects** > Look for "Base Demo"
3. If missing, re-run setup: `./start-demo.sh`

### Delegate Not Connecting

**Check delegate pod status:**
```bash
kubectl get pods -n harness-delegate-ng
kubectl logs -n harness-delegate-ng <pod-name>
```

**Common issues:**
- Pod is not running: Check for image pull errors or resource constraints
- Delegate shows in UI but status is "Not Connected": Check network connectivity
- Delegate token expired: Generate a new token and reinstall

### Kubernetes Cluster Issues

**Rancher Desktop:**
- Verify Rancher Desktop is running
- Check Kubernetes is enabled in **Preferences** > **Kubernetes**
- Restart Rancher Desktop if needed

**Minikube:**
- Start cluster: `minikube start`
- Check status: `minikube status`
- If tunnel needed: Run `minikube tunnel` in a separate terminal

### Prometheus Not Running

```bash
# Check Prometheus pod
kubectl get pods -n monitoring

# If not running, redeploy
kubectl create namespace monitoring
kubectl -n monitoring apply -f ./kit/prometheus.yml
```

### Connector Test Failures

**Workshop K8s{{NAME}} connector fails:**
- Verify delegate is connected
- Check delegate has access to your local cluster
- Test manually: `kubectl get nodes`

**Workshop Docker{{NAME}} connector fails:**
- Verify Docker Hub credentials in Harness secrets
- Test manually: `docker login`
- Ensure Docker Hub repository `harness-demo` exists

## Lab Structure

Now that you've completed the setup and installed the delegate, you're ready to proceed with the demo labs:

1. **Lab 1: Code Repository Secret Scanning** - Prevent secrets from being committed to your code repository
2. **Lab 2: CI Pipeline** - Build application with test intelligence and push Docker images
3. **Lab 3: Frontend Deployment** - Deploy frontend using rolling deployment strategy
4. **Lab 4: Backend Deployment** - Deploy backend using canary deployment strategy
5. **Lab 5: Security Testing** - Advanced security scanning (requires licensed partner org)
6. **Lab 6: Continuous Verification** - ML-powered deployment validation with Prometheus
7. **Lab 7: OPA Policy Enforcement** - Policy-as-code governance (requires licensed partner org)

> **Note**: Labs 5 and 7 require a licensed Harness organization. The core demo (Labs 1-4, 6) can be completed with a free Harness account.

## Important Notes

**Before Starting Lab 1:**
- Ensure your delegate shows **Connected** status in Harness
- Verify all connectors in the "Base Demo" project test successfully
- If using minikube, keep `minikube tunnel` running in a separate terminal throughout the demo
- Colima, Rancher Desktop, and Docker Desktop users don't need a tunnel - services are automatically accessible

**Throughout the Demo:**
- All activities take place in the **"Base Demo"** project
- The `partner_demo_kit{{ID}}` repository in Harness Code Repository is mirrored from GitHub
- You'll generate Git credentials for the Harness Code Repository in Lab 1
- Your local Kubernetes cluster and Prometheus must remain running

**Next Steps:**
Proceed to **Lab 1: Code Repository Secret Scanning** to begin the demo!

---

