# Isso "lê" a role que a Amazon já criou para você
data "aws_iam_role" "labrole" {
  name = "LabRole"
}

# Agora, em qualquer lugar que pedir um ARN de Role, você usa:
# role_arn = data.aws_iam_role.labrole.arn

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "togglemaster-vpc"
  cidr = "10.0.0.0/16"

  # Define em quais zonas da AWS a rede vai morar
  azs             = ["us-east-1a", "us-east-1b"]
  
  # Subnets Privadas (onde os Pods e RDS vão ficar)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  
  # Subnets Públicas (onde o Load Balancer vai ficar)
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # Habilita NAT Gateway (Necessário para os Pods baixarem imagens da internet)
  enable_nat_gateway = true
  single_nat_gateway = true # Para economizar os $50 da Academy

  tags = {
    "kubernetes.io/cluster/togglemaster-eks" = "shared"
  }
}

#1 terraform init
#2 terraform plan
#3 terraform apply
