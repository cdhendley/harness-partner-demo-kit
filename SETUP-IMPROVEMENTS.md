# Setup improvements: Apple Silicon, shared projects, automatic delegate

This builds on [PREEXISTING-PROJECT-SUPPORT.md](PREEXISTING-PROJECT-SUPPORT.md) (reusing an admin-created project in any org). It fixes several problems that make the kit slow or confusing on Apple Silicon Macs and in team workshops.

## Summary

| Area | Before | After |
|---|---|---|
| Colima on Apple Silicon | Forced an x86_64 VM, which runs under **qemu software emulation** (slow, heavy, can crash) | **Native arm64** by default (Apple Virtualization.framework); amd64 emulation still selectable |
| Image builds | `docker build` = whatever the VM's architecture is; Homebrew's docker CLI silently uses the deprecated legacy builder | **buildx**, multi-arch (`linux/amd64,linux/arm64`) under one tag |
| Delegate | Copy a Helm command from the UI; the guide's rename doesn't reach the command; easy to stop after the repo lines | **Installed by the script** with the right name, token, endpoint and image; waits until connected |
| Many people, one project | Fixed identifiers collide on the second `terraform apply`; same-named delegates share tasks across laptops | **Participant ID** suffixes every resource and the delegate; lab guides personalized per person |
| Token problems | Surface as a 403 midway through `terraform apply` | **Pre-flight checks** before Terraform with plain-language fixes |
| Cleanup | `terraform destroy` deleted an imported (pre-existing/shared) project — for everyone | Never deletes a project it didn't create or that is shared |
| Docs site | Only deployed when images were built; rebuilt image not picked up | Deployed every run; always pulls the moving `docs-latest` tag |

## 1. Native Colima on Apple Silicon

`colima start --vm-type=vz --vz-rosetta --arch x86_64` looks like it uses Apple's hypervisor with Rosetta, but on Apple Silicon an `x86_64` VM can't run on Virtualization.framework: Lima silently switches to **qemu** with software CPU emulation (`~/.colima/_lima/<profile>/lima.yaml` shows `vmType: qemu`, and a `qemu-system-x86_64 -accel tcg` process runs). `colima status` still reports Virtualization.framework. Everything — Kubernetes, the delegate, Docker builds — runs emulated. In testing, the guest kernel panicked during an image build (visible only in Lima's `serial.log`).

Now `start-demo.sh` asks once (default native) and remembers the answer as `COLIMA_ARCH_MODE`:

```bash
./start-demo.sh                      # prompts on Apple Silicon (default: native)
./start-demo.sh --colima-arch amd64  # opt into emulation
```

Native uses `--vm-type=vz --vz-rosetta --arch aarch64`. amd64-only images (for example a frontend built on Harness Cloud) still run, translated by Rosetta. qemu is only installed/required in amd64 mode.

The script checks the architecture the Docker daemon actually reports (`docker info --format '{{.Architecture}}'`), not Colima's config. Switching architecture recreates the VM **with `colima delete --data`**: plain `colima delete` keeps the data disk, and a new VM booting the old cluster's data leaves k3s crash-looping (node not found, stale pods, CNI errors).

Measured with the full stack idle (k3s, delegate, Prometheus, docs) natively: the VM uses roughly 12% of one host core and ~3 GB of memory.

## 2. buildx multi-architecture images

Backend, test and docs images are built with BuildKit for `linux/amd64` and `linux/arm64` and pushed under the same tags, so they run on Harness Cloud (amd64) and on native Apple Silicon clusters. A `docker-container` builder (`harness-demo-builder`) is created once. If a multi-arch build fails, the script retries for the local architecture; without buildx it falls back to the legacy builder with a warning. Homebrew's `docker` CLI ships without buildx; the script offers `brew install docker-buildx`. Override platforms with `DEMO_BUILD_PLATFORMS`.

All base images (`python:3.11-slim`, `node:20-alpine`, `nginx:alpine`, `prom/prometheus`) and the Harness delegate image publish arm64 variants; backend and test images build cleanly for both architectures.

## 3. Automatic delegate installation

After Terraform, the script checks whether the delegate the connectors expect is connected and, if not, installs it with Helm using values from the Harness API — no copy-paste:

| Value | Source |
|---|---|
| `delegateToken` | `GET /ng/api/delegate-token-ng/delegate-token-value?…&delegateTokenName=default_token` (the UI command's token is base64 of this value) |
| `delegateDockerImage` | `GET /ng/api/delegate-setup/latest-supported-version` → `…/harness/delegate:<version>` |
| `managerEndpoint` | `GET /ng/api/accounts/{id}` → `cluster`: `prod-2` → `https://app.harness.io/gratis`, `prod-1` → `https://app.harness.io`; anything else falls back with a warning (override with `HARNESS_MANAGER_ENDPOINT`) |
| connected? | `POST /ng/api/delegate-setup/listDelegates` |

The name is `local-k8s-delegate`, or `<participant>-k8s-delegate` (see below) — always the name the connectors select. `--skip-delegate` skips this step. `helm` is now a checked prerequisite. Lab 0 keeps a manual fallback that spells out all three commands and both places the name must be set.

## 4. Several people sharing one project

Projects are cheap, but asking an admin for one per participant doesn't scale for a workshop. With a **participant ID** (1–20 lowercase letters/digits, e.g. `alex`; `--participant <id>` or prompted once), Terraform's new `participant_id` variable appends `_<id>` to every identifier and ` <id>` to every name the kit creates:

`partner_demo_kit_alex`, `workshop_k8s_alex` ("Workshop K8s alex"), `workshopdocker_alex`, `prometheus_alex`, `docker_username_alex`, `DOCKER_PAT_alex`, `Compile_Application_alex`, `dev_alex`/`prod_alex`, `k8s_dev_alex`, `backend_alex`, `backend_dev_alex`/`backend_prod_alex`, and the delegate `alex-k8s-delegate`.

Delegates are grouped by name within a scope, and Harness sends a task to any connected instance, so unique delegate names also keep each person's deployments on their own cluster.

The lab guides use `{{ID}}`, `{{NAME}}` and `{{DELEGATE}}` tokens that the script fills in when it builds each person's docs image, so everyone reads their own names; pipelines, services and policies created during the labs are suffixed too. An empty participant ID produces exactly the original names (verified: `terraform plan` against an existing single-user state shows no changes).

The script refuses to continue if this participant's connector already exists in the project but not in local state (someone else using the same ID, or a lost state).

## 5. Pre-flight checks

Before Terraform runs, `harness_preflight` checks:
- the token is `pat.<account>.<id>.<secret>` (an API *key* alone is not a token);
- the token's account segment matches `HARNESS_ACCOUNT_ID` (tokens are per-account);
- the org exists (otherwise lists the orgs you can see);
- permissions via `POST /authz/api/acl`: `core_project_create` for a new project, or connector/secret/template/environment/service/monitored-service/code-repo edit rights for an existing one.

Bypass with `DEMO_SKIP_PREFLIGHT=true`.

## 6. Safe cleanup

When the kit reuses a project it didn't create, it records `PROJECT_PREEXISTING=true`. `stop-demo.sh` treats such a project — or any run with a participant ID — as shared: it removes `harness_platform_project` from Terraform state before `destroy` (so only that user's resources are destroyed), refuses the API "delete project" fallback, uses `HARNESS_ORG_ID` instead of `default`, and deletes that participant's pipeline. Verified on a copy of a real state: `plan -destroy` went from 14 resources (including the project) to 13.

`stop-demo.sh` also no longer `source`s `.demo-config` (a value containing a space, like the default project name, would run as a command), and its "fresh start" now uses `colima delete -f --data`.

## 7. Smaller fixes

- Docs are personalized in a temporary copy (the repo's markdown is no longer edited and reverted), deployed on every run including `--skip-docker-build`, with `imagePullPolicy: Always` and a rollout restart so a rebuilt `docs-latest` is actually pulled.
- First-run Docker credentials are saved even when `.demo-config` already has other keys.
- Lab guides: the Docker connector was called `workshop-docker` (no such name; it's "Workshop Docker"); Lab 7 references a `K8s Prod` infrastructure the kit doesn't create — now noted.

## Verification

- `scripts/demo-lib.sh`: 53 unit/integration tests (bash 3.2), shellcheck clean.
- Terraform: `validate`; empty participant ID → no changes on an existing state; participant `zz` → all 14 resources suffixed; invalid IDs rejected.
- End to end on Apple Silicon (native Colima): rerun on an existing single-user setup (pre-flight passes, `0 added, 0 changed, 0 destroyed`, docs deployed, delegate detected); a second participant in the same project (see the PR description for results).
- Not verifiable here: delegate `managerEndpoint` for Harness clusters other than prod-1/prod-2; Linux/Windows runs; current Harness UI menu names referenced by the labs.

## New flags and settings

| Flag / variable | Purpose |
|---|---|
| `--colima-arch native\|amd64` | Apple Silicon VM mode (saved as `COLIMA_ARCH_MODE`) |
| `--participant <id>` | Share a project (saved as `PARTICIPANT_ID`) |
| `--skip-delegate` | Don't install the delegate |
| `DEMO_SKIP_PREFLIGHT=true` | Skip pre-flight checks |
| `DEMO_BUILD_PLATFORMS` | buildx platforms (default `linux/amd64,linux/arm64`) |
| `HARNESS_MANAGER_ENDPOINT` | Override the delegate's manager endpoint |
| `participant_id`, `delegate_name` | Terraform variables in `kit/main.tf` |
