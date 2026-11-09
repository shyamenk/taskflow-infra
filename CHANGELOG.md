# Changelog

## [Unreleased]

### Added
- Docs record GHCR as the container registry and A10 as deferred.
- Docs refresh after A9: A9 notes and reference, GitHub Actions replaces CircleCI in the plan, stale billing note removed.
- `docs/` folder with the assignments, backlog, build notes and a reference of official docs, required arguments, gotchas and troubleshooting.
- EKS managed node group `taskflow-dev-nodes` (2 x `t3.small`, AL2023 x86) in the private subnets.
- Validated `instance_type`, `ami_type`, `min_size`, `desired_size` and `max_size` variables.
- EKS control plane `taskflow-dev-eks` (Kubernetes 1.37) in the private subnets, using access entries for authentication, with the Terraform caller granted cluster admin.
- `admin_cidrs` variable restricting the public API endpoint, with `terraform.tfvars.example`.
- EKS cluster role and node role in `iam.tf`, with trust policies from `aws_iam_policy_document` and AWS managed policies attached by `for_each`.
- VPC module `versions.tf` and README.
- README section documenting the CLI state bootstrap.

### Changed
- EKS private API endpoint enabled so nodes can reach the control plane while the public endpoint is limited to `admin_cidrs`.
- VPC module builds subnets, Elastic IPs, NAT gateways and private route tables with `for_each` keyed by availability zone.
- VPC module rejects public and private subnet lists of different lengths.

### Removed
- Commented-out tag blocks in the VPC module.
