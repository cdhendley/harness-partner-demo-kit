# Running the kit with a pre-existing project or non-default org

This branch changes `start-demo.sh` so the kit works in shared or partner Harness accounts where:

- the user **cannot create projects**, so an admin creates the project for them, and/or
- the account has **no `default` org**.

When neither applies, the script behaves exactly as before.

## The problem

The stock script assumes the user can create a project in the `default` org. In a shared account, that fails on the first resource:

```
harness_platform_project.base_demo: Creating...
Error: 403 Forbidden
Hint:
1) Please check if the token has required permission for this operation.
2) Please check if the token has expired or is wrong.
```

The hint points at the token, but the token is usually fine. The 403 comes from the **user's role**: permissions belong to the user, so generating a new PAT doesn't change anything. The fix is to have an admin create the project and grant the user **Project Admin**. Everything in `kit/main.tf` is project-scoped, so that role is enough.

Two things in the original script still blocked that route:

1. **The org was hardcoded.** `project_exists()` queried `orgIdentifier=default`, and the script never set `org_id` in `se-parms.tfvars`, so `kit/main.tf` fell back to `default`. Accounts without a `default` org failed.
2. **The project identifier was derived from the display name.** `name_to_identifier()` turns `My-Project` into `My_Project`, but an admin-created project may have a different identifier (for example `MyProject`). Typing the real project's name either targeted a project that didn't exist or was rejected as "already exists".

Even with the right identifier, the IaC would still try to **create** the project, because it isn't in state.

## Changes to `start-demo.sh`

All changes are in the Terraform/OpenTofu section.

### 1. Configurable org: `HARNESS_ORG_ID`

- Read from `.demo-config`. Defaults to `default` when missing.
- Written back to `.demo-config` on every run.
- Written to `kit/se-parms.tfvars` as `org_id = "..."`, which sets `var.org_id` in `kit/main.tf`.
- `project_exists()` now queries `orgIdentifier=${HARNESS_ORG_ID}`.

### 2. New helper: `find_project_by_name()`

Calls `GET /ng/api/projects?searchTerm=<name>` in the configured org. It prints the identifier of a project whose display name matches **exactly**, or nothing. Harness's `searchTerm` matches substrings, so the exact comparison happens locally.

### 3. Reuse an existing project instead of rejecting it

The name-validation loop now checks, after the reserved-word check and before deriving an identifier, whether a project with that exact name already exists:

- **Found:** the script uses that project's real identifier, sets `REUSE_EXISTING_PROJECT=true`, and prints `Found existing project '<name>' (identifier: <id>) - it will be reused`.
- **Not found:** unchanged behaviour. The script derives the identifier and runs the existing collision check before creating a new project.

Previously, a project that already existed with the entered name was treated as an error.

### 4. Import the reused project before `plan`

When `REUSE_EXISTING_PROJECT=true` and the project isn't already in state, the script runs:

```bash
$IAC_CMD import -var="pat=$HARNESS_PAT" -var-file="se-parms.tfvars" \
  harness_platform_project.base_demo "${HARNESS_ORG_ID}/${PROJECT_IDENTIFIER}"
```

It skips the import when the project is already in state, writes the output to `$TEMP_DIR/terraform_import.log`, and exits with the log tail if the import fails. After the import, `plan` shows the project as an in-place update (usually only a colour-case change, `#0063f7` → `#0063F7`) and creates everything else.

## How to use it

1. Ask an org admin to create the project and give you the **Project Admin** role on it.
2. Generate your PAT **in the same account** as the project. The account ID is the second field of the token: `pat.<accountId>.<keyId>.<secret>`.
3. If your org isn't `default`, add it to `.demo-config`:
   ```
   HARNESS_ORG_ID=<your_org_identifier>
   ```
4. Run:
   ```bash
   ./start-demo.sh --skip-docker-build
   ```
   When asked for the project name, enter the project's **display name** exactly as the admin created it.

`--skip-docker-build` is only needed if your images already exist. It also skips an early name prompt in the Docker section, which runs before the PAT is collected and can't look up existing projects (see below).

## Diagnosing a 403 quickly

The Harness API can tell you directly whether you're allowed to do something, which is much faster than repeated `apply` runs:

```bash
# Who am I, and which accounts do I belong to?
curl -s -H "x-api-key: $PAT" https://app.harness.io/ng/api/user/currentUser

# Am I allowed to create projects in this org? (response includes "permitted": true/false)
curl -s -H "x-api-key: $PAT" -H "Content-Type: application/json" -X POST \
  https://app.harness.io/authz/api/acl -d '{
    "principal": {"principalIdentifier": "<user uuid>", "principalType": "USER"},
    "permissions": [{
      "resourceScope": {"accountIdentifier": "<account id>", "orgIdentifier": "<org id>"},
      "resourceType": "PROJECT", "permission": "core_project_create"
    }]}'

# Which users or groups have admin roles in this org?
curl -s -H "x-api-key: $PAT" \
  "https://app.harness.io/authz/api/roleassignments?accountIdentifier=<account id>&orgIdentifier=<org id>&pageSize=50"
```

## Known gaps (not addressed here)

- **No org prompt or detection.** The org must be set by hand in `.demo-config`. `/ng/api/organizations` could list the orgs the user can see.
- **No up-front permission check.** A `core_project_create` ACL check before `apply` could replace the raw provider 403 with a clear message and a list of org admins to contact.
- **`apply` output isn't logged.** `init` and `plan` write to `$TEMP_DIR`, but `apply` only prints to the terminal.
- **Wrong identifier in lab docs.** The early project-name prompt in the Docker-build section derives the identifier, so with a pre-existing project the lab markdown can end up with the wrong identifier. Fixing this needs the PAT collected earlier, or the docs personalized again after the lookup.
