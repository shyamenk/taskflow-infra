# Changelog

## [Unreleased]

### Changed
- VPC module builds subnets, Elastic IPs, NAT gateways and private route tables with `for_each` keyed by availability zone.
- VPC module rejects public and private subnet lists of different lengths.

### Added
- VPC module `versions.tf` and README.
- README section documenting the CLI state bootstrap.

### Removed
- Commented-out tag blocks in the VPC module.
