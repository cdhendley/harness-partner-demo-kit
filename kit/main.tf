terraform {  
    required_providers {  
        harness = {  
            source = "harness/harness"
            version = "~> 0.30"
        }  
    }  
}

variable "account_id" {}
variable "pat" {}
variable "docker_username" {}
variable "DOCKER_PAT" {}

variable "org_id" {
  default = "default"
}

variable "project_name" {
  description = "Display name for the Harness project (e.g., 'Base Demo', 'Partner Workshop')"
  default     = "Base Demo"
}

variable "project_identifier" {
  description = "Identifier for the Harness project (alphanumeric and underscores only, e.g., 'Base_Demo')"
  default     = "Base_Demo"
}

variable "participant_id" {
  description = "Short per-person ID when several people share one project (e.g. 'alex'). Appended to every resource this kit creates so participants don't collide. Empty = single-user names."
  default     = ""

  validation {
    condition     = can(regex("^([a-z][a-z0-9]{0,19})?$", var.participant_id))
    error_message = "participant_id must be empty or 1-20 lowercase letters/digits starting with a letter (e.g. 'alex')."
  }
}

variable "delegate_name" {
  description = "Delegate name the connectors select. Empty = 'local-k8s-delegate' (single-user) or '<participant_id>-k8s-delegate'."
  default     = ""
}

locals {
  # Identifier suffix ("_alex") and display-name suffix (" alex"); both empty in single-user mode
  id_sfx        = var.participant_id == "" ? "" : "_${var.participant_id}"
  name_sfx      = var.participant_id == "" ? "" : " ${var.participant_id}"
  delegate_name = var.delegate_name != "" ? var.delegate_name : (var.participant_id == "" ? "local-k8s-delegate" : "${var.participant_id}-k8s-delegate")

  repo_id        = "partner_demo_kit"
  k8s_conn_id    = "workshop_k8s${local.id_sfx}"
  docker_conn_id = "workshopdocker${local.id_sfx}"
  prom_conn_id   = "prometheus${local.id_sfx}"
  template_id    = "Compile_Application${local.id_sfx}"
  dev_env_id     = "dev${local.id_sfx}"
  prod_env_id    = "prod${local.id_sfx}"
  dev_infra_id   = "k8s_dev${local.id_sfx}"
  backend_id     = "backend${local.id_sfx}"
}

provider "harness" {
    endpoint            = "https://app.harness.io/gateway"
    account_id          = var.account_id
    platform_api_key    = var.pat
}

resource "harness_platform_project" "base_demo" {
  identifier = var.project_identifier
  name       = var.project_name
  org_id     = var.org_id
  color      = "#0063F7"
}

resource "harness_platform_repo" "partner_demo_kit" {
  identifier     = local.repo_id
  org_id         = var.org_id
  project_id     = harness_platform_project.base_demo.identifier
  default_branch = "main"
  description    = "Base demo repository for Harness partner workshops"
  source {
    repo = "harness-community/partner-demo-kit"
    type = "github"
  }

  depends_on = [
    harness_platform_project.base_demo
  ]

  lifecycle {
    ignore_changes = [
      source,
      description
    ]
  }
}

resource "harness_platform_connector_kubernetes" "workshop_k8s" {
  org_id             = var.org_id
  project_id         = harness_platform_project.base_demo.identifier
  identifier         = local.k8s_conn_id
  name               = "Workshop K8s${local.name_sfx}"
  description        = "Connector to local K8s cluster (minikube)"

  inherit_from_delegate {
    delegate_selectors = [local.delegate_name]
  }

  depends_on = [
    harness_platform_project.base_demo
  ]
}

resource "harness_platform_secret_text" "docker_username" {
  identifier                = "docker_username${local.id_sfx}"
  name                      = "docker-username${local.name_sfx}"
  org_id                    = var.org_id
  project_id                = harness_platform_project.base_demo.identifier
  secret_manager_identifier = "harnessSecretManager"
  value_type               = "Inline"
  value                    = var.docker_username

  depends_on = [
    harness_platform_project.base_demo
  ]
}

resource "harness_platform_secret_text" "DOCKER_PAT" {
  identifier                = "DOCKER_PAT${local.id_sfx}"
  name                      = "docker-pat${local.name_sfx}"
  org_id                    = var.org_id
  project_id                = harness_platform_project.base_demo.identifier
  secret_manager_identifier = "harnessSecretManager"
  value_type               = "Inline"
  value                    = var.DOCKER_PAT

  depends_on = [
    harness_platform_project.base_demo
  ]
}

resource "harness_platform_connector_docker" "workshopdocker" {
  identifier          = local.docker_conn_id
  name                = "Workshop Docker${local.name_sfx}"
  org_id              = var.org_id
  project_id          = harness_platform_project.base_demo.identifier
  type                = "DockerHub"
  url                 = "https://index.docker.io/v2/"
  execute_on_delegate = false

  credentials {
    username_ref = harness_platform_secret_text.docker_username.identifier
    password_ref = harness_platform_secret_text.DOCKER_PAT.identifier
  }

  depends_on = [
    harness_platform_project.base_demo,
    harness_platform_secret_text.docker_username,
    harness_platform_secret_text.DOCKER_PAT
  ]
}

resource "harness_platform_template" "compile_application" {
  identifier    = local.template_id
  org_id        = var.org_id
  project_id    = harness_platform_project.base_demo.identifier
  name          = "Compile Application${local.name_sfx}"
  version       = "v0.1"
  is_stable     = true
  template_yaml = <<-EOT
template:
  name: "Compile Application${local.name_sfx}"
  identifier: "${local.template_id}"
  versionLabel: "v0.1"
  type: Step
  projectIdentifier: ${harness_platform_project.base_demo.identifier}
  orgIdentifier: ${var.org_id}
  tags: {}
  spec:
    type: Run
    spec:
      connectorRef: ${harness_platform_connector_docker.workshopdocker.identifier}
      image: node:20-alpine
      shell: Sh
      command: |-
        cd frontend-app/harness-webapp
        npm install
        npm install -g @angular/cli

        mkdir -p ./src/environments
        echo "export const environment = {
          production: true,
          defaultApiUrl: "'"http://localhost:8000"'",
          defaultSDKKey: "'"<+variable.sdk>"'"
        };" > ./src/environments/environment.prod.ts


        echo "export const environment = {
          production: true,
          defaultApiUrl: "'"http://localhost:8000"'",
          defaultSDKKey: "'"<+variable.sdk>"'"
        };" > ./src/environments/environment.ts

        # Force single-threaded build to avoid esbuild deadlock on ARM64
        node --version
        ng build --configuration production
  EOT

  depends_on = [
    harness_platform_project.base_demo,
    harness_platform_connector_docker.workshopdocker
  ]
}

resource "harness_platform_connector_prometheus" "prometheus" {
  identifier         = local.prom_conn_id
  name               = "Prometheus${local.name_sfx}"
  org_id             = var.org_id
  project_id         = harness_platform_project.base_demo.identifier
  description        = "Connector to Prometheus instance (use ngrok URL or cluster-local URL)"
  url                = "http://prometheus-k8s.monitoring.svc.cluster.local:9090/"
  delegate_selectors = [local.delegate_name]

  depends_on = [
    harness_platform_project.base_demo
  ]
}

resource "harness_platform_environment" "dev" {
  identifier  = local.dev_env_id
  name        = "Dev${local.name_sfx}"
  org_id      = var.org_id
  project_id  = harness_platform_project.base_demo.identifier
  type        = "PreProduction"
  tags        = []
  
  yaml = <<-EOT
environment:
  name: Dev${local.name_sfx}
  identifier: ${local.dev_env_id}
  tags: {}
  type: PreProduction
  orgIdentifier: ${var.org_id}
  projectIdentifier: ${harness_platform_project.base_demo.identifier}
EOT

  depends_on = [
    harness_platform_project.base_demo
  ]
}

resource "harness_platform_environment" "prod" {
  identifier  = local.prod_env_id
  name        = "Prod${local.name_sfx}"
  org_id      = var.org_id
  project_id  = harness_platform_project.base_demo.identifier
  type        = "Production"
  tags        = []
  
  yaml = <<-EOT
environment:
  name: Prod${local.name_sfx}
  identifier: ${local.prod_env_id}
  tags: {}
  type: Production
  orgIdentifier: ${var.org_id}
  projectIdentifier: ${harness_platform_project.base_demo.identifier}
EOT

  depends_on = [
    harness_platform_project.base_demo
  ]
}

resource "harness_platform_infrastructure" "k8s_dev" {
  identifier      = local.dev_infra_id
  name            = "K8s Dev${local.name_sfx}"
  org_id          = var.org_id
  project_id      = harness_platform_project.base_demo.identifier
  env_id          = harness_platform_environment.dev.identifier
  type            = "KubernetesDirect"
  deployment_type = "Kubernetes"
  yaml            = <<-EOT
infrastructureDefinition:
  name: K8s Dev${local.name_sfx}
  identifier: ${local.dev_infra_id}
  description: ""
  tags:
    owner: ed.slatt
  orgIdentifier: ${var.org_id}
  projectIdentifier: ${harness_platform_project.base_demo.identifier}
  environmentRef: ${harness_platform_environment.dev.identifier}
  deploymentType: Kubernetes
  type: KubernetesDirect
  spec:
    connectorRef: ${harness_platform_connector_kubernetes.workshop_k8s.identifier}
    namespace: default
    releaseName: release-<+INFRA_KEY>
  allowSimultaneousDeployments: true
EOT

  depends_on = [
    harness_platform_project.base_demo,
    harness_platform_environment.dev,
    harness_platform_connector_kubernetes.workshop_k8s
  ]
}

resource "harness_platform_service" "backend" {
  identifier  = local.backend_id
  name        = "backend${local.name_sfx}"
  org_id      = var.org_id
  project_id  = harness_platform_project.base_demo.identifier
  yaml = <<-EOT
service:
  name: backend${local.name_sfx}
  identifier: ${local.backend_id}
  orgIdentifier: ${var.org_id}
  projectIdentifier: ${harness_platform_project.base_demo.identifier}
  serviceDefinition:
    spec:
      manifests:
        - manifest:
            identifier: backend
            type: K8sManifest
            spec:
              store:
                type: HarnessCode
                spec:
                  repoName: ${local.repo_id}
                  gitFetchType: Branch
                  paths:
                    - harness-deploy/backend/manifests
                  branch: main
              valuesPaths:
                - harness-deploy/backend/values.yaml
              skipResourceVersioning: false
              enableDeclarativeRollback: false
      artifacts:
        primary:
          primaryArtifactRef: <+input>
          sources:
            - spec:
                connectorRef: ${harness_platform_connector_docker.workshopdocker.identifier}
                imagePath: ${var.docker_username}/harness-demo
                tag: backend-latest
                digest: ""
              identifier: backend
              type: DockerRegistry
    type: Kubernetes
EOT

  depends_on = [
    harness_platform_project.base_demo,
    harness_platform_connector_docker.workshopdocker
  ]

  lifecycle {
    ignore_changes = [
      yaml  # Allow manual updates to service configuration
    ]
  }
}

resource "harness_platform_monitored_service" "backend_dev" {
  org_id     = var.org_id
  project_id = harness_platform_project.base_demo.identifier
  identifier = "backend_dev${local.id_sfx}"
  request {
    name            = "backend${local.name_sfx}"
    type            = "Application"
    service_ref     = harness_platform_service.backend.identifier
    environment_ref = harness_platform_environment.dev.identifier
    health_sources {
      name       = "Prometheus"
      identifier = "prometheus"
      type       = "Prometheus"
      spec = jsonencode({
        connectorRef = harness_platform_connector_prometheus.prometheus.identifier
        feature      = "apm"
        metricDefinitions = [
          {
            identifier = "Prometheus_Metric"
            metricName = "Prometheus Metric"
            riskProfile = {
              riskCategory = "Performance_Other"
              thresholdTypes = [
                "ACT_WHEN_HIGHER"
              ]
            }
            analysis = {
              liveMonitoring = {
                enabled = true
              }
              deploymentVerification = {
                enabled                  = true
                serviceInstanceFieldName = "pod"
              }
              sli = {
                enabled = true
              }
            }
            query         = "avg(container_cpu_system_seconds_total{namespace=\"default\", pod!~\".*canary.*\", pod=~\"backend-deployment.*\"})"
            groupName     = "Infrastructure"
            isManualQuery = true
          }
        ]
      })
    }
  }

  depends_on = [
    harness_platform_project.base_demo,
    harness_platform_service.backend,
    harness_platform_environment.dev,
    harness_platform_connector_prometheus.prometheus
  ]
}

resource "harness_platform_monitored_service" "backend_prod" {
  org_id     = var.org_id
  project_id = harness_platform_project.base_demo.identifier
  identifier = "backend_prod${local.id_sfx}"
  request {
    name            = "backend${local.name_sfx}"
    type            = "Application"
    service_ref     = harness_platform_service.backend.identifier
    environment_ref = harness_platform_environment.prod.identifier
    health_sources {
      name       = "Prometheus"
      identifier = "prometheus"
      type       = "Prometheus"
      spec = jsonencode({
        connectorRef = harness_platform_connector_prometheus.prometheus.identifier
        feature      = "apm"
        metricDefinitions = [
          {
            identifier = "Prometheus_Metric"
            metricName = "Prometheus Metric"
            riskProfile = {
              riskCategory = "Performance_Other"
              thresholdTypes = [
                "ACT_WHEN_HIGHER"
              ]
            }
            analysis = {
              liveMonitoring = {
                enabled = true
              }
              deploymentVerification = {
                enabled                  = true
                serviceInstanceFieldName = "pod"
              }
              sli = {
                enabled = true
              }
            }
            query         = "avg(container_cpu_system_seconds_total{namespace=\"default\", pod!~\".*canary.*\", pod=~\"backend-deployment.*\"})"
            groupName     = "Infrastructure"
            isManualQuery = true
          }
        ]
      })
    }
  }

  depends_on = [
    harness_platform_project.base_demo,
    harness_platform_service.backend,
    harness_platform_environment.prod,
    harness_platform_connector_prometheus.prometheus
  ]
}