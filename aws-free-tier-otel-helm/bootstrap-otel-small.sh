
#!/usr/bin/env bash
# bootstrap-otel-eks-optA-v2.sh
# Generates a Terraform + Helm project to provision EKS and deploy the OpenTelemetry Demo.
# Option A: Providers use EKS module outputs + AWS CLI exec auth (no pre-read data sources).

set -euo pipefail

# ---- Config (override via env) ----
REGION="${REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-otel-eks-cluster}"
K8S_VERSION="${K8S_VERSION:-1.31}"

BASE_DIR="otel-eks"
VALUES_DIR="${BASE_DIR}/helm-values"

echo "==> Creating directories..."
mkdir -p "${BASE_DIR}"
mkdir -p "${VALUES_DIR}"

# -----------------------------------
# versions.tf
# -----------------------------------
cat > "${BASE_DIR}/versions.tf" <<'EOF'
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}
EOF

# -----------------------------------
# variables.tf
# -----------------------------------
cat > "${BASE_DIR}/variables.tf" <<EOF
# General
variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "${REGION}"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "${CLUSTER_NAME}"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "${K8S_VERSION}"
}

# Networking
variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnets" {
  description = "Public subnet CIDRs (3 AZs)"
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDRs (3 AZs)"
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]
}

# Node groups
variable "ng_general_instance_types" {
  description = "Instance types for general-purpose node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "ng_general_desired" {
  description = "Desired capacity for general node group"
  type        = number
  default     = 2
}

variable "ng_general_min" {
  description = "Min size for general node group"
  type        = number
  default     = 2
}

variable "ng_general_max" {
  description = "Max size for general node group"
  type        = number
  default     = 4
}

variable "ng_small_instance_types" {
  description = "Instance types for smaller node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "ng_small_desired" {
  description = "Desired capacity for small node group"
  type        = number
  default     = 2
}

variable "ng_small_min" {
  description = "Min size for small node group"
  type        = number
  default     = 2
}

variable "ng_small_max" {
  description = "Max size for small node group"
  type        = number
  default     = 4
}

# Helm chart
variable "otel_demo_chart_version" {
  description = "Optional: pin a specific opentelemetry-demo chart version"
  type        = string
  default     = "" # keep empty to use latest
}
EOF

# -----------------------------------
# main.tf
# -----------------------------------
cat > "${BASE_DIR}/main.tf" <<'EOF'
provider "aws" {
  region = var.region
}

data "aws_availability_zones" "this" {
  state = "available"
}

# ---------------------
# VPC (3 AZs, NAT GW)
# ---------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.this.names, 0, 3)
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# ---------------------
# EKS Cluster & NodeGroups (module v21.x interface)
# ---------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.12.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  endpoint_public_access  = true
  endpoint_private_access = false

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true
  
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    general = {
      instance_types = var.ng_general_instance_types
      desired_size   = var.ng_general_desired
      min_size       = var.ng_general_min
      max_size       = var.ng_general_max
      subnet_ids     = module.vpc.private_subnets
      tags           = { Name = "ng-general" }
    }

    small = {
      instance_types = var.ng_small_instance_types
      desired_size   = var.ng_small_desired
      min_size       = var.ng_small_min
      max_size       = var.ng_small_max
      subnet_ids     = module.vpc.private_subnets
      tags           = { Name = "ng-small" }
    }
  }

  tags = { Name = var.cluster_name }
}

# ---------------------
# Explicit AWS EKS add-ons (no `cluster_addons` in module)
# ---------------------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = module.eks.cluster_name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = module.eks.cluster_name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"
}

# ---------------------
# Providers wired to EKS (Option A: exec via AWS CLI, Helm v3 syntax)
# ---------------------
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# ---------------------
# Helm: OpenTelemetry Demo
# ---------------------
resource "helm_release" "otel_demo" {
  name             = "my-otel-demo"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-demo"
  namespace        = "opentelemetry-demo"
  create_namespace = true

  # Optional pin
  # version = var.otel_demo_chart_version

  values = [
    file("${path.module}/helm-values/opentelemetry-demo-values.yaml")
  ]

  timeout = 1200
  depends_on = [
    module.eks,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.coredns
  ]
}

# Grab the LoadBalancer hostname created for the Frontend Proxy
data "kubernetes_service_v1" "frontendproxy" {
  metadata {
    name      = "${helm_release.otel_demo.name}-frontendproxy"
    namespace = helm_release.otel_demo.namespace
  }
}

locals {
  frontendproxy_hostname = try(
    data.kubernetes_service_v1.frontendproxy.status[0].load_balancer[0].ingress[0].hostname,
    data.kubernetes_service_v1.frontendproxy.status[0].load_balancer[0].ingress[0].hostname
  )
}
EOF

# -----------------------------------
# outputs.tf
# -----------------------------------
cat > "${BASE_DIR}/outputs.tf" <<'EOF'
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "kubeconfig_hint" {
  description = "Use aws eks update-kubeconfig to talk to the cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "otel_demo_frontendproxy_url" {
  description = "Public URL for the OTel Demo Frontend Proxy"
  value       = local.frontendproxy_hostname != "" ? "http://${local.frontendproxy_hostname}:8080" : "(pending)"
}

output "grafana_url_via_proxy" {
  description = "Grafana proxied through Frontend Proxy"
  value       = local.frontendproxy_hostname != "" ? "http://${local.frontendproxy_hostname}:8080/grafana" : "(pending)"
}

output "jaeger_url_via_proxy" {
  description = "Jaeger UI proxied through Frontend Proxy"
  value       = local.frontendproxy_hostname != "" ? "http://${local.frontendproxy_hostname}:8080/jaeger/ui" : "(pending)"
}
EOF

# -----------------------------------
# terraform.tfvars
# -----------------------------------
cat > "${BASE_DIR}/terraform.tfvars" <<EOF
region             = "${REGION}"
cluster_name       = "${CLUSTER_NAME}"
kubernetes_version = "${K8S_VERSION}"

vpc_cidr        = "10.20.0.0/16"
public_subnets  = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
private_subnets = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]

ng_general_instance_types = ["t3.small"]
ng_general_desired        = 4
ng_general_min            = 2
ng_general_max            = 4

ng_small_instance_types = ["t3.small"]
ng_small_desired        = 2
ng_small_min            = 2
ng_small_max            = 4

otel_demo_chart_version = ""
EOF

# -----------------------------------
# helm-values/opentelemetry-demo-values.yaml
# -----------------------------------
cat > "${VALUES_DIR}/opentelemetry-demo-values.yaml" <<'EOF'
# Expose the Frontend Proxy via a public AWS LoadBalancer
components:
  frontend-proxy:
    service:
      type: LoadBalancer
      port: 8080

  # Make load-generator schedulable on small nodes
  load-generator:
    enabled: true
    env:
      - name: LOCUST_USERS
        value: "5"      # default 10
      - name: LOCUST_SPAWN_RATE
        value: "1"
      - name: LOCUST_AUTOSTART
        value: "true"
    resources:
      limits:
        memory: 512Mi   # default is 1500Mi (too high for small nodes)

# Sub-chart toggles (root-level keys)
opensearch:
  enabled: false        # Optional: disable the heaviest component on small clusters
EOF

# -----------------------------------
# Optional: .gitignore
# -----------------------------------
cat > "${BASE_DIR}/.gitignore" <<'EOF'
# Terraform
.terraform/
.terraform.lock.hcl
terraform.tfstate
terraform.tfstate.backup
*.tfvars.backup
.crash*
*.log

# kubeconfig files
kubeconfig_*
EOF

# -----------------------------------
# README (quick start)
# -----------------------------------
cat > "${BASE_DIR}/README.md" <<EOF
# OpenTelemetry Demo on EKS (Terraform, Option A)

This project creates:
- A VPC (public+private subnets across 3 AZs)
- An EKS cluster (IRSA enabled) with two managed node groups
- Explicit EKS add-ons via \`aws_eks_addon\`: vpc-cni, kube-proxy, coredns
- Helm install of the OpenTelemetry Demo, exposing the Frontend Proxy via a LoadBalancer

## Prereqs
- Terraform \`>= 1.5\`
- AWS CLI v2 installed and configured (for \`aws eks get-token\`)
- kubectl installed

## Deploy

\`\`\`bash
terraform init -upgrade
terraform validate
terraform apply
\`\`\`

Configure \`kubectl\`:
\`\`\`bash
\$(terraform output -raw kubeconfig_hint)
\`\`\`

Get public URL:
\`\`\`bash
terraform output otel_demo_frontendproxy_url
terraform output grafana_url_via_proxy
terraform output jaeger_url_via_proxy
\`\`\`

If the URL shows "(pending)", wait 1–3 minutes for the LoadBalancer to be provisioned and run:
\`\`\`bash
terraform refresh
terraform output otel_demo_frontendproxy_url
\`\`\`

## Clean up
\`\`\`bash
terraform destroy
\`\`\`

## Notes
- Providers use EKS module outputs + AWS CLI token to avoid reading the cluster before it's created.
- Helm provider uses v3 syntax (kubernetes as an argument object).
EOF

echo "==> Formatting Terraform files..."
( cd "${BASE_DIR}" && terraform fmt || true )

echo "==> Done."
echo "Project created at: ${BASE_DIR}"
echo
echo "Next steps:"
echo "  cd ${BASE_DIR}"
echo "  terraform init -upgrade"
echo "  terraform validate"
echo "  terraform apply"
echo
echo "After apply:"
echo "  \$(terraform output -raw kubeconfig_hint)"
echo "  terraform output otel_demo_frontendproxy_url"
echo "  terraform output grafana_url_via_proxy"
echo "  terraform output jaeger_url_via_proxy"
