# vpc module

A VPC with one public and one private subnet per availability zone, an internet gateway, and one NAT gateway per zone so private traffic never crosses zones.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | string | none | Name prefix for every resource, for example `taskflow-dev`. |
| `eks_cluster_name` | string | none | Cluster name used in the `kubernetes.io/cluster/<name>` subnet tag. |
| `cidr_block` | string | `10.0.0.0/16` | VPC CIDR. |
| `public_subnet_cidr` | list(string) | `["10.0.1.0/24", "10.0.2.0/24"]` | One CIDR per zone. The list length decides how many zones are used. |
| `private_subnet_cidr` | list(string) | `["10.0.3.0/24", "10.0.4.0/24"]` | Same length and order as the public list. A plan fails if the lengths differ. |

## Outputs

`vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `nat_gateway_ids`, `private_route_table_ids`, `internet_gateway_id`. List outputs are ordered by availability zone name.

## Notes

- Subnets, NAT gateways, Elastic IPs and private route tables are keyed by zone name (`us-east-1a`), so removing one CIDR from a list does not recreate the others.
- Two NAT gateways cost about $65 a month before data transfer. For a throwaway environment, destroy when idle.
