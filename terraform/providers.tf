# Este arquivo configura os provedores e o local do estado (backend)
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # O backend remoto garante que o seu .tfstate esteja seguro no S3
  backend "s3" {
    bucket = "togglemaster-terraform-state-tc3" 
    # Organizando a key dentro de uma pasta para o projeto
    key    = "fase3/infra/terraform.tfstate"
    region = "us-east-1"
    
    # DICA: Não coloque 'profile' aqui. 
    # O Terraform usará as credenciais que você exportar no terminal ou configurar no GitHub.
  }
}

provider "aws" {
  region = "us-east-1"
  
  # Deixando este bloco vazio, o Terraform busca automaticamente 
  # as variáveis de ambiente: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY e AWS_SESSION_TOKEN.
}