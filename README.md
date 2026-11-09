# taskflow-infra

Terraform for the Taskflow dev environment on AWS. Built so far: VPC with NAT gateways. Planned: IAM roles and an EKS cluster with a managed node group.

Part of a three-repo GitOps pipeline:

- `taskflow-infra` (this repo) builds the cluster.
- `taskflow-app` builds and pushes the container image.
- `taskflow-gitops` holds the Kubernetes manifests that ArgoCD syncs to the cluster.

Naming: every resource is prefixed `taskflow-dev` and tagged `Project=taskflow`, `Environment=dev`, `ManagedBy=terraform`.

## Configuration

Copy `terraform.tfvars.example` to `terraform.tfvars` (git-ignored) and set:

| Variable | Meaning |
|----------|---------|
| `admin_cidrs` | CIDRs allowed to reach the public EKS API endpoint, for example your own IP as `x.x.x.x/32`. `0.0.0.0/0` is rejected. If `kubectl` starts timing out, your IP probably changed: update this and apply. |

## State bootstrap (one time, by CLI)

Terraform cannot create the bucket that stores its own state, so the bucket was created by hand with default AWS credentials. To recreate it in another account, replace `<account-id>`:

```sh
B=taskflow-tfstate-<account-id>-use1
aws s3api create-bucket --bucket $B --region us-east-1   # no location constraint in us-east-1
aws s3api put-bucket-versioning --bucket $B --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket $B --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --bucket $B --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

Then update `bucket` in `backend.tf` and run `terraform init`. Locking uses `use_lockfile` in the same bucket, so no DynamoDB table is needed.

## Checks

```sh
terraform fmt -check -recursive
terraform validate
tflint --recursive
```
