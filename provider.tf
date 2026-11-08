provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = var.managed_by
      Repository  = var.repository
      Owner       = var.owner
    }
  }
}
