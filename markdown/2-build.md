# Lab 2: CI Pipeline with Test Intelligence

> **Lab Type**: BASE DEMO - Available with free Harness account

## Overview
This lab walks through creating a complete CI pipeline with test intelligence, compilation, and Docker image building. You'll configure build infrastructure and see how Harness optimizes your CI/CD workflows.

## Prerequisites
- Harness account with CI module enabled
- "Base Demo" project created by Terraform
- Docker Hub account with `harness-demo` repository

## Step 1: Create a New Pipeline

1. In Harness UI, use the modular selector button to navigate to CD module
   ![](images/2025-12-12_13-21-40.jpg)
2. Close the wizard if displayed
   ![](images/2025-12-12_13-23-44.jpg)
3. Click **Pipelines** in the "Base Demo" project (close the wizard if displayed)
4. Click **+ Create Pipeline**
   - **Name**: `Workshop Build and Deploy{{NAME}}`
   - **Store**: Inline (for simplicity)
5. Click **Start**

> **Note**: Inline vs. Remote - We're using inline for this lab, but you can store pipelines in Git repositories alongside your application code.

## Step 2: Add a Build Stage

1. Click **+ Add Stage**
2. Select **Build** as the stage type
   ![](images/2025-12-15_15-14-23.jpg)
3. Configure the build stage:
   - **Stage Name**: `Build`
   - **Clone Codebase**: Enable
   - **Repository Name**: `partner_demo_kit` (the Harness Code repository created by Terraform)
   ![](images/2025-12-15_15-12-17.jpg)
4. Click **Set Up Stage**

## Step 3: Configure Build Infrastructure

> **Note**: The `./start-demo.sh` script automatically creates a Docker Hub secret (`dockerhub-pull`) in your Kubernetes cluster and attaches it to the default service account. This allows build pods to pull Harness CI images like `harness/ci-addon` from Docker Hub using your authenticated credentials (Docker Hub Personal Access Token).

You have several options for build infrastructure. Choose the one that best fits your needs:

### Option A: Harness Cloud (Recommended)

> **Important**: Harness Cloud is available to use for free but you will need to verify yourself using a credit card.  You will not be charged for any use, it's simply a security measure to prevent abuse.

The following will only need to be done once:

1. On the **Infrastructure** tab
2. Click on `Update Card`, enter your card details, agree to the terms of use, and then click `Set as Default Card` to proceed.

![](images/2025-12-16_13-20-50.jpg)

![](images/2025-12-16_13-21-16.jpg)

1. Select **Harness Cloud**
2. Click **Continue**

**Benefits of Harness Cloud**:
- Zero configuration required
- Autoscaling build environment
- Fastest bare-metal hardware available
- No infrastructure management
- Dramatically less expensive than on-premise solutions

### Option B: Kubernetes Build Farm (Alternative - x86/Intel Only)

If you do not wish to use Harness Cloud, you can use your local Kubernetes cluster:

1. On the **Infrastructure** tab
2. Select **Kubernetes**
3. Configure:
   - **Connector**: `workshop_k8s{{ID}}` (created by Terraform)
   - **Namespace**: `harness-delegate-ng` (or your delegate namespace)
4. Click **Continue**

**Benefits of Kubernetes Build Farm**:
- Use existing Kubernetes infrastructure
- Full control over build environment
- Works with any Kubernetes cluster (minikube, Rancher Desktop, cloud providers)
- No external dependencies

> **Note**: For this demo, either option will work. Harness Cloud provides a better experience but requires account verification.

## Step 4: Add Run Tests Step

1. On the **Execution** tab, click **+ Add Step**
2. Select **Add Step** > **Test Intelligence**
3. Configure:
   - **Name**: `Test Intelligence`
   - **Command**:
     ```bash
     mkdir -p reports
     cd ./python-tests
     pytest --junitxml=reports/junit.xml --html=reports/report.html --cov=. --cov-report=xml:reports/coverage.xml
     ```
   - Expand the `Optional Configuration`
   - **Container Registry**: `Workshop Docker{{NAME}}`
   - **Image**: `dockerhubaccountid/harness-demo:test-latest`
     - ⚠️ Use `test-latest` tag (NOT `backend-latest`) - this image has pytest pre-installed

4. Click **Apply Changes**

> **Important**: The `test-latest` image is a lightweight Python container with pytest pre-installed specifically for CI testing. This is different from `backend-latest` which contains the Django application.

![](images/2025-12-16_11-00-25.jpg)

> **Understanding Test Intelligence**:
>
> **The Problem**: Traditional CI systems run your entire test suite on every commit, even when only a small part of the codebase changed. This leads to:
> - Wasted time waiting for irrelevant tests to run
> - Higher infrastructure costs
> - Slower developer feedback loops
> - Reduced productivity
>
> **The Solution**: Test Intelligence uses ML to analyze:
> - Code changes in your commit
> - Historical test results and failures
> - Code coverage data
> - Dependencies between code and tests
>
> **The Result**: Test Intelligence automatically selects only the tests that are relevant to your changes:
> - **80% faster** test execution on average
> - **Same confidence** - catches the same bugs as running all tests
> - **Automatic** - no configuration or test tagging required
> - **Learns over time** - gets smarter with each run
>
> **How It Works in This Demo**:
> - **First run**: Runs all tests to establish a baseline
> - **Subsequent runs**: Only runs tests affected by code changes
> - **Example**: If you only change `backend/views.py`, it won't run frontend tests
>
> This is particularly powerful for large codebases with thousands of tests where a typical commit only affects a small subset.

> **Note**: While this demo uses a small test suite (so you won't see dramatic time savings), the same technology scales to save hours on enterprise test suites.

## Step 5: Add Compile Step (Using Template)

1. Click **+ Add Step**
2. Select **Use Template**
3. Select the **"Compile Application{{NAME}}"** template (created by Terraform)
4. Select **Use Template**
5. Configure:
   - **Name**: `Compile`
6. Click **Apply Changes**

> **About Templates**:
> This step uses a pre-configured template created by Terraform. Templates allow platform teams to standardize build processes across the organization, ensuring consistency and best practices.
>
> The "Compile Application" template:
> - Installs Node.js dependencies
> - Builds the Angular frontend application
> - Produces production-ready static assets

## Step 6: Add Docker Build and Push Step

1. Still in the `Build` Stage, Click **+ Add Step**
2. Select **Add Step** > **Build and Push an image to Docker Registry**
3. Configure:
   - **Name**: `Push to Dockerhub`
   - **Docker Connector**: `Workshop Docker{{NAME}}` (created by Terraform)
   - **Docker Repository**: `dockerhubaccountid/harness-demo`
   - **Tags**: Click **+ Add**
     - Add: `demo-base-<+pipeline.sequenceId>`
     - Change field type to **Expression** using the icon
   - **Enable Docker Layer Caching**: Check this box
   - **Optional Configuration** (expand):
     - **Dockerfile**: `/harness/frontend-app/harness-webapp/Dockerfile`
     - **Context**: `/harness/frontend-app/harness-webapp`
4. Click **Apply Changes**

> **Expression Syntax**: `<+pipeline.sequenceId>` is a Harness expression that provides the pipeline execution number. This ensures each build creates a uniquely tagged Docker image.

## Step 7: (Optional) Enable Cache Intelligence and Build Intelligence

If you're using **Harness Cloud** for builds, you can enable both Cache Intelligence and Build Intelligence to speed up subsequent builds:

1. Return to the **Build** stage **Overview** tab
2. Scroll down to the **Cache Intelligence** section
3. Toggle **Enable Cache Intelligence** to ON
4. Scroll down to the **Build Intelligence** section
5. Toggle **Enable Build Intelligence** to ON
6. Click **Continue**

![](images/2025-12-16_13-43-00.jpg)

> **What is Cache Intelligence?**
> Cache Intelligence automatically caches common dependencies to improve build times:
> - Speeds up builds by 40-60% on average
> - No configuration required - works automatically
> - Caches package manager dependencies (npm, pip, maven, etc.)
> - Available with Harness Cloud
>
> **What is Build Intelligence?**
> Build Intelligence automatically caches build outputs to improve build time:
> - Caches compiled artifacts and build outputs between runs
> - Reduces redundant compilation and processing
> - Currently supported on both Cloud and Kubernetes build infrastructure
> - Works seamlessly with Cache Intelligence for maximum performance

## Step 8: Save and Run the Pipeline

1. Click **Save** in the top right
2. Click **Run**
3. Select **Branch**: `main`
4. Click **Run Pipeline**

## Monitor the Execution

Watch the pipeline execute:
- ✅ **Test Intelligence** - Runs Python tests
- ✅ **Compile** - Builds the Angular frontend
- ✅ **Push to Dockerhub** - Builds and pushes the Docker image

> **First Run**: The first execution will run all tests. Subsequent runs will use Test Intelligence to run only relevant tests based on code changes.

## Verify the Results

1. **Check the pipeline execution** in Harness - all steps should be green
2. **Verify the Docker image** was pushed:
   - Visit: `https://hub.docker.com/r/dockerhubaccountid/harness-demo/tags`
   - You should see a new tag: `demo-base-1` (or higher sequence number)

## Key Takeaways

- **Multiple infrastructure options** - Choose Harness Cloud or Kubernetes based on your needs
- **Harness Cloud** requires account verification but provides the best experience
- **Test Intelligence** optimizes test execution for faster feedback
- **Templates** standardize build processes across teams
- **Docker integration** makes artifact management seamless
- **Cache Intelligence** (Harness Cloud only) dramatically speeds up builds
- **Pipeline as Code** can be stored inline or in Git

## Build Infrastructure Comparison

<table style="width:100%; border-collapse: collapse; border: 2px solid #555;">
  <thead>
    <tr style="background-color: #2a2a2a; border-bottom: 3px solid #666;">
      <th style="padding: 12px; text-align: left; border: 1px solid #555; font-weight: bold;">Feature</th>
      <th style="padding: 12px; text-align: left; border: 1px solid #555; font-weight: bold;">Harness Cloud</th>
      <th style="padding: 12px; text-align: left; border: 1px solid #555; font-weight: bold;">Kubernetes</th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid #555;">
      <td style="padding: 12px; border: 1px solid #555;"><strong>Setup Required</strong></td>
      <td style="padding: 12px; border: 1px solid #555;">None</td>
      <td style="padding: 12px; border: 1px solid #555;">Minimal (connector)</td>
    </tr>
    <tr style="border-bottom: 1px solid #555;">
      <td style="padding: 12px; border: 1px solid #555;"><strong>Account Requirements</strong></td>
      <td style="padding: 12px; border: 1px solid #555;">Verified account</td>
      <td style="padding: 12px; border: 1px solid #555;">Any account</td>
    </tr>
    <tr style="border-bottom: 1px solid #555;">
      <td style="padding: 12px; border: 1px solid #555;"><strong>Performance</strong></td>
      <td style="padding: 12px; border: 1px solid #555;">Fastest (bare-metal)</td>
      <td style="padding: 12px; border: 1px solid #555;">Depends on cluster</td>
    </tr>
    <tr style="border-bottom: 1px solid #555;">
      <td style="padding: 12px; border: 1px solid #555;"><strong>Scaling</strong></td>
      <td style="padding: 12px; border: 1px solid #555;">Automatic</td>
      <td style="padding: 12px; border: 1px solid #555;">Manual/cluster-dependent</td>
    </tr>
    <tr style="border-bottom: 1px solid #555;">
      <td style="padding: 12px; border: 1px solid #555;"><strong>Cache Intelligence</strong></td>
      <td style="padding: 12px; border: 1px solid #555;">✅ Yes</td>
      <td style="padding: 12px; border: 1px solid #555;">❌ No</td>
    </tr>
    <tr style="border-bottom: 1px solid #555;">
      <td style="padding: 12px; border: 1px solid #555;"><strong>Cost</strong></td>
      <td style="padding: 12px; border: 1px solid #555;">Pay-as-you-go</td>
      <td style="padding: 12px; border: 1px solid #555;">Use existing infrastructure</td>
    </tr>
  </tbody>
</table>

## Pipeline Configuration Summary

Your pipeline now has these components:
- **Build** stage with:
  - Infrastructure: Harness Cloud or Kubernetes
  - Run Tests (pytest)
  - Compile Application (Angular build via template)
  - Docker Build & Push (to Docker Hub)
  - Cache Intelligence (optional, Harness Cloud only)

---
