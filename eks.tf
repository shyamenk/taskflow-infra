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

    # Accepted risk (trivy AWS-0040, critical): the public endpoint stays on so
    # kubectl works from a laptop without a VPN or bastion. The exposure is
    # limited by public_access_cidrs below, and IAM plus access entries still
    # gate every request. Revisit when the cluster gets a VPN or CI-only access.
    #trivy:ignore:AWS-0040
    endpoint_public_access = true

    # Accepted finding (trivy AWS-0041, critical): this flags the CIDR list as
    # open, but admin_cidrs is a variable whose validation rejects 0.0.0.0/0, and
    # the plan shows only the single /32 from terraform.tfvars. Trivy does not
    # evaluate that validation, so the scan cannot see it.
    #trivy:ignore:AWS-0041
    public_access_cidrs = var.admin_cidrs

    # Required because of the allow-list above. The nodes sit in private subnets
    # and reach the API through the NAT gateways, whose IPs are not in admin_cidrs,
    # so over the public endpoint they would be refused and the node group would
    # fail with NodeCreationFailure. The private endpoint lets them reach it
    # from inside the VPC instead.
    endpoint_private_access = true
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

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name}-nodes"
  node_role_arn   = aws_iam_role.node.arn

  # Private subnets only: nodes get no public IPs and reach the internet via NAT.
  subnet_ids = module.vpc.private_subnet_ids

  # A list because a node group can mix instance types (useful for Spot).
  instance_types = [var.instance_type]
  ami_type       = var.ami_type

  # min = desired = max pins two nodes, one per AZ, so cost stays predictable
  # and the cluster autoscaler is not needed for the demo.
  scaling_config {
    min_size     = var.min_size
    desired_size = var.desired_size
    max_size     = var.max_size
  }

  # Terraform cannot see this link because the node group only references the
  # role. Without it, nodes can start before the policies attach, then fail to
  # register with the cluster.
  depends_on = [aws_iam_role_policy_attachment.node]
}
