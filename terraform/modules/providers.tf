
#Este é o primeiro arquivo que você deve criar. Ele diz ao Terraform quem é o provedor e onde salvar o estado.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # IMPORTANTE: Crie o bucket no S3 manualmente antes de rodar isso!
  backend "s3" {
    bucket = "seu-nome-bucket-terraform-state" 
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}