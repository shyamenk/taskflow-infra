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
