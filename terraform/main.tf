terraform {
  # 1. CONFIGURAÇÃO DE BACKEND REMOTO
  backend "s3" {
    bucket = "togglemaster-s3" 
    key    = "state/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.12.1"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "infisical" {
  host          = "https://app.infisical.com"
  client_id     = var.infisical_client_id
  client_secret = var.infisical_client_secret
}

variable "infisical_client_id" {
  type      = string
  sensitive = true
}

variable "infisical_client_secret" {
  type      = string
  sensitive = true
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks_cluster.name
}

data "infisical_secrets" "db_secrets" {
  env_slug     = "dev"
  workspace_id = "3d29296c-2d40-49a8-b604-183f887fd6e7"
  folder_path  = "/"
}

data "aws_iam_role" "labrole" {
  name = "LabRole"
}

# --- INFRAESTRUTURA (VPC, ECR, EKS) ---

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"
  name = "togglemaster-vpc-tc3"
  cidr = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true 
  public_subnet_tags = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }
}

resource "aws_ecr_repository" "repos" {
  for_each = toset(["auth", "flag", "targeting", "evaluation", "analytics"])
  name     = "togglemaster-${each.key}"
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "togglemaster-eks-prod"
  version  = "1.30"
  role_arn = data.aws_iam_role.labrole.arn
  vpc_config {
    subnet_ids = module.vpc.private_subnets
    endpoint_public_access = true
  }
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "togglemaster-nodes"
  node_role_arn   = data.aws_iam_role.labrole.arn
  subnet_ids      = module.vpc.private_subnets
  instance_types  = ["t3.medium"]
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}

# --- BANCOS DE DADOS ---

resource "aws_db_subnet_group" "rds_group" {
  name       = "togglemaster-rds-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_db_instance" "rds_instances" {
  count                  = 3
  identifier             = "togglemaster-db-${count.index}"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "togglemaster"
  username               = "masteruser"
  password               = data.infisical_secrets.db_secrets.secrets["DB_PASS_${count.index}"].value
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.rds_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "togglemaster-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnets.name
  security_group_ids   = [aws_security_group.db_sg.id]
}

resource "aws_elasticache_subnet_group" "redis_subnets" {
  name       = "redis-subnets"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_security_group" "db_sg" {
  name   = "togglemaster-db-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- SERVIÇOS DE SISTEMA (METRICS SERVER) ---

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"
  set {
    name  = "args"
    value = "{--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP}"
  }
  depends_on = [aws_eks_node_group.node_group]
}

# --- CONFIGURAÇÃO KUBERNETES & GITOPS ---

resource "kubernetes_config_map" "db_config" {
  metadata { name = "togglemaster-db-config" }
  data = {
    DB_HOST_0 = aws_db_instance.rds_instances[0].address
    DB_HOST_1 = aws_db_instance.rds_instances[1].address
    DB_HOST_2 = aws_db_instance.rds_instances[2].address
    REDIS_ENDPOINT = aws_elasticache_cluster.redis.cache_nodes[0].address
  }
}

resource "kubernetes_secret" "db_password_secret" {
  metadata { name = "togglemaster-db-secret" }
  data = {
    password_0 = data.infisical_secrets.db_secrets.secrets["DB_PASS_0"].value
    password_1 = data.infisical_secrets.db_secrets.secrets["DB_PASS_1"].value
    password_2 = data.infisical_secrets.db_secrets.secrets["DB_PASS_2"].value
  }
}

# APLICAÇÃO DOS MANIFESTOS NA ORDEM CORRETA
resource "kubernetes_manifest" "namespaces" {
  for_each = fileset("${path.module}/../gitops", "*-namespace.yaml")
  manifest = yamldecode(file("${path.module}/../gitops/${each.value}"))
  depends_on = [aws_eks_node_group.node_group]
}

resource "kubernetes_manifest" "jobs" {
  for_each = fileset("${path.module}/../gitops", "*-job.yaml")
  manifest = yamldecode(file("${path.module}/../gitops/${each.value}"))
  depends_on = [kubernetes_manifest.namespaces, aws_db_instance.rds_instances, kubernetes_secret.db_password_secret]
}

resource "kubernetes_manifest" "services" {
  for_each = fileset("${path.module}/../gitops", "*-service.yaml")
  manifest = yamldecode(file("${path.module}/../gitops/${each.value}"))
  depends_on = [kubernetes_manifest.jobs, kubernetes_config_map.db_config]
}