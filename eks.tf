data "aws_caller_identity" "current" {}

locals {
  # The identity running Terraform becomes cluster admin. With SSO later this
  # is an assumed-role session ARN and needs aws_iam_session_context instead.
  cluster_admin_arn = data.aws_caller_identity.current.arn
}

resource "aws_eks_cluster" "main" {
  name     = "${local.name}-eks"
  role_arn = aws_iam_role.cluster.arn
  version  = "1.37"

  vpc_config {
    subnet_ids = module.vpc.private_subnet_ids

    # Public so kubectl works from a laptop without a VPN. Access is limited to
    # admin_cidrs instead of the default 0.0.0.0/0.
    endpoint_public_access = true
    public_access_cidrs    = var.admin_cidrs
  }

  access_config {
    authentication_mode = "API"
    # Admin access is granted explicitly below, so it is visible in code.
    bootstrap_cluster_creator_admin_permissions = false
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.cluster_admin_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.admin.principal_arn

  access_scope {
    type = "cluster"
  }
}
