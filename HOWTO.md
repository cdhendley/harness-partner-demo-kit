# HOWTO: Set Up the Harness Partner Demo Kit

A start-to-finish checklist. Do the steps in order; each one says how to confirm it worked before moving on. Setup takes about 30–60 minutes the first time, mostly downloads.

If several people are sharing one Harness project (a workshop), the **workshop lead** does [Part A](#part-a-workshop-lead-once-for-everyone) first, and everyone else starts at [Part B](#part-b-everyone-before-running-the-script).

**Already ran `./start-demo.sh` and it failed?** Go to [Part F](#part-f-already-ran-it-and-it-failed).

**Have two tokens ready before you start**: a Harness API token ([B3](#b3-create-your-harness-api-token-the-most-common-mistake)) and a Docker Hub access token ([B4](#b4-create-your-docker-hub-access-token)). The script asks for each once, checks it on the spot, and remembers it.

---

## ⚠️ Shared project? Read this before running `stop-demo.sh`

**Older copies of this kit delete the entire Harness project when you run `stop-demo.sh`'s Harness cleanup — everyone's resources, pipelines and work, not just yours.** In a shared workshop project that means wiping out every other participant.

The current version is safe:

| `stop-demo.sh` choice | What it touches |
|---|---|
| Options **1–3** (the default is 1) | **Only your own laptop**: local Kubernetes deployments, Prometheus, stopping your cluster |
| Options **4–5**, `--delete-harness-project`, `--full-cleanup` | Your laptop, plus the Harness resources **you** created (and your Docker Hub repo). It **never** deletes a shared or admin-created project, and never touches other participants' resources — even though its menu text says "Removes: Harness project" |
| Option **6** (force delete via API) | In a shared or admin-created project it refuses to delete anything in Harness (it only cleans up your laptop and Docker Hub repo) |

Rules for a shared project:
1. **Make sure you have the current version** before running `stop-demo.sh` at all: `git pull` (or the branch your lead gave you).
2. **If you're not sure which version you have, only use options 1–3.**
3. **Leave removing Harness resources to your workshop lead.**



---

## Part A: Workshop lead (once, for everyone)

Skip this part if you're setting up the demo just for yourself in your own Harness account.

1. **Choose the project.** Have an org admin create one Harness project for the workshop (any name), in the org you'll use. Participants pick it from a list when the script runs, so there is nothing to copy exactly.
2. **Grant access.** In the project's access-control settings, give every participant the **Project Admin** role on that project. Project Admin is enough; participants don't need org rights. (Participants must already be users in the Harness account.)
3. **Name/IDs.** Each person types a short name/ID of their own when the script asks — their first name or initials, e.g. `alex` (lowercase letters/digits, starting with a letter, max 20). It's appended to everything that person's setup creates, so no two people may use the same one; the script refuses a name/ID that is already in use in the project.
4. **Send each participant:**
   - Harness **account ID** (from any Harness URL: `https://app.harness.io/ng/account/<ACCOUNT_ID>/...`)
   - the **org** and **project** names (both are picked from a list; the project is the only one they are Project Admin on)

5. **Import the demo code repository once (recommended).** In the project: **Code Repository** → dropdown next to **New Repository** → **Import Repository** → repository `harness-community/partner-demo-kit`, name `partner_demo_kit`, tick **Requires Authorization** and enter a GitHub token. Everyone's setup then reuses this one repository. Without it, each person's first run imports it from GitHub itself, and Harness's anonymous GitHub access is throttled, so some runs fail at that step (see Part F).

Each participant runs everything on their **own laptop**, with their own local Kubernetes cluster and their own Docker Hub account.

---

## Part B: Everyone, before running the script

### B1. Accounts you need

| Account | What you need | Check |
|---|---|---|
| **Harness** | A user in the right account. For a shared project: Project Admin on it. For your own project: permission to create projects. | You can open the project in the Harness UI |
| **Docker Hub** | An account and a repository named **`harness-demo`** (https://hub.docker.com/repository/create) | The repository shows under your Docker Hub repositories |

### B2. Install the tools

**macOS (Apple Silicon or Intel)** — with [Homebrew](https://brew.sh):
```bash
brew install colima docker kubectl helm terraform docker-buildx
mkdir -p ~/.docker/cli-plugins && ln -sfn "$(brew --prefix)/opt/docker-buildx/bin/docker-buildx" ~/.docker/cli-plugins/docker-buildx
```

**Linux / Windows**: install Docker (with buildx), kubectl, helm, Terraform (or OpenTofu), Python 3 (callable as `python3`), and a local Kubernetes (minikube, Docker Desktop, or Rancher Desktop). Windows users run the scripts from Git Bash or WSL2 — the README's [Windows section](README.md#windows-users---important-setup-notes) has the `winget` commands, minikube install steps and the Python check.

**Check:**
```bash
docker --version && docker buildx version && kubectl version --client && helm version && terraform version && python3 --version
```
All six should print versions. (`docker buildx version` failing on a Mac means the `ln -sfn` line above wasn't run.)

### B3. Create your Harness API token (the most common mistake)

1. **If your Harness login belongs to more than one account, switch to the right one first** (use the account switcher in the Harness UI, and check the account ID in the URL). Tokens only work in the account they were created in.
2. Profile icon (bottom-left) → **My API Keys & Tokens** → **+ API Key** (any name).
3. On that key, click **+ Token** → give it an expiry → **Generate** → **copy it now** (it's shown once).

**Check:** the token looks like `pat.<ACCOUNT_ID>.<letters>.<letters>` and the second part equals your account ID. An *API key* on its own is **not** a token.

### B4. Create your Docker Hub access token

At https://hub.docker.com/settings/security → **Personal access tokens** → **Generate new token**, access **Read & Write**; copy it (it's shown once). Also know your Docker Hub **username** (not your email address).

You'll paste the token when the script asks for the *Docker Hub access token*. Being logged in to Docker Desktop on your laptop is **not** enough: Harness (its Docker connector, which the Lab 2 pipeline uses to push images) and your cluster's image pulls need the token itself, and the script stores it for them.

### B5. Get the code

```bash
git clone <repository URL you were given>
cd partner-demo-kit
```
If you were told to use a specific branch: `git checkout <branch>`.

### B6. Have these ready

- Harness **account ID** (from your lead, or any Harness URL: `https://app.harness.io/ng/account/<ACCOUNT_ID>/...`)
- Harness **API token** (B3)
- Docker Hub **username** and **access token** (B4)
- the **name/ID** you'll use: just your first name or initials, e.g. `alex`

Nothing to pre-configure: the script asks for everything (organization and project from numbered lists, your name/ID, the tokens) and remembers your answers in `.demo-config` for the next run, offering them as defaults — just press Enter to keep them. `.demo-config` is ignored by git and holds your tokens: never commit or share it.

---

## Part C: Run the setup

```bash
chmod +x start-demo.sh stop-demo.sh
./start-demo.sh
```

Prompts you'll see, and what to answer:

| Prompt | Answer |
|---|---|
| *Install missing dependencies?* / *Install docker-buildx now?* | **Y** |
| *Harness account ID* | From your lead or your Harness URL |
| *Paste your Harness API token* | The token from B3 (starts with `pat.`) |
| *Organization* (a numbered list) | Type the number of your workshop's org |
| *Harness project for the demo* (a numbered list) | Type the number of the workshop project. The list shows only projects where you are Project Admin |
| *Your name/ID* | Just your name, e.g. `alex` (lowercase letters/digits, starting with a letter, max 20). Use the same one every run. Type `none` only if nobody else uses the project |
| *Build images?* | **Y** on your first run, after code changes, or after changing your project or name/ID; otherwise **n** saves time |
| *Enter your Docker Hub username* | Your Docker Hub username, not your email (skipped if Docker Desktop already knows it) |
| *Docker Hub access token* | The token from B4. Being logged in to Docker Desktop is not enough — Harness needs the token itself |
| *Restart Colima with 4 CPUs and 8GB memory?* / *Recreate Colima as 'native' now?* (Apple Silicon) | **Y** |
| *IaC state file exists … Choose [1/2]* (re-runs only) | **2** (re-run Terraform) unless you're sure nothing changed |
| *Install it into this cluster now with Helm?* (delegate) | **Y** |

**If a token is rejected when you paste it**, the message says why (*That isn't an API token*, *looks incomplete*, *Harness rejected this token*, *Docker Hub rejected it*). Fix it and paste again; nothing is saved until it's accepted.

The first run takes a while: the Colima VM and images download, three Docker images build, Terraform creates about 14 Harness resources, and the delegate installs and connects.

**If the script stops at "Pre-flight Checks"**, it tells you exactly what's wrong:

| Message | Fix |
|---|---|
| *That isn't an API token* | You pasted an API key (or its name), not a token — redo B3 step 3 |
| *token belongs to account X, but the configured account is Y* | Switch accounts in the UI and create the token there (B3 step 1) |
| *Organization 'X' not found* | Re-run and pick the org from the numbered list |
| *You lack these permissions in project…* | Ask your lead to make you Project Admin (Part A step 2) |
| *You don't have Project Admin rights on any project in organization…* | Wrong org, or you haven't been made Project Admin yet (Part A step 2) |
| *The name/ID '…' is already taken in project…* | Someone else already uses that name/ID — the script asks you for a different one (add an initial, e.g. `alexm`) |

If a check fails, the script asks *Continue anyway? [y/N]* — answer **N**, fix the problem, and run it again.

---

## Part D: Check it worked

1. **Lab guides** open at http://localhost:30001 and show your project name and your name/ID.
2. **Delegate**: `kubectl get pods -n harness-delegate-ng` shows your delegate (`<name/ID>-k8s-delegate`, or `local-k8s-delegate`) as `1/1 Running`, and Harness → Project Settings → **Delegates** shows it **Connected**.
3. **Connectors**: Harness → Project Settings → **Connectors** → open your `Workshop K8s …`, `Workshop Docker …` and `Prometheus …` connectors → **Test Connection** → all three succeed.
4. **Code repository**: Harness → **Code Repository** shows `partner_demo_kit` (one repository, shared by everyone in the project).

Then follow the labs in order, starting with Lab 0's verification section.

---

## Part E: Re-running and cleaning up

- **Re-run** any time: `./start-demo.sh`. Your previous answers are offered as defaults; answer **n** to *Build images?* and **1** (skip) to the Terraform question to make it quick.
- **Delegate disappeared** (e.g. after restarting your cluster): just re-run `./start-demo.sh` — it notices and offers to reinstall it.
- **New Docker Hub token** (old one expired or revoked): re-run and answer **2** to the Terraform question; the script notices the saved token is rejected, asks for the new one, and updates the Harness secret.
- Experienced users can pre-answer questions with flags (`--skip-docker-build`, `--skip-terraform`, `--skip-delegate`, `--org <id>`, `--participant <id>`, `--colima-arch native|amd64`); nobody *needs* them.
- **Stop for the day**: `./stop-demo.sh` → option **1** (local only; your Harness resources stay). Read the shared-project warning at the top of this guide first.
- **Remove your Harness resources**: in a shared project, leave this to your workshop lead. (With the current version, `./stop-demo.sh --delete-harness-project` removes only the resources *you* created; older versions delete the whole project.)

---

## Part F: Already ran it and it failed?

Re-running `./start-demo.sh` is safe: it reuses what already exists and only creates what's missing. Don't delete the Harness project or files in the repo to "start clean" — fix the cause below, then run it again (when asked about the existing Terraform state, answer **2** to re-run Terraform).

**First, make sure you have the current version of the kit.** Older copies don't have the pre-flight checks, organization prompt, shared-project support or automatic delegate install, and fail in the ways described below. From the repo folder: `git pull` (or `git checkout <branch>` if your lead gave you one), then re-run.

Find the error text you saw:

### `403 Forbidden` — usually on `harness_platform_project.base_demo: Creating...`

The Harness token can't do what Terraform asked. In order of likelihood:

1. **You created an API key but not a token.** A key on its own isn't usable. Profile → **My API Keys & Tokens** → your key → **+ Token** → copy the `pat.…` value. When the script asks for the Harness PAT, paste the token.
2. **The token is from a different Harness account.** If your login belongs to several accounts, switch to the project's account in the UI *before* creating the token. The second part of the token (`pat.<THIS PART>.…`) must equal your account ID.
3. **An old copy of the kit tried to create a new project.** The current version has you pick the existing project from a list of the ones you're Project Admin on, and never tries to create one unless you have that permission. Update (`git pull`) and re-run.
4. **Wrong organization.** Older versions assumed an org named `default`. Re-run and pick the right org from the numbered list.

The current script checks all four before Terraform runs and tells you which one it is.

### `401 Unauthorized`, or *"token is not valid"*

The token expired, was revoked, or is an API key. Create a new token (B3) and paste it when the script asks — it re-asks automatically when the saved one stops working.

### *"Connector … already exists"* / Terraform says a resource *already exists*

Someone else in the project already created resources with your names — usually you both typed `none`, or the same name/ID. Re-run; the script detects this and asks you for a different name/ID (add an initial, e.g. `alexm`).

### *"Access denied to harness-community/partner-demo-kit at github"*

Harness couldn't fetch the demo code repository from GitHub (its anonymous GitHub access gets throttled). The script retries a few times by itself. If it still fails: in the Harness UI open the project → **Code Repository** → dropdown next to **New Repository** → **Import Repository**, repository `harness-community/partner-demo-kit`, name `partner_demo_kit`, tick **Requires Authorization** and enter a GitHub token; then re-run the script, which reuses that repository. Workshop leads can do this import once per project up front so nobody hits it.

### *"terraform init failed"* with no other output

The script's temporary working folder had disappeared mid-run (cause not yet found). Re-run; it starts with a fresh one.

### Docker Hub token rejected, *Workshop Docker* connector test fails, or the Lab 2 push fails with *invalid credentials*

The script checks your Docker Hub access token with Docker Hub the moment you paste it, so a bad one is caught at the prompt: create a new token (B4) and make sure the username is your Docker Hub username, not your email.

If the **Workshop Docker** connector or the Lab 2 image push fails with invalid credentials, your setup was done with an older copy of the kit, which stored a placeholder instead of your token when Docker Desktop was already logged in. Update (`git pull`), re-run, answer **2** to the Terraform question; the script asks for the token and updates the Harness secret.

To be asked for everything again, delete the saved answers with `rm .demo-config` and re-run.

### Everything is extremely slow, or *"connection to the server … was refused"* (Apple Silicon)

Your Colima VM is probably running in **amd64 emulation** (software-emulated x86 — very slow, and it has crashed mid-build). Re-run `./start-demo.sh`; it switches to native arm64 automatically. Switching rebuilds the Colima VM and its Kubernetes cluster from scratch (your Harness resources are untouched; the script redeploys the local pieces). The first rebuild takes a few minutes.

### http://localhost:30001 doesn't load

- Re-run `./start-demo.sh` — it deploys the docs on every run.
- If the docs image was never built (your first run failed before the build), answer **Y** to *Build images?*.
- Check the pod: `kubectl get pods -l app=docs` should show `1/1 Running`.
- On Apple Silicon, if `kubectl get nodes` fails, your Colima VM may have stopped or restarted: see the previous item.

### Delegate missing, not connected, or connector tests fail

- Re-run `./start-demo.sh`; it detects a missing delegate and offers to install it (answer **Y**).
- If you installed it by hand: the delegate name must be exactly the one your connectors use (`<name/ID>-k8s-delegate`, or `local-k8s-delegate` if you typed `none`). A delegate with any other name installs and connects but connector tests fail. Running only the two `helm repo …` lines doesn't install anything — the long `helm upgrade -i …` command is the install.
- A new delegate needs 1–3 minutes before it shows **Connected**.

### *"helm: command not found"* / *"docker buildx … unknown"*

Install the tools from B2 (on a Mac, including the `ln -sfn` line for buildx), then re-run.

### Still stuck?

Send your lead:
- the last ~30 lines of the script's output (the error and what came just before it);
- the first two parts of your token only (`pat.<account>.…`) — **never the whole token**;
- your org, project name and name/ID.

---

## More detail

- [SETUP-IMPROVEMENTS.md](SETUP-IMPROVEMENTS.md) — what the scripts do and why (native Colima, buildx, delegate automation, shared projects, pre-flight checks).
- [PREEXISTING-PROJECT-SUPPORT.md](PREEXISTING-PROJECT-SUPPORT.md) — reusing an admin-created project and non-default orgs.
- [README.md](README.md) — full reference, manual setup, troubleshooting.
