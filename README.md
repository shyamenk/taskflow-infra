# taskflow-infra

Terraform for the Taskflow dev environment on AWS: VPC, NAT gateways, IAM roles, and an EKS cluster with a managed node group.

Part of a three-repo GitOps pipeline:

- `taskflow-infra` (this repo) builds the cluster.
- `taskflow-app` builds and pushes the container image.
- `taskflow-gitops` holds the Kubernetes manifests that ArgoCD syncs to the cluster.

Naming: every resource is prefixed `taskflow-dev` and tagged `Project=taskflow`, `Environment=dev`, `ManagedBy=terraform`.
