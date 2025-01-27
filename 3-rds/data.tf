data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket  = "terraform-state-bucket-mbmousavi"
    key     = "global/vpc/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}

data "terraform_remote_state" "secret" {
  backend = "s3"
  config = {
    bucket  = "terraform-state-bucket-mbmousavi"
    key     = "global/secret/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}

data "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = data.terraform_remote_state.secret.outputs.db_credentials_id
}