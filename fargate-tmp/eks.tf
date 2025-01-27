terraform {
  backend "s3" {
    key            = "global/eks/terraform.tfstate"
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

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"
  enable_irsa     = true

  cluster_addons = {
    kube-proxy = {}
    vpc-cni    = {}
    coredns = {
      configuration_values = jsonencode({
        computeType = "fargate"
      })
    }
  }

  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group = false
  create_node_security_group    = false

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  enable_efa_support                       = true

  vpc_id                   = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids               = data.terraform_remote_state.vpc.outputs.private_subnets
  control_plane_subnet_ids = data.terraform_remote_state.vpc.outputs.intra_subnets

  fargate_profile_defaults = {
    iam_role_additional_policies = {
      additional = aws_iam_policy.additional.arn
    }
  }

  fargate_profiles = {
    apps = {
      name = "apps"
      selectors = [
        { namespace = "backend" }
      ]
    }
    kube-system = {
      name = "kube-system"
      selectors = [
        { namespace = "kube-system" }
      ]
    }
  }
}

resource "aws_iam_policy" "additional" {
  name = "EKS-additional"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.19"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    aws-efs-csi-driver = {
      service_account_role_arn = module.efs_csi_driver_irsa.iam_role_arn
      most_recent              = true
    }
  }
  enable_aws_load_balancer_controller = true
  enable_metrics_server = true

}

module "efs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix = "${var.cluster_name}-efs-csi-driver"

  attach_efs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }
}