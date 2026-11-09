# Changelog

## [Unreleased]

### Added
- EKS control plane `taskflow-dev-eks` (Kubernetes 1.37) in the private subnets, using access entries for authentication, with the Terraform caller granted cluster admin.
- `admin_cidrs` variable restricting the public API endpoint, with `terraform.tfvars.example`.
- EKS cluster role and node role in `iam.tf`, with trust policies from `aws_iam_policy_document` and AWS managed policies attached by `for_each`.
- VPC module `versions.tf` and README.
- README section documenting the CLI state bootstrap.

### Changed
- VPC module builds subnets, Elastic IPs, NAT gateways and private route tables with `for_each` keyed by availability zone.
- VPC module rejects public and private subnet lists of different lengths.

### Removed
- Commented-out tag blocks in the VPC module.
