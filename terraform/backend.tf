terraform {
  backend "s3" {
    bucket = "togglemaster-s3"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
    # use_lockfile = true (Se estiver usando Terraform 1.10+)
  }
}