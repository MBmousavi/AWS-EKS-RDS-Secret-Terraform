terraform {
  backend "s3" {
    key            = "global/rds/terraform.tfstate"
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

# create security group for RDS
module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name   = "sg_rds"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  # Ingress rule for PostgreSQL
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = data.terraform_remote_state.vpc.outputs.vpc_cidr_block
    },
  ]
}

# create AWS RDS
module "db" {
  source     = "terraform-aws-modules/rds/aws"
  version    = "6.10.0"
  identifier = "database"

  engine               = "postgres"
  engine_version       = "15.7"
  major_engine_version = "15"
  instance_class       = "db.t4g.micro" # Free tier compatible if eligible
  family               = "postgres15"

  allocated_storage = 20 # Minimum for free tier

  username                    = jsondecode(data.aws_secretsmanager_secret_version.db_credentials.secret_string)["username"]
  password                    = jsondecode(data.aws_secretsmanager_secret_version.db_credentials.secret_string)["password"]
  manage_master_user_password = false
  port                        = 5432

  multi_az               = false # Free tier only supports single AZ
  create_db_subnet_group = false
  db_subnet_group_name   = data.terraform_remote_state.vpc.outputs.database_subnet_group
  vpc_security_group_ids = [module.security_group.security_group_id]

  skip_final_snapshot = true
  deletion_protection = false

  performance_insights_enabled = false
  create_monitoring_role       = false

  tags = {
    Name        = "PostgreSQL-DB"
    Environment = "dev"
    Terraform   = "true"
  }
}
