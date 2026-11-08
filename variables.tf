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
