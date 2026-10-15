# shellcheck shell=bash
#
# Shared helpers for start-demo.sh / stop-demo.sh.
# Sourced, not executed. Must stay compatible with bash 3.2 (macOS default):
# no associative arrays, no ${var,,}, no mapfile.
#
# Expects the caller to define: print_status, print_error, print_info.

HARNESS_API_BASE="https://app.harness.io"
DELEGATE_NAMESPACE="harness-delegate-ng"
DELEGATE_HELM_REPO_NAME="harness-delegate"
DELEGATE_HELM_REPO_URL="https://app.harness.io/storage/harness-download/delegate-helm-chart/"
DELEGATE_IMAGE_REPO="us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate"
DEMO_BUILDER_NAME="harness-demo-builder"
DEMO_BUILD_PLATFORMS="${DEMO_BUILD_PLATFORMS:-linux/amd64,linux/arm64}"

# ---------------------------------------------------------------------------
# Small utilities
# ---------------------------------------------------------------------------

is_apple_silicon() {
  [ "$(uname -s)" = "Darwin" ] && { [ "$(uname -m)" = "arm64" ] || [ "$(uname -m)" = "aarch64" ]; }
}

# Read KEY=value from a config file (first match; value may contain '=')
config_get() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 0
  grep "^${key}=" "$file" 2>/dev/null | head -n1 | cut -d'=' -f2-
}

# Set KEY=value in a config file, replacing an existing line or appending
config_set() {
  local file="$1" key="$2" value="$3"
  touch "$file"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    python3 - "$file" "$key" "$value" <<'PYEOF'
import sys
path, key, value = sys.argv[1:4]
lines = open(path).read().splitlines()
out = [f"{key}={value}" if l.startswith(key + "=") else l for l in lines]
open(path, "w").write("\n".join(out) + "\n")
PYEOF
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
  chmod 600 "$file" 2>/dev/null || true
}

# Extract a dotted path from JSON on stdin (e.g. "data.uuid", "resource.0.name")
json_get() {
  python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    for k in sys.argv[1].split("."):
        d = d[int(k)] if isinstance(d, list) else (d or {}).get(k)
    print("" if d is None else d)
except Exception:
    pass' "$1" 2>/dev/null
}

harness_get() {
  curl -s -H "x-api-key: ${HARNESS_PAT}" "${HARNESS_API_BASE}$1"
}

harness_get_code() {
  curl -s -o /dev/null -w "%{http_code}" -H "x-api-key: ${HARNESS_PAT}" "${HARNESS_API_BASE}$1"
}

harness_post() {
  curl -s -X POST -H "x-api-key: ${HARNESS_PAT}" -H "Content-Type: application/json" \
    "${HARNESS_API_BASE}$1" -d "${2:-{\}}"
}

# ---------------------------------------------------------------------------
# Participant ID (several people sharing one Harness project)
# ---------------------------------------------------------------------------

# Valid: empty, or 1-20 lowercase letters/digits starting with a letter
is_valid_participant_id() {
  [ -z "$1" ] && return 0
  printf '%s' "$1" | grep -Eq '^[a-z][a-z0-9]{0,19}$'
}

# Turn free text ("Alex P.") into a candidate ID ("alexp")
normalize_participant_id() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9' | sed 's/^[0-9]*//' | cut -c1-20
}

participant_id_suffix()   { [ -n "$1" ] && printf '_%s' "$1"; return 0; }
participant_name_suffix() { [ -n "$1" ] && printf ' %s' "$1"; return 0; }

# Delegate name the Terraform connectors select (must match kit/main.tf locals)
delegate_name_for() {
  if [ -n "$1" ]; then printf '%s-k8s-delegate' "$1"; else printf 'local-k8s-delegate'; fi
}

# ---------------------------------------------------------------------------
# Harness pre-flight checks (token, account, org, permissions)
# ---------------------------------------------------------------------------

# Usage: harness_preflight ACCOUNT_ID ORG_ID PROJECT_ID PROJECT_EXISTS(true|false)
# Prints each check; returns 1 if anything would make Terraform fail.
harness_preflight() {
  local account="$1" org="$2" project="$3" project_exists="$4"
  local ok=true

  # 1. Token shape: pat.<accountId>.<tokenId>.<secret>
  local tok_prefix tok_account tok_parts
  tok_prefix=$(printf '%s' "$HARNESS_PAT" | cut -d'.' -f1)
  tok_account=$(printf '%s' "$HARNESS_PAT" | cut -d'.' -f2)
  tok_parts=$(printf '%s' "$HARNESS_PAT" | awk -F'.' '{print NF}')
  if [ "$tok_prefix" != "pat" ] || [ "$tok_parts" != "4" ]; then
    print_error "Harness token doesn't look like a token (expected pat.<account>.<id>.<secret>)"
    print_info "An API *key* is not a token: open the key under My API Keys & Tokens and click + Token"
    return 1
  fi
  if [ "$tok_account" != "$account" ]; then
    print_error "Harness token belongs to account '$tok_account', but the configured account is '$account'"
    print_info "Switch to account '$account' in the Harness UI and create the token there (tokens are per-account)"
    return 1
  fi
  print_status "Token format OK and matches account $account"

  # 2. Who am I
  local me
  me=$(harness_get "/ng/api/user/currentUser?accountIdentifier=${account}" | json_get "data.uuid")
  if [ -z "$me" ]; then
    print_error "Token was rejected by Harness (expired, revoked, or wrong account)"
    return 1
  fi

  # 3. Org exists and is visible
  if [ "$(harness_get_code "/ng/api/organizations/${org}?accountIdentifier=${account}")" != "200" ]; then
    print_error "Organization '$org' not found or not visible to you"
    local orgs
    orgs=$(harness_get "/ng/api/organizations?accountIdentifier=${account}&pageSize=50" | python3 -c '
import sys, json
try:
    print(", ".join(o["organization"]["identifier"] for o in json.load(sys.stdin)["data"]["content"]))
except Exception:
    pass' 2>/dev/null)
    [ -n "$orgs" ] && print_info "Orgs you can see: $orgs  (rerun and pick one at the Organization prompt)"
    return 1
  fi
  print_status "Organization '$org' found"

  # 4. Permissions
  local perms_json scope
  if [ "$project_exists" = true ]; then
    scope="{\"accountIdentifier\":\"${account}\",\"orgIdentifier\":\"${org}\",\"projectIdentifier\":\"${project}\"}"
    perms_json=""
    local pair
    for pair in CONNECTOR:core_connector_edit SECRET:core_secret_edit TEMPLATE:core_template_edit \
                ENVIRONMENT:core_environment_edit SERVICE:core_service_edit \
                MONITOREDSERVICE:chi_monitoredservice_edit CODE_REPOSITORY:code_repo_edit; do
      perms_json="${perms_json}{\"resourceScope\":${scope},\"resourceType\":\"${pair%%:*}\",\"permission\":\"${pair##*:}\"},"
    done
  else
    scope="{\"accountIdentifier\":\"${account}\",\"orgIdentifier\":\"${org}\"}"
    perms_json="{\"resourceScope\":${scope},\"resourceType\":\"PROJECT\",\"permission\":\"core_project_create\"},"
  fi
  local denied
  denied=$(harness_post "/authz/api/acl" \
    "{\"principal\":{\"principalIdentifier\":\"${me}\",\"principalType\":\"USER\"},\"permissions\":[${perms_json%,}]}" \
    | python3 -c '
import sys, json
try:
    acl = json.load(sys.stdin)["data"]["accessControlList"]
    print(" ".join(p["permission"] for p in acl if not p["permitted"]))
except Exception:
    print("UNKNOWN")' 2>/dev/null)
  if [ "$denied" = "UNKNOWN" ]; then
    print_info "Could not verify permissions (continuing; Terraform will report any 403)"
  elif [ -n "$denied" ]; then
    ok=false
    if [ "$project_exists" = true ]; then
      print_error "You lack these permissions in project '$project': $denied"
      print_info "Ask an org/project admin to make you Project Admin on '$project'"
    else
      print_error "You can't create projects in org '$org' (missing core_project_create)"
      print_info "Ask an org admin to create the project for you, then enter its exact name here"
    fi
  else
    print_status "Permissions OK"
  fi

  [ "$ok" = true ]
}

# Warn when this participant's resources already exist in the project but aren't in
# local Terraform state (someone else already uses this participant ID, or a lost state).
# Usage: participant_collision_check ACCOUNT ORG PROJECT PARTICIPANT_ID STATE_FILE
participant_collision_check() {
  local account="$1" org="$2" project="$3" pid="$4" state="$5"
  local conn
  conn="workshop_k8s$(participant_id_suffix "$pid")"
  if [ -s "$state" ] && grep -q "\"${conn}\"" "$state" 2>/dev/null; then
    return 0
  fi
  local code
  code=$(harness_get_code "/ng/api/connectors/${conn}?accountIdentifier=${account}&orgIdentifier=${org}&projectIdentifier=${project}")
  if [ "$code" = "200" ]; then
    if [ -n "$pid" ]; then
      print_error "The name/ID '$pid' is already taken in project '$project' (connector '$conn' exists and isn't yours) - pick a different one"
    else
      print_error "Someone already uses this project without a name/ID (connector '$conn' exists and isn't yours) - type a name/ID for yourself"
    fi
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Colima on Apple Silicon: native arm64 vs amd64 emulation
# ---------------------------------------------------------------------------

COLIMA_RESOURCE_ARGS="--cpu 4 --memory 8 --kubernetes --runtime docker"

# Prints the colima start flags for a mode: native | amd64
colima_mode_args() {
  case "$1" in
    amd64) printf '%s' "--vm-type=vz --vz-rosetta --arch x86_64" ;;
    *)     printf '%s' "--vm-type=vz --vz-rosetta --arch aarch64" ;;
  esac
}

colima_start_cmd() {
  printf 'colima start %s %s' "$(colima_mode_args "$1")" "$COLIMA_RESOURCE_ARGS"
}

# Architecture the running Docker daemon reports: aarch64 | x86_64 | ""
docker_daemon_arch() {
  docker info --format '{{.Architecture}}' 2>/dev/null || true
}

# Does a docker/kube arch string match a mode?
arch_matches_mode() {
  local mode="$1" arch="$2"
  case "$mode" in
    amd64) [ "$arch" = "x86_64" ] || [ "$arch" = "amd64" ] ;;
    *)     [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ] ;;
  esac
}

# Decide native vs amd64. A --colima-arch flag value skips the prompt; otherwise always
# ask, offering the previous answer (or native) as the default.
# Usage: choose_colima_mode FLAG_VALUE REMEMBERED_VALUE   (prints native|amd64; prompts on stderr)
choose_colima_mode() {
  local flag="$1" remembered="$2"
  case "$flag" in
    native|arm64|aarch64) echo native; return 0 ;;
    amd64|x86_64)         echo amd64;  return 0 ;;
  esac
  # No question: Apple Silicon always runs native arm64 unless --colima-arch amd64 is given
  : "$remembered"
  echo native
}

# Pick the Harness organization. Lists the orgs the token can see and accepts a number
# or an identifier; DEFAULT is offered on Enter. A FLAG value skips the prompt.
# Usage: choose_harness_org ACCOUNT_ID FLAG_VALUE DEFAULT   (prints the org identifier)
choose_harness_org() {
  local account="$1" flag="$2" def="${3:-default}"
  if [ -n "$flag" ]; then
    echo "$flag"
    return 0
  fi
  local orgs
  orgs=$(harness_get "/ng/api/organizations?accountIdentifier=${account}&pageSize=100" | python3 -c '
import sys, json
try:
    for o in json.load(sys.stdin)["data"]["content"]:
        print(o["organization"]["identifier"] + "\t" + o["organization"]["name"])
except Exception:
    pass' 2>/dev/null)
  if [ -n "$orgs" ]; then
    # If the remembered/default org isn't visible, default to the only org (if just one)
    if ! printf '%s\n' "$orgs" | cut -f1 | grep -qx "$def"; then
      [ "$(printf '%s\n' "$orgs" | wc -l | tr -d ' ')" = "1" ] && def=$(printf '%s\n' "$orgs" | cut -f1)
    fi
    {
      echo ""
      echo "Which Harness organization holds (or should hold) your demo project?"
      printf '%s\n' "$orgs" | awk -F'\t' '{printf "  %d) %s  (%s)\n", NR, $1, $2}'
      echo ""
    } >&2
  fi
  local ans chosen
  while true; do
    read -r -p "Organization [${def}]: " ans
    ans=${ans:-$def}
    chosen="$ans"
    if [ -n "$orgs" ]; then
      if printf '%s' "$ans" | grep -Eq '^[0-9]+$'; then
        chosen=$(printf '%s\n' "$orgs" | sed -n "${ans}p" | cut -f1)
      fi
      if [ -n "$chosen" ] && printf '%s\n' "$orgs" | cut -f1 | grep -qx "$chosen"; then
        echo "$chosen"
        return 0
      fi
      echo "Not one of the organizations listed above - enter its number or identifier." >&2
    else
      echo "$chosen"
      return 0
    fi
  done
}

# Pick the Harness project. Only projects in ORG where this user has the permissions the kit
# needs (connectors, secrets, environments, services, templates, monitored services, code repo)
# are offered. "Create a new project" is offered only to users allowed to create projects.
# DEFAULT_ID (the previous answer) is offered on Enter.
# Prints: "<identifier>\t<display name>\t<existing|new>"  (prompts go to stderr)
# Returns 1 if the user can't use any project and can't create one.
# Usage: choose_harness_project ACCOUNT_ID ORG_ID DEFAULT_ID
choose_harness_project() {
  local account="$1" org="$2" def="$3"
  local me
  me=$(harness_get "/ng/api/user/currentUser?accountIdentifier=${account}" | json_get "data.uuid")
  local listing
  listing=$(harness_get "/ng/api/projects?accountIdentifier=${account}&orgIdentifier=${org}&pageSize=100" | python3 -c '
import sys, json
try:
    for p in json.load(sys.stdin)["data"]["content"]:
        print(p["project"]["identifier"] + "\t" + p["project"]["name"])
except Exception:
    pass' 2>/dev/null)

  # One ACL request: per-project edit permissions + project-create in the org
  local eligible can_create
  eligible=$(printf '%s\n' "$listing" | ACCOUNT="$account" ORG="$org" ME="$me" PAT="$HARNESS_PAT" BASE="$HARNESS_API_BASE" python3 -c '
import sys, os, json, urllib.request
acct, org, me = os.environ["ACCOUNT"], os.environ["ORG"], os.environ["ME"]
projects = [l.rstrip("\n").split("\t", 1) for l in sys.stdin if "\t" in l]
needed = [("CONNECTOR","core_connector_edit"), ("SECRET","core_secret_edit"),
          ("ENVIRONMENT","core_environment_edit"), ("SERVICE","core_service_edit"),
          ("TEMPLATE","core_template_edit"), ("MONITOREDSERVICE","chi_monitoredservice_edit"),
          ("CODE_REPOSITORY","code_repo_edit")]
perms = [{"resourceScope": {"accountIdentifier": acct, "orgIdentifier": org},
          "resourceType": "PROJECT", "permission": "core_project_create"}]
for ident, _ in projects:
    for rtype, perm in needed:
        perms.append({"resourceScope": {"accountIdentifier": acct, "orgIdentifier": org, "projectIdentifier": ident},
                      "resourceType": rtype, "permission": perm})
req = urllib.request.Request(os.environ["BASE"] + "/authz/api/acl", method="POST",
      data=json.dumps({"principal": {"principalIdentifier": me, "principalType": "USER"}, "permissions": perms}).encode(),
      headers={"x-api-key": os.environ["PAT"], "Content-Type": "application/json"})
try:
    acl = json.load(urllib.request.urlopen(req, timeout=30))["data"]["accessControlList"]
except Exception:
    sys.exit(2)
ok = {}
create = False
for a in acl:
    sc = a["resourceScope"]
    if a["permission"] == "core_project_create":
        create = a["permitted"]
        continue
    pid = sc.get("projectIdentifier")
    ok[pid] = ok.get(pid, True) and a["permitted"]
print("CREATE\t" + ("yes" if create else "no"))
for ident, name in projects:
    if ok.get(ident):
        print(ident + "\t" + name)
' 2>/dev/null)
  if [ -z "$eligible" ]; then
    print_error "Couldn't check your project permissions in organization '$org' (Harness API error)" >&2
    return 1
  fi
  can_create=$(printf '%s\n' "$eligible" | grep '^CREATE' | cut -f2)
  local usable
  usable=$(printf '%s\n' "$eligible" | grep -v '^CREATE' | grep -v '^$')
  local n=0
  [ -n "$usable" ] && n=$(printf '%s\n' "$usable" | wc -l | tr -d ' ')

  if [ "$n" = "0" ] && [ "$can_create" != "yes" ]; then
    {
      echo ""
      print_error "You don't have Project Admin rights on any project in organization '$org',"
      echo "  and you aren't allowed to create projects there."
      echo "  Check that you picked the right organization. If you did, ask whoever manages"
      echo "  the Harness project to make you Project Admin on it, then run this script again."
    } >&2
    return 1
  fi

  # Default: previous answer if still usable, else the only usable project, else 1
  local defnum=1 i=0 line
  if [ -n "$usable" ]; then
    while IFS= read -r line; do
      i=$((i + 1))
      [ "$(printf '%s' "$line" | cut -f1)" = "$def" ] && defnum=$i
    done <<EOF
$usable
EOF
  fi
  local createnum=$((n + 1))
  [ "$n" = "0" ] && defnum=$createnum

  {
    echo ""
    echo "Harness project for the demo - choose from the projects in '$org' where you are"
    echo "a Project Admin:"
    if [ -n "$usable" ]; then
      printf '%s\n' "$usable" | awk -F'\t' '{printf "  %d) %s   (identifier: %s)\n", NR, $2, $1}'
    fi
    [ "$can_create" = "yes" ] && echo "  ${createnum}) Create a NEW project (you have permission to create projects)"
    echo ""
  } >&2

  local ans name ident
  while true; do
    read -r -p "Project number [${defnum}]: " ans
    ans=$(printf '%s' "${ans:-$defnum}" | tr -d '[:space:]')
    if printf '%s' "$ans" | grep -Eq '^[0-9]+$'; then
      if [ "$ans" -ge 1 ] && [ "$ans" -le "$n" ]; then
        line=$(printf '%s\n' "$usable" | sed -n "${ans}p")
        printf '%s\t%s\texisting\n' "$(printf '%s' "$line" | cut -f1)" "$(printf '%s' "$line" | cut -f2)"
        return 0
      fi
      if [ "$can_create" = "yes" ] && [ "$ans" = "$createnum" ]; then
        read -r -p "Name for the new project: " name
        name=$(printf '%s' "$name" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        if [ -n "$name" ]; then
          ident=$(printf '%s' "$name" | sed 's/[^a-zA-Z0-9]/_/g; s/__*/_/g; s/^_//; s/_$//')
          printf '%s\t%s\tnew\n' "$ident" "$name"
          return 0
        fi
      fi
    fi
    echo "Enter one of the numbers listed above." >&2
  done
}

# ---------------------------------------------------------------------------
# Docker image builds (BuildKit / buildx, multi-arch)
# ---------------------------------------------------------------------------

has_buildx() {
  docker buildx version > /dev/null 2>&1
}

# Make sure the buildx plugin exists; offers a Homebrew install on macOS.
ensure_buildx() {
  if has_buildx; then
    return 0
  fi
  print_info "docker buildx is not installed (needed for multi-architecture images)"
  if [ "$(uname -s)" = "Darwin" ] && command -v brew > /dev/null 2>&1; then
    echo "Homebrew's docker CLI ships without buildx; install it with:"
    echo "  brew install docker-buildx"
    echo "  mkdir -p ~/.docker/cli-plugins && ln -sfn \"\$(brew --prefix)/opt/docker-buildx/bin/docker-buildx\" ~/.docker/cli-plugins/docker-buildx"
    local ans
    read -r -p "Install docker-buildx now? [Y/n]: " ans
    if [[ ! "$ans" =~ ^[Nn] ]]; then
      if brew install docker-buildx > /dev/null 2>&1; then
        mkdir -p "$HOME/.docker/cli-plugins"
        ln -sfn "$(brew --prefix)/opt/docker-buildx/bin/docker-buildx" "$HOME/.docker/cli-plugins/docker-buildx"
      fi
    fi
  else
    echo "See https://docs.docker.com/build/install-buildx/"
  fi
  has_buildx
}

# A BuildKit builder that can build several platforms (docker-container driver)
ensure_multiarch_builder() {
  docker buildx inspect "$DEMO_BUILDER_NAME" > /dev/null 2>&1 && return 0
  docker buildx create --name "$DEMO_BUILDER_NAME" --driver docker-container > /dev/null 2>&1
}

# Build CONTEXT_DIR and push TAG. Multi-arch with buildx when possible; falls back to
# the daemon's own architecture, then to the legacy builder.
build_and_push_image() {
  local context="$1" tag="$2"
  if has_buildx && ensure_multiarch_builder; then
    if docker buildx build --builder "$DEMO_BUILDER_NAME" --platform "$DEMO_BUILD_PLATFORMS" \
         -t "$tag" --push "$context"; then
      print_status "Built and pushed $tag ($DEMO_BUILD_PLATFORMS)"
      return 0
    fi
    local native
    native="linux/$(docker_daemon_arch | sed 's/x86_64/amd64/; s/aarch64/arm64/')"
    print_info "Multi-arch build failed; retrying for this machine only ($native)"
    if docker buildx build --builder "$DEMO_BUILDER_NAME" --platform "$native" \
         -t "$tag" --push "$context"; then
      print_status "Built and pushed $tag ($native only)"
      return 0
    fi
    return 1
  fi
  print_info "Using the legacy builder (single architecture: $(docker_daemon_arch))"
  docker build -t "$tag" "$context" && docker push "$tag"
}

# ---------------------------------------------------------------------------
# Lab documentation: personalize + deploy
# ---------------------------------------------------------------------------

# Copy markdown/ (and images/) to DEST and fill in the per-person placeholders.
# Usage: personalize_docs REPO_ROOT DEST DOCKER_USER PROJECT_NAME PROJECT_ID PARTICIPANT_ID
personalize_docs() {
  local root="$1" dest="$2" docker_user="$3" pname="$4" pid_proj="$5" participant="$6"
  rm -rf "$dest" && mkdir -p "$dest"
  cp -R "$root/markdown/." "$dest/" || return 1
  [ -d "$root/images" ] && cp -R "$root/images" "$dest/" 2>/dev/null
  python3 - "$dest" "$docker_user" "$pname" "$pid_proj" "$participant" <<'PYEOF'
import sys, glob, os
dest, docker_user, pname, pid_proj, participant = sys.argv[1:6]
repl = [
    ("dockerhubaccountid", docker_user),
    ("{{ID}}", f"_{participant}" if participant else ""),
    ("{{NAME}}", f" {participant}" if participant else ""),
    ("{{DELEGATE}}", f"{participant}-k8s-delegate" if participant else "local-k8s-delegate"),
]
if pname and pname != "Base Demo":
    repl += [("Base Demo", pname), ("Base_Demo", pid_proj)]
for f in glob.glob(os.path.join(dest, "*.md")):
    s = open(f, encoding="utf-8").read()
    for a, b in repl:
        s = s.replace(a, b)
    open(f, "w", encoding="utf-8").write(s)
PYEOF
}

# Deploy (or refresh) the docs site from DOCKER_USER/harness-demo:docs-latest.
# Applies a temp copy of the manifest so the repo file is never modified.
deploy_docs() {
  local root="$1" docker_user="$2"
  local tmp existed=false
  tmp=$(mktemp)
  sed "s/dockerhubaccountid/${docker_user}/g" "$root/harness-deploy/docs/docs-deployment.yaml" > "$tmp"
  kubectl get deployment docs-deployment > /dev/null 2>&1 && existed=true
  if ! kubectl apply -f "$tmp" > /dev/null 2>&1; then
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
  # docs-latest is a moving tag: restart so a rebuilt image is actually pulled
  [ "$existed" = true ] && kubectl rollout restart deployment/docs-deployment > /dev/null 2>&1
  kubectl rollout status deployment/docs-deployment --timeout=180s > /dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Harness delegate (Helm), installed with values fetched from the Harness API
# ---------------------------------------------------------------------------

# prod-2 accounts use https://app.harness.io/gratis (verified); prod-1 uses the
# chart default https://app.harness.io. Other clusters: the user is asked to paste the value
# (HARNESS_MANAGER_ENDPOINT pre-answers it).
harness_manager_endpoint() {
  if [ -n "$HARNESS_MANAGER_ENDPOINT" ]; then
    printf '%s' "$HARNESS_MANAGER_ENDPOINT"
    return 0
  fi
  local cluster
  cluster=$(harness_get "/ng/api/accounts/$1?accountIdentifier=$1" | json_get "data.cluster")
  case "$cluster" in
    prod-2) printf '%s' "https://app.harness.io/gratis" ;;
    prod-1|"") printf '%s' "https://app.harness.io" ;;
    *)
      {
        echo ""
        echo "Your Harness account is on cluster '$cluster'; this script doesn't know its delegate endpoint."
        echo "In Harness: Project Settings > Delegates > New Delegate > Kubernetes > Helm Chart,"
        echo "copy the value after '--set managerEndpoint=' from the install command."
      } >&2
      local ep
      read -r -p "managerEndpoint [https://app.harness.io]: " ep
      printf '%s' "${ep:-https://app.harness.io}"
      ;;
  esac
}

harness_delegate_image() {
  local ver
  ver=$(harness_get "/ng/api/delegate-setup/latest-supported-version?accountIdentifier=$1" | json_get "resource.latestSupportedVersion")
  [ -n "$ver" ] && printf '%s:%s' "$DELEGATE_IMAGE_REPO" "$ver"
}

# The UI install command's delegateToken is base64(<project default_token value>)
harness_delegate_token() {
  local account="$1" org="$2" project="$3" value
  value=$(harness_get "/ng/api/delegate-token-ng/delegate-token-value?accountIdentifier=${account}&orgIdentifier=${org}&projectIdentifier=${project}&delegateTokenName=default_token" \
    | json_get "resource")
  [ -n "$value" ] && printf '%s' "$value" | base64
}

# Usage: delegate_connected ACCOUNT ORG PROJECT NAME  -> 0 if Harness shows it connected
delegate_connected() {
  harness_post "/ng/api/delegate-setup/listDelegates?accountIdentifier=$1&orgIdentifier=$2&projectIdentifier=$3" \
    '{"filterType":"Delegate"}' | python3 -c '
import sys, json
try:
    name = sys.argv[1]
    for d in json.load(sys.stdin).get("resource") or []:
        if d.get("name") == name and d.get("connected"):
            sys.exit(0)
except Exception:
    pass
sys.exit(1)' "$4" 2>/dev/null
}

# Usage: install_delegate ACCOUNT ORG PROJECT NAME
# Set DEMO_DRY_RUN=true to only render the Helm release (no changes).
install_delegate() {
  local account="$1" org="$2" project="$3" name="$4"
  if ! command -v helm > /dev/null 2>&1; then
    print_error "helm is not installed (needed to install the delegate)"
    print_info "macOS: brew install helm   |   others: https://helm.sh/docs/intro/install/"
    return 1
  fi

  local token endpoint image
  token=$(harness_delegate_token "$account" "$org" "$project")
  if [ -z "$token" ]; then
    print_error "Could not read the project's delegate token (default_token) from Harness"
    print_info "You need Project Admin (or delegate edit) on '$project'"
    return 1
  fi
  endpoint=$(harness_manager_endpoint "$account")
  image=$(harness_delegate_image "$account")

  helm repo add "$DELEGATE_HELM_REPO_NAME" "$DELEGATE_HELM_REPO_URL" > /dev/null 2>&1 || true
  helm repo update "$DELEGATE_HELM_REPO_NAME" > /dev/null 2>&1 || true

  local args="upgrade -i $name --namespace $DELEGATE_NAMESPACE --create-namespace $DELEGATE_HELM_REPO_NAME/harness-delegate-ng"
  args="$args --set delegateName=$name --set accountId=$account --set managerEndpoint=$endpoint"
  args="$args --set replicas=1 --set upgrader.enabled=true"
  [ -n "$image" ] && args="$args --set delegateDockerImage=$image"
  if [ "$DEMO_DRY_RUN" = true ]; then
    # shellcheck disable=SC2086
    helm $args --set delegateToken="$token" --dry-run=client > /dev/null
    return $?
  fi

  print_info "Installing delegate '$name' (image ${image:-chart default}, endpoint $endpoint)..."
  # shellcheck disable=SC2086
  if ! helm $args --set delegateToken="$token" > /dev/null; then
    print_error "helm install of the delegate failed"
    return 1
  fi
  print_info "Waiting for the delegate pod to become ready (1-3 minutes)..."
  kubectl rollout status "deployment/$name" -n "$DELEGATE_NAMESPACE" --timeout=300s > /dev/null 2>&1 || true

  local _
  for _ in $(seq 1 30); do
    if delegate_connected "$account" "$org" "$project" "$name"; then
      print_status "Delegate '$name' is connected to Harness"
      return 0
    fi
    sleep 10
  done
  print_error "Delegate '$name' did not show as connected within 5 minutes"
  print_info "Check: kubectl logs -n $DELEGATE_NAMESPACE deployment/$name"
  return 1
}
