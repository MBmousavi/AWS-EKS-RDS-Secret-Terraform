data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket  = "terraform-state-bucket-mbmousavi"
    key     = "global/vpc/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}