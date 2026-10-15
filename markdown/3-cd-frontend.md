# Lab 3: Continuous Deployment - Frontend

> **Lab Type**: BASE DEMO - Available with free Harness account

## Overview
This lab extends your CI pipeline with a deployment stage for the frontend application. You'll deploy to your local Kubernetes cluster (Colima, minikube, or Rancher Desktop) using a rolling deployment strategy.

## Prerequisites
- Completed Lab 2 (CI Pipeline)
- Kubernetes cluster running (Colima for Apple Silicon, minikube, or Rancher Desktop)
- "Base Demo" project with Dev{{NAME}} environment and K8s Dev{{NAME}} infrastructure (created by Terraform)

## Step 1: Add a Deploy Stage

1. In the Pipeline Studio, click **+ Add Stage** (after the Build stage)
2. Select **Deploy** as the stage type
3. Configure:
   - **Stage Name**: `Frontend - Deployment`
   - **Deployment Type**: `Kubernetes`
4. Click **Set Up Stage**

## Step 2: Create Frontend Service

On the **Service** tab:

1. Click **+ Add Service**
2. Configure the new service:

**About the Service:**
- **Name**: `frontend{{NAME}}`
- **Store**: Inline

**Service Definition:**
- **Deployment Type**: Kubernetes

### Configure Manifests

1. Click **+ Add Manifest**
2. **Manifest Type**: `K8s Manifest`
3. **Manifest Source**: `Harness Code` (Code Repository)
4. **Manifest Details**:
   - **Manifest Identifier**: `templates`
   - **Repository Name**: `partner_demo_kit{{ID}}`
   - **Branch**: `main`
   - **File/Folder Path**: `harness-deploy/frontend/manifests`
   - **Values.yaml**: Click **+ Add File**
     - Add: `harness-deploy/frontend/values.yaml`
5. Click **Submit**

### Configure Artifacts

1. Click **+ Add Artifact Source**
2. **Artifact Repository Type**: `Docker Registry`
3. **Docker Registry Connector**: `Workshop Docker{{NAME}}` (created by Terraform)
4. **Artifact Location**:
   - **Artifact Source Identifier**: `frontend`
   - **Image Path**: `dockerhubaccountid/harness-demo`
   - **Tag**: `demo-base-<+pipeline.sequenceId>`
     - Change the field type to **Expression** (click the icon)
5. Click **Submit**
6. Click **Save** to save the service
7. Click **Continue**

## Step 3: Select Environment and Infrastructure

On the **Environment** tab:

1. **Specify Environment**: `Dev{{NAME}}` (created by Terraform)
2. **Specify Infrastructure**: `K8s Dev{{NAME}}` (created by Terraform)
3. Click **Continue**

> **Note**: Platform teams can create and manage environments and infrastructure, then developers can easily use them for deployments. This promotes consistency and reduces setup time.

## Step 4: Choose Deployment Strategy

On the **Execution** tab:

1. Select **Rolling** deployment strategy
2. Click **Use Strategy**

> **Why Rolling?**
> The frontend is a static application serving the UI. A rolling deployment gradually replaces pods with new versions, which is perfect for stateless applications. We'll use Canary deployment for the backend in the next lab.

## Step 5: Save and Run the Pipeline

1. Click **Save** in the top right
2. Click **Run**
3. Configure the run:
   - **Branch Name**: `main`
   - **Stage: Frontend - Deployment**
     - **Primary Artifact**: `frontend`
4. Click **Run Pipeline**

## Monitor the Deployment

Watch the deployment stages execute:
- ✅ **Build** stage - Runs all CI steps from Lab 2
- ✅ **Frontend - Deployment** - Deploys to Kubernetes

> **First Deployment Note**: On your first deployment, the delegate may take 1-2 minutes to pick up the deployment task. This is normal as the delegate on your local machine initializes and connects to Harness. Subsequent deployments will be faster.

## Verify the Deployment

### Check Kubernetes Resources

```bash
# View deployments
kubectl get pods -A | grep deployment

# View services
kubectl get services -A | grep svc
```

You should see:
- `frontend-deployment` pods running
- `web-frontend-svc` service created

### Access the Application

**With Colima (Apple Silicon Macs):**
```bash
# Services are automatically accessible
# Open your browser to:
http://localhost:8080
```

**With Rancher Desktop:**
```bash
# Services are automatically accessible
# Open your browser to:
http://localhost:8080
```

**With minikube:**
```bash
# In a separate terminal, start minikube tunnel (keep it running)
minikube tunnel

# Open your browser to:
http://localhost:8080
```

You should see the Harness demo application UI!

## Key Takeaways

- **Service definitions** encapsulate deployment configuration (manifests + artifacts)
- **Environments and infrastructure** can be reused across services and teams
- **Rolling deployments** are ideal for stateless applications
- **Harness Code Repository** can store Kubernetes manifests
- **Expression syntax** `<+pipeline.sequenceId>` enables dynamic artifact selection

## What You've Built

Your pipeline now includes:
1. **Build** stage (from Lab 2)
   - Test Intelligence
   - Compile Application
   - Docker Build & Push
2. **Frontend - Deployment** stage (new!)
   - Rolling deployment to Kubernetes
   - Uses Dev environment and K8s Dev infrastructure

---
