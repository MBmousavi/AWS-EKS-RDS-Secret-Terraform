# create AWS EKS cluster with addones
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

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  enable_efa_support                       = true

  vpc_id                   = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids               = data.terraform_remote_state.vpc.outputs.private_subnets
  control_plane_subnet_ids = data.terraform_remote_state.vpc.outputs.intra_subnets

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  eks_managed_node_group_defaults = {
    attach_cluster_primary_security_group = true
  }

  eks_managed_node_groups = {
    nodes = {
      min_size       = 2
      max_size       = 6
      desired_size   = 4
      instance_types = ["t2.medium"]
      capacity_type  = "SPOT"
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }

  node_security_group_tags = {
    "kubernetes.io/cluster/terraform" = null
  }
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.19"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_secrets_store_csi_driver = false
  enable_secrets_store_csi_driver_provider_aws = false
  
  eks_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
      most_recent              = true
    }
    aws-efs-csi-driver = {
      service_account_role_arn = module.efs_csi_driver_irsa.iam_role_arn
      most_recent              = true
    }
  }
  enable_aws_load_balancer_controller = true
  # enable_cluster_proportional_autoscaler = true # For autoscaling master nodes components, like CoreDNS, ...
  enable_metrics_server = true

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
  depends_on = [module.eks, module.ebs_csi_driver_irsa, module.efs_csi_driver_irsa]
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix = "${var.cluster_name}-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
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

module "eks-cluster-autoscaler" {
  source  = "lablabs/eks-cluster-autoscaler/aws"
  version = "2.2.0"

  cluster_name                     = module.eks.cluster_name
  cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn
  cluster_identity_oidc_issuer     = module.eks.cluster_oidc_issuer_url
}


### Secret csi driver setting ###

resource "helm_release" "secrets_csi_driver" {
  name = "secrets-store-csi-driver"

  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"
  version    = "1.4.3"

  # MUST be set if you use ENV variables
  set {
    name  = "syncSecret.enabled"
    value = true
  }

  depends_on = [module.eks_blueprints_addons]
}

resource "helm_release" "secrets_csi_driver_aws_provider" {
  name = "secrets-store-csi-driver-provider-aws"

  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
  version    = "0.3.8"

  depends_on = [helm_release.secrets_csi_driver]
}

data "aws_iam_policy_document" "myapp_secrets" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:apps:myapp"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}


resource "aws_iam_role" "myapp_secrets" {
  name               = "${module.eks.cluster_name}-myapp-secrets"
  assume_role_policy = data.aws_iam_policy_document.myapp_secrets.json
}

resource "aws_iam_policy" "myapp_secrets" {
  name = "${module.eks.cluster_name}-myapp-secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "myapp_secrets" {
  policy_arn = aws_iam_policy.myapp_secrets.arn
  role       = aws_iam_role.myapp_secrets.name
}

output "myapp_secrets_role_arn" {
  value = aws_iam_role.myapp_secrets.arn
}