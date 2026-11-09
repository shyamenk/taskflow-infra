variable "cidr_block" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "name" {
  type        = string
  description = "Name prefix"
}


variable "eks_cluster_name" {
  type        = string
  description = "Name of the EKS Cluster"
}

variable "public_subnet_cidr" {
  type        = list(string)
  description = "Public subnet CIDR blocks"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidr" {
  type        = list(string)
  description = "Private subnet CIDR blocks, one per public subnet and in the same order"
  default     = ["10.0.3.0/24", "10.0.4.0/24"]

  validation {
    condition     = length(var.private_subnet_cidr) == length(var.public_subnet_cidr)
    error_message = "private_subnet_cidr must have the same number of entries as public_subnet_cidr (one NAT gateway per availability zone)."
  }
}
