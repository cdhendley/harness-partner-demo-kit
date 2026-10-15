# Lab 4: Continuous Deployment - Backend (Canary)

> **Lab Type**: BASE DEMO - Available with free Harness account

## Overview
This lab adds backend deployment using a Canary deployment strategy. Unlike the frontend's rolling deployment, canary deployments gradually shift traffic to new versions while monitoring for issues.

## Prerequisites
- Completed Lab 3 (Frontend Deployment)
- Backend service created by Terraform (already exists in "Base Demo" project)
- Application accessible at http://localhost:8080

## Step 1: Add Backend Deploy Stage

1. In the Pipeline Studio, click **+ Add Stage** (after Frontend - Deployment)
2. Select **Deploy** as the stage type
3. Configure:
   - **Stage Name**: `Backend - Deployment`
   - **Deployment Type**: `Kubernetes`
4. Click **Set Up Stage**

## Step 2: Select Backend Service

On the **Service** tab:

1. Click **Select Service** (not "Add Service" - it already exists!)
2. Select **backend{{NAME}}** (this was pre-configured by Terraform)
3. **CRITICAL**: Click on the **backend{{NAME}}** service name to edit it
4. Navigate to the **Artifacts** section
5. Click **Edit** (pencil icon) on the artifact source
6. Update the **Image Path** to: `dockerhubaccountid/harness-demo`
   - ⚠️ **The Terraform-created service has a placeholder - update it with your Docker Hub username**
7. Verify the **Tag** is set to: `backend-latest`
8. Click **Submit** to save the artifact changes
9. Click **Save** to save the service
10. Click **Continue** to proceed to the Environment tab

> **⚠️ IMPORTANT - Update Docker Hub Account**:
>
> **You MUST update the Image Path** to use your Docker Hub username, otherwise the deployment will fail with an "image not found" error.
>
> The Terraform configuration creates the backend service with a placeholder that needs to be replaced with your actual Docker Hub username. The start-demo.sh script pushed your backend image to your Docker Hub account, so the service needs to point there.
>
> **What to change**:
> - Update the Image Path to: `dockerhubaccountid/harness-demo`
> - Keep the tag as: `backend-latest`

> **About the Backend Service Template**:
>
> The backend service was **pre-configured by Terraform** to demonstrate how platform teams can create reusable service templates. This service includes:
>
> **Kubernetes Manifests** (from Harness Code Repository):
> - **Repository**: `partner_demo_kit`
> - **Manifest Path**: `harness-deploy/backend/manifests/`
> - **Values File**: `harness-deploy/backend/values.yaml`
> - These manifests define the backend deployment, service, and configuration
>
> **Docker Artifact Configuration**:
> - **Artifact Source**: Docker Registry
> - **Connector**: `Workshop Docker{{NAME}}` (reusing the connector from the frontend)
> - **Image Path**: `dockerhubaccountid/harness-demo` (you just updated this!)
> - **Tag**: `backend-latest`
> - This points to the backend Docker image you built during setup
>
> **What This Demonstrates**:
> - Platform teams can create and maintain service definitions centrally
> - Development teams can simply select and use pre-configured services
> - Standardization ensures consistency across deployments
> - Services can be versioned and updated independently of pipelines
>
> By using a pre-configured service, you're following a **platform engineering** approach where infrastructure and deployment configurations are managed as reusable templates.

## Step 3: Propagate Environment from Frontend

On the **Environment** tab:

1. Click **Propagate Environment From**
2. Select **Stage [Frontend - Deployment]**
3. Click **Continue**

> **Understanding Environment Propagation**:
>
> Instead of manually selecting the environment and infrastructure again, we're **propagating** from the frontend stage. This means:
>
> **What's Being Inherited**:
> - **Environment**: `Dev{{NAME}}` (created by Terraform)
> - **Infrastructure**: `K8s Dev{{NAME}}` (Kubernetes cluster connector)
> - **All environment variables** and configurations
>
> **Benefits of Propagation**:
> - **Consistency**: Both frontend and backend deploy to the same environment
> - **Less Configuration**: No need to select the same settings twice
> - **Reduced Errors**: Eliminates potential mismatches between stages
> - **Easier Updates**: Changing the environment in one place updates all propagated stages
>
> This is particularly useful in multi-service architectures where several services need to deploy to the same environment as part of a single pipeline execution.

## Step 4: Choose Canary Deployment Strategy

On the **Execution** tab:

1. Select **Canary** deployment strategy
2. Click **Use Strategy**

> **What is Canary Deployment?**
> Canary deployment gradually rolls out changes to a small subset of users before rolling out to the entire infrastructure. This allows you to:
> - Test in production with minimal risk
> - Catch issues before full rollout
> - Automatically rollback if problems are detected
>
> The default canary strategy:
> 1. Deploys canary pods (small percentage of traffic)
> 2. Monitors performance and errors
> 3. Promotes to full deployment if healthy
> 4. Can automatically rollback if issues detected

## Step 5: Save and Run the Pipeline

1. Click **Save** in the top right
2. Click **Run**
3. Configure the run:
   - **Branch Name**: `main`
   - **Stage: Frontend - Deployment**
     - **Primary Artifact**: `frontend`
   - **Stage: Backend - Deployment**
     - **Primary Artifact**: `backend`
4. Click **Run Pipeline**

## Monitor the Deployment

Watch all three stages execute:
- ✅ **Build** - CI pipeline
- ✅ **Frontend - Deployment** - Rolling deployment
- ✅ **Backend - Deployment** - Canary deployment (watch the canary phases!)

## Verify the Deployment

### Check Kubernetes Resources

```bash
# View all deployments
kubectl get pods -A | grep deployment

# View all services
kubectl get services -A | grep svc
```

You should now see:
- `frontend-deployment` pods
- `backend-deployment` pods (including canary pods during deployment)
- `web-frontend-svc` service
- `web-backend-svc` service

### Test the Application

**With Colima (Apple Silicon Macs) or Rancher Desktop:**
- Services are automatically accessible at http://localhost:8080

**With minikube:**
```bash
# Ensure minikube tunnel is running in a separate terminal
minikube tunnel
```

**Access the demo app**:
1. Open browser to: http://localhost:8080
2. Click **"Distribution Test"** > **"Start"** button
3. Click the **Play (▶️)** button
4. Watch the traffic distribution graph build out

This graph shows how requests are distributed across the backend pods!

### Spot the Canary!

During canary deployments, a special "canary" feature is enabled:
- Keep clicking the **"Check Release"** button
- Look for a **yellow cartoon graphic** - that's the canary!
- This graphic is served only by canary pods

## Key Takeaways

- **Canary deployments** reduce risk by gradual rollout
- **Service propagation** ensures consistency across related deployments
- **Pre-configured services** (via Terraform) streamline demo setup
- **Canary phases** (deploy → monitor → promote) provide safety gates
- **Traffic shifting** can be observed in real-time

## What You've Built

Your complete pipeline now includes:
1. **Build** stage
   - Test Intelligence
   - Compile Application
   - Docker Build & Push
2. **Frontend - Deployment** stage
   - Rolling deployment
3. **Backend - Deployment** stage (new!)
   - Canary deployment
   - Automated traffic shifting

---

> **Note**: Lab 5 (Security Testing) is available only with a licensed partner organization
