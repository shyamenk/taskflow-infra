variable "region" {
  type        = string
  description = "Region name for AWS resources"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment name for AWS resources"
  default     = "dev"

  validation {
    condition     = contains(["dev"], var.environment)
    error_message = "environment must be \"dev\" (this project has a single environment)."
  }
}

variable "project_name" {
  type        = string
  description = "Name of the project"
  default     = "taskflow"
}

variable "managed_by" {
  type        = string
  description = "Managed by"
  default     = "terraform"
}

variable "repository" {
  type        = string
  description = "Repository name for AWS resources"
  default     = "taskflow-infra"
}

variable "owner" {
  type        = string
  description = "Name of the owner"
  default     = "shyamenk"
}

variable "admin_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public EKS API endpoint. Set in terraform.tfvars, never commit."

  validation {
    condition     = length(var.admin_cidrs) > 0 && alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0))])
    error_message = "admin_cidrs must be a non-empty list of valid CIDRs, for example [\"203.0.113.10/32\"]."
  }

  validation {
    condition     = !contains(var.admin_cidrs, "0.0.0.0/0")
    error_message = "admin_cidrs must not contain 0.0.0.0/0; that opens the Kubernetes API to the internet."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 Instance Type for EKS Nodes"
  default     = "t3.small"

  # Allow-list, not a free string: the provider does not check the value at plan
  # time, so a typo like "t3-small" would only fail ~minutes into apply.
  # t3.small holds ~11 pods per node; move to t3.medium if ArgoCD pods stay Pending.
  validation {
    condition     = contains(["t3.small", "t3.medium", "t3.large"], var.instance_type)
    error_message = "instance_type must be one of t3.small, t3.medium, t3.large."
  }
}

variable "ami_type" {
  type        = string
  description = "AMI Type for EKS Nodes"

  # x86 on purpose: Graviton (ARM) nodes would need arm64 images, and the CI
  # build produces amd64 by default (exec format error otherwise).
  default = "AL2023_x86_64_STANDARD"
}

variable "min_size" {
  type        = number
  description = "Minimum number of nodes"
  default     = 2
}

variable "desired_size" {
  type        = number
  description = "Desired number of nodes"
  default     = 2

  # Catches an impossible size at plan time instead of as an API error at apply.
  validation {
    condition     = var.desired_size >= var.min_size && var.desired_size <= var.max_size
    error_message = "desired_size must be between min_size and max_size."
  }
}

variable "max_size" {
  type        = number
  description = "Maximum number of nodes"
  default     = 2
}
