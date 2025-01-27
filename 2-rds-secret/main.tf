terraform {
  backend "s3" {
    key            = "global/secret/terraform.tfstate"
    bucket         = "terraform-state-bucket-mbmousavi"
    dynamodb_table = "terraform-state"
    region         = "eu-central-1"
    encrypt        = true
  }
}

provider "aws" {
  profile = var.profile
  region  = var.region
}

resource "random_password" "db_master_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.db_name}-db-credentials"
  description = "Credentials for RDS database ${var.db_name}"
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master_password.result
  })
}