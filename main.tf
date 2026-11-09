module "vpc" {
  source              = "./modules/vpc"
  cidr_block          = "10.0.0.0/16"
  name                = local.name
  public_subnet_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidr = ["10.0.3.0/24", "10.0.4.0/24"]
  eks_cluster_name    = "${local.name}-eks"
}
