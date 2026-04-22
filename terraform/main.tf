provider "aws" {
  region = "us-east-1"
}

# 1. REFERÊNCIA À ROLE DA ACADEMY
data "aws_iam_role" "labrole" {
  name = "LabRole"
}

# 2. NETWORKING (VPC)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "togglemaster-vpc-tc3" # Nome novo
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true 

  public_subnet_tags = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }
}

# 3. REPOSITÓRIOS ECR (Adicionado sufixo -v2)
locals {
  microservices = ["auth", "flag", "targeting", "evaluation", "analytics"]
}

resource "aws_ecr_repository" "repos" {
  for_each             = toset(local.microservices)
  name                 = "togglemaster-${each.key}-v2"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 4. CLUSTER EKS (Nome novo)
resource "aws_eks_cluster" "eks_cluster" {
  name     = "togglemaster-eks-v2"
  version  = "1.30"
  role_arn = data.aws_iam_role.labrole.arn

  vpc_config {
    subnet_ids             = module.vpc.private_subnets
    endpoint_public_access = true
  }
}

# 4.1. NODE GROUP
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "togglemaster-nodes-v2"
  node_role_arn   = data.aws_iam_role.labrole.arn
  subnet_ids      = module.vpc.private_subnets
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [aws_eks_cluster.eks_cluster]
}

# 5. RDS
resource "aws_db_subnet_group" "rds_unique_group" {
  name       = "togglemaster-rds-group-v2"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_db_instance" "rds_instances" {
  count                  = 3
  identifier             = "togglemaster-db-v2-${count.index}"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "togglemaster"
  username               = "masteruser"
  password               = "password123"
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.rds_unique_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
}

# 6. CACHE (Redis)
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "togglemaster-redis-v2"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnets.name
  security_group_ids   = [aws_security_group.db_sg.id]
}

resource "aws_elasticache_subnet_group" "redis_subnets" {
  name       = "redis-subnets-v2"
  subnet_ids = module.vpc.private_subnets
}

# 7. DYNAMODB
resource "aws_dynamodb_table" "analytics" {
  name           = "ToggleMasterAnalyticsV2"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# 8. SQS
resource "aws_sqs_queue" "main_queue" {
  name = "togglemaster-queue-v2"
}

# 9. SECURITY GROUP
resource "aws_security_group" "db_sg" {
  name   = "togglemaster-db-sg-v2"
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

# --- OUTPUTS ---
output "cluster_endpoint" { value = aws_eks_cluster.eks_cluster.endpoint }
output "cluster_name"     { value = aws_eks_cluster.eks_cluster.name }
output "ecr_repository_urls" {
  value = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}
output "rds_endpoints" { value = aws_db_instance.rds_instances[*].endpoint }
output "redis_endpoint" { value = aws_elasticache_cluster.redis.cache_nodes[0].address }
output "sqs_queue_url"  { value = aws_sqs_queue.main_queue.id }
output "dynamodb_table_name" { value = aws_dynamodb_table.analytics.name }