# HOWTO: Set Up the Harness Partner Demo Kit

A start-to-finish checklist. Do the steps in order; each one says how to confirm it worked before moving on. Setup takes about 30–60 minutes the first time, mostly downloads.

If several people are sharing one Harness project (a workshop), the **workshop lead** does [Part A](#part-a-workshop-lead-once-for-everyone) first, and everyone else starts at [Part B](#part-b-everyone-before-running-the-script).

---

## Part A: Workshop lead (once, for everyone)

Skip this part if you're setting up the demo just for yourself in your own Harness account.

1. **Choose the project.** Have an org admin create one Harness project for the workshop (any name), in the org you'll use. Note its **display name** exactly as shown in the Harness UI.
2. **Grant access.** In the project's access-control settings, give every participant the **Project Admin** role on that project. Project Admin is enough; participants don't need org rights. (Participants must already be users in the Harness account.)
3. **Assign participant IDs.** Give each person a unique short ID: 1–20 lowercase letters/digits, starting with a letter (e.g. `alex`, `sam2`). It's appended to everything that person's setup creates, so two people must never share an ID.
4. **Send each participant:**
   - Harness **account ID** (from any Harness URL: `https://app.harness.io/ng/account/<ACCOUNT_ID>/...`)
   - **org identifier** — the *identifier*, not the display name; it's the part after `/orgs/` in the project's URL
   - **project display name**
   - their **participant ID**

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

**Linux / Windows**: install Docker (with buildx), kubectl, helm, Terraform (or OpenTofu), and a local Kubernetes (minikube, Docker Desktop, or Rancher Desktop). Windows users run the scripts from Git Bash or WSL2 — see the README's Windows section.

**Check:**
```bash
docker --version && docker buildx version && kubectl version --client && helm version && terraform version
```
All five should print versions. (`docker buildx version` failing on a Mac means the `ln -sfn` line above wasn't run.)

### B3. Create your Harness API token (the most common mistake)

1. **If your Harness login belongs to more than one account, switch to the right one first** (use the account switcher in the Harness UI, and check the account ID in the URL). Tokens only work in the account they were created in.
2. Profile icon (bottom-left) → **My API Keys & Tokens** → **+ API Key** (any name).
3. On that key, click **+ Token** → give it an expiry → **Generate** → **copy it now** (it's shown once).

**Check:** the token looks like `pat.<ACCOUNT_ID>.<letters>.<letters>` and the second part equals your account ID. An *API key* on its own is **not** a token.

### B4. Create your Docker Hub token

At https://hub.docker.com/settings/security create a **personal access token** with **Read, Write, Delete** access, and copy it (it's shown once).

### B5. Get the code

```bash
git clone <repository URL you were given>
cd partner-demo-kit
```
If you were told to use a specific branch: `git checkout <branch>`.

### B6. Pre-configure (only if your org isn't `default`)

The script asks for most settings, but it does **not** ask for the Harness org — it assumes `default`. If the org identifier you were given is anything else, create the settings file **before** the first run (from inside the repo folder):

```bash
echo "HARNESS_ORG_ID=<org identifier>" >> .demo-config
```

`.demo-config` is ignored by git and holds your settings and tokens; never commit or share it. Other values you can pre-set the same way (otherwise you're prompted):

| Key | Example | Meaning |
|---|---|---|
| `HARNESS_ACCOUNT_ID` | `AbCdEf123...` | Harness account ID |
| `HARNESS_ORG_ID` | `my_org` | Org identifier (default `default`) |
| `PARTICIPANT_ID` | `alex` | Your participant ID (leave out if you're the only user of the project) |
| `COLIMA_ARCH_MODE` | `native` | Apple Silicon only: `native` (recommended) or `amd64` |

---

## Part C: Run the setup

```bash
chmod +x start-demo.sh stop-demo.sh
./start-demo.sh
```

Prompts you'll see, and what to answer:

| Prompt | Answer |
|---|---|
| *How should Colima run Kubernetes…* (Apple Silicon) | **1** — native (fast). Only choose 2 if told to. |
| *Install missing dependencies?* | **Y** |
| *Enter your Harness Project name* | The project **display name** exactly (shared project), or a new name for your own project |
| *Participant ID (optional)* | Your participant ID; **leave empty** only if nobody else uses the project |
| Docker Hub username / password | Your Docker Hub username and the **token** from B4 |
| Harness Account ID | From your lead or your Harness URL |
| Harness PAT | The token from B3 |
| *Install docker-buildx now?* | **Y** |
| *Install it into this cluster now with Helm?* (delegate) | **Y** |

The first run takes a while: the Colima VM and images download, three Docker images build, Terraform creates about 14 Harness resources, and the delegate installs and connects.

**If the script stops at "Pre-flight Checks"**, it tells you exactly what's wrong:

| Message | Fix |
|---|---|
| *token doesn't look like a token* | You copied an API key, not a token — redo B3 step 3 |
| *token belongs to account X, but the configured account is Y* | Switch accounts in the UI and create the token there (B3 step 1) |
| *Organization 'X' not found* | Set the right org (B6); the message lists the orgs you can see |
| *You lack these permissions in project…* | Ask your lead to make you Project Admin (Part A step 2) |
| *You can't create projects in org…* | Ask an admin to create the project; enter its exact name |
| *Connector … already exists … isn't in your local Terraform state* | Someone else is using your participant ID — ask your lead for another, then `./start-demo.sh --participant <id>` |

---

## Part D: Check it worked

1. **Lab guides** open at http://localhost:30001 and show your project (and participant) names.
2. **Delegate**: `kubectl get pods -n harness-delegate-ng` shows your delegate (`<participant>-k8s-delegate`, or `local-k8s-delegate`) as `1/1 Running`, and Harness → Project Settings → **Delegates** shows it **Connected**.
3. **Connectors**: Harness → Project Settings → **Connectors** → open your `Workshop K8s …` and `Prometheus …` connectors → **Test Connection** → both succeed.

Then follow the labs in order, starting with Lab 0's verification section.

---

## Part E: Re-running and cleaning up

- **Re-run** any time: `./start-demo.sh`. Faster variants: `--skip-docker-build` (reuse images), `--skip-terraform` (Harness resources unchanged), `--skip-delegate`.
- **Delegate disappeared** (e.g. after restarting your cluster): `./start-demo.sh --skip-docker-build --skip-terraform` reinstalls it.
- **Stop for the day**: `./stop-demo.sh` → option 1. Your Harness resources stay.
- **Remove your Harness resources**: `./stop-demo.sh --delete-harness-project`. In a shared or admin-created project this removes **only your** resources — the project itself and other people's resources are never deleted.

---

## More detail

- [SETUP-IMPROVEMENTS.md](SETUP-IMPROVEMENTS.md) — what the scripts do and why (native Colima, buildx, delegate automation, shared projects, pre-flight checks).
- [PREEXISTING-PROJECT-SUPPORT.md](PREEXISTING-PROJECT-SUPPORT.md) — reusing an admin-created project and non-default orgs.
- [README.md](README.md) — full reference, manual setup, troubleshooting.
