# Step notes

Seeded from what actually happened in A0 to A5. Entries marked `[verify]` need a check against the official docs for the version in `README.md` before they go into a post. Template for new steps is in `README.md`.

---

## A0: Tools and AWS access
- **What we built:** confirmed Terraform, AWS CLI, kubectl and Docker work; confirmed `aws sts get-caller-identity` works with no `--profile`.
- **Fundamentals:** the AWS CLI reads credentials from a chain (environment, shared credentials file, config). With no profile set it uses the default. `aws configure list` shows where each value comes from.
- **Best practices:** use SSO or short-lived role credentials, not long-lived static keys on an admin user [verify against the IAM best-practices page]. Set a cost budget before creating billable resources.
- **Common mistakes:** the tutorial creates an admin IAM user with static access keys. Skipping the budget alert means nothing warns you about NAT and EKS charges.
- **Troubleshooting tip:** `kubectl: command not found` meant the tool was simply not installed. On Arch, `sudo pacman -S kubectl`.
- **Post angle:** "Before you run terraform apply: the three checks I do first." Status: raw.

## A1: Repo conventions
- **What we built:** three public repos (`taskflow-app`, `taskflow-infra`, `taskflow-gitops`) with `.gitignore`, README and `SECURITY.md`.
- **Fundamentals:** public repos mean anything committed is visible forever, even if deleted later.
- **Best practices:** ignore `*.tfstate*`, `.terraform/`, `*.tfvars`, keys and kubeconfig; commit `.terraform.lock.hcl`; enable secret scanning and push protection (GitHub had both on for these public repos).
- **Common mistakes:** first draft of the infra `.gitignore` ignored only `*.auto.tfvars`, which would have let a plain `terraform.tfvars` through. Fixed with `*.tfvars` plus `!*.tfvars.example`.
- **Troubleshooting tip:** `git check-ignore -v <file>` shows which rule ignores a file.
- **Version note:** pushing over SSH failed with `Permission denied (publickey)` in one environment; `gh` over HTTPS worked.
- **Post angle:** "Your Terraform repo is public. What must never be in it." Status: raw.

## A2: Remote state
- **What we built:** versioned, private, encrypted S3 bucket plus an S3 backend with locking.
- **Fundamentals:** state maps your config to real resources; losing or corrupting it is the worst Terraform failure. A backend block tells Terraform where to store state; it does not configure the bucket.
- **Best practices:** versioning on, public access fully blocked, encryption on, locking on. Newer Terraform can lock in S3 with `use_lockfile`, so a DynamoDB table is not needed [checked 2026-11-09: the S3 backend page marks `use_lockfile` optional (default `false`), says DynamoDB locking is deprecated, and does not state the Terraform version that introduced it]. Docs: https://developer.hashicorp.com/terraform/language/backend/s3
- **Common mistakes (all seen):**
  - Putting `versioning_configuration` inside the `backend "s3"` block. The backend does not create or modify the bucket; versioning is set on the bucket with the CLI.
  - Assuming a new bucket is protected. `get-public-access-block` returned all four settings `false` until set explicitly.
  - Changing the backend block after the first init: `Error: Backend configuration changed`.
- **Fix:** `terraform init -reconfigure` when there is no state to migrate; `-migrate-state` when there is.
- **Troubleshooting tip:** a plan that ends with `Releasing state lock` shows locking is working. Verify the bucket with `aws s3api get-bucket-versioning` and `get-public-access-block`.
- **Version note:** for `us-east-1`, `create-bucket` needs no location constraint [checked 2026-11-09: `--create-bucket-configuration` is optional and the CLI example for us-east-1 omits it; regions outside us-east-1 need a `LocationConstraint`].
- **Post angle:** "Terraform state: the bucket settings that are not on by default." Status: raw.

## A3: Provider, variables, locals, default tags
- **What we built:** pinned provider, variables with validation, `locals.name = taskflow-dev`, `default_tags` on every resource.
- **Fundamentals:** variables are inputs, locals are computed values, `default_tags` stamps every taggable resource from one place.
- **Best practices:** pin the provider by major version; use a lower-bound `required_version`; validate input values.
- **Common mistakes (all seen):**
  - Hard-coding region and tags in the provider block so the variables did nothing, and a variable default (`ap-south-1`) that disagreed with the state bucket region.
  - `required_version = "~> 1.15.1"` allows only 1.15.x and blocks 1.16 and later.
  - `environment = "prd"` was accepted silently until a `validation` block was added.
- **Troubleshooting tip:** test a validation with `terraform plan -var environment=prd` and confirm the error text.
- **Version note:** the tutorial pins AWS provider 4.67.0; this build runs 6.72.0, so argument names changed (see A4, A5).
- **Post angle:** "Four lines of Terraform that tag everything you create." Status: raw.

## A4: VPC module
- **What we built:** VPC, internet gateway, 2 public and 2 private subnets across 2 zones, public route table, Kubernetes subnet tags.
- **Fundamentals:** a subnet is public only because its route table sends `0.0.0.0/0` to an internet gateway. A module is a function: the root calls it and passes inputs.
- **Best practices:** look up zones with the `aws_availability_zones` data source; tag subnets for EKS (`kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb`, `kubernetes.io/cluster/<name>`); docs: https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html
- **Common mistakes (all seen):**
  - Module call placed inside the module's own folder, and a folder named `" modules"` with a leading space.
  - `locals.name` vs `local.name`: the block is `locals { }`, the reference is `local.name`; a module cannot see the root's locals, so pass the value in as a variable.
  - Variable defaults cannot reference locals (`Variables not allowed`).
  - Inventing resource types (`aws_subnet_public`); the provider has one `aws_subnet`, the label carries public/private.
  - Using `count.index` in a resource that has no `count`.
  - Subnet using the VPC's own CIDR; route to the VPC CIDR instead of `0.0.0.0/0`.
- **Troubleshooting tip:** `terraform validate` after every small change; read the first error only, later ones are often consequences.
- **Version note:** the 6.72.0 `aws_vpc` docs list no ClassicLink arguments [checked 2026-11-09; when they were removed is not stated there].
- **Post angle:** "What makes a subnet public (it is one route)." Status: raw.

## A5: NAT gateways and private routing
- **What we built:** 2 Elastic IPs, 2 NAT gateways (one per public subnet), 2 private route tables, associations.
- **Fundamentals:** private instances reach the internet through a NAT gateway that sits in a public subnet; nothing on the internet can start a connection to them.
- **Best practices:** one NAT per zone for resilience (cost: each NAT gateway bills hourly plus per-GB data; the us-east-1 rate was not in the fetched pricing text, the page's example uses $0.045 an hour for US East (Ohio) [unverified for us-east-1]; each Elastic IP is $0.005 an hour per the VPC pricing page, checked 2026-11-09); `depends_on` the internet gateway.
- **Common mistakes (all seen):**
  - Attaching private subnets to the public route table. They would be public in practice, and the NAT gateways would be unused.
  - Putting `nat_gateway_id` on a route table association. The route belongs in the `aws_route_table`; the association only links subnet to table.
  - Adding an unneeded `aws_network_interface` copied from a docs example.
  - Missing index: `aws_route_table.private_rt.id` when the resource uses `count`.
- **Version note:** `aws_eip` uses `domain = "vpc"` on provider 6.72.0 (the 6.72.0 docs show `domain = "vpc"` in every example and list no `vpc` argument) [checked 2026-11-09].
- **Troubleshooting tip:** the plan output is the review: count resources, read every `Name` tag, check each private route table points at the NAT in its own zone.
- **Post angle:** "Why my private subnets were secretly public (one wrong route table association)." Status: raw.

## Environment issues worth a post
- **Corrupt local git repo:** `object file ... is empty` / `bad object HEAD` after an interrupted write. Fix: back up `.git`, then `git init`, fetch from the remote, `git reset --mixed origin/main` (keeps working files). Verify with `git fsck`.
- **zsh `compdef` error** when running `aws`: use plain bash to run the command; the cause is shell startup scripts, not the CLI.

---

## A6: IAM roles for EKS
- **What we built:** a cluster role (trusted by `eks.amazonaws.com`, policy `AmazonEKSClusterPolicy`) and a node role (trusted by `ec2.amazonaws.com`, policies `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`).
- **Fundamentals:** a role has no keys; something assumes it. Two layers: the trust policy says who may assume it, the permission policies say what it can do. Mixing them up is the classic mistake.
- **Best practices:** AWS managed policies for these two roles, trust policy from `aws_iam_policy_document` (not a JSON heredoc), attachments with `for_each` over policy ARNs. Docs: https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html and https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html [open and re-check the policy names for your version]
- **Common mistakes (all seen):**
  - Pasting a JSON policy from the docs inside an HCL `statement` block: `Error: Invalid argument name` ... `Argument names must not be quoted.`
  - Leaving the docs example `aws_iam_policy "example"` in the file; it would have created a real policy.
  - A name mismatch between declaration and reference: `A managed resource "aws_iam_role" "nodes" has not been declared in the root module.` (the role was declared as `node`).
  - The tutorial's extra `ElasticLoadBalancingFullAccess` on the cluster role was left out on purpose [checked 2026-11-09: the cluster role page names `AmazonEKSClusterPolicy` and says nothing about `ElasticLoadBalancingFullAccess`; it notes the minimal custom policy does not let the legacy cloud provider create load balancers].
- **Fix:** write one block at a time and run `terraform validate` after each; read the first error only.
- **Troubleshooting tip:** the plan count is a check: 17 networking + 2 roles + 4 attachments = 23.
- **Why ReadOnly for ECR:** nodes only pull images, so a read-only registry policy is enough.
- **Post angle:** "Two IAM roles every EKS cluster needs, and the difference between who can assume a role and what it can do." Status: raw.

## A7: EKS cluster and node group
- **What we built:** cluster `taskflow-dev-eks` on Kubernetes 1.37 in the private subnets, authentication through access entries, and a managed node group of 2 x `t3.small` (AL2023 x86) with scaling min = desired = max = 2.
- **Fundamentals:** the control plane is run by AWS and billed hourly; nodes are your own EC2 machines. `authentication_mode = "API"` means access is managed with access entries (AWS resources), not an in-cluster ConfigMap.
- **Best practices:**
  - Pick the Kubernetes version from AWS, not from a video. `aws eks describe-cluster-versions` showed 1.37 in standard support until 2027-12-01 and as the default version. Docs: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  - Confirm the node AMI exists for that version before applying: the SSM parameter `/aws/service/eks/optimized-ami/1.37/amazon-linux-2023/x86_64/standard/recommended/image_name` returned `amazon-eks-node-al2023-x86_64-standard-1.37-v20261031`.
  - Grant admin explicitly: `bootstrap_cluster_creator_admin_permissions = false` plus an access entry and `AmazonEKSClusterAdminPolicy` for your own identity, so access is visible in code.
  - Use an allow-list `validation` for values the provider only checks at apply time (instance type).
  - Run `trivy config .` and decide each finding. Findings AWS-0040 (public endpoint) and AWS-0041 (open CIDR) were accepted with a written reason via `#trivy:ignore`; AWS-0039 (KMS secrets), AWS-0038 (logging) and AWS-0178 (VPC flow logs) were deferred.
- **Common mistakes (all seen in review, before apply):**
  - `public_access_cidrs = "x.x.x.x"` as a string: `set of string required, but have string.` It needs a list of CIDRs such as `["x.x.x.x/32"]`.
  - Hard-coding a home IP in a public repo. Fix: a variable with no default, the value in git-ignored `terraform.tfvars`, a placeholder in `terraform.tfvars.example`, and a validation that rejects `0.0.0.0/0`.
  - The access entry pointed at the cluster's own service role instead of the human identity, and the policy was `AmazonEKSViewPolicy` scoped to `kube-system`. The plan could not catch it; it would have meant `kubectl` denied after apply.
  - `instance_type` default `t3-small` (dash, not dot). It appeared in the plan as `instance_types = ["t3-small"]`, and Terraform does not check it until apply.
  - A private cluster endpoint left off while the public endpoint is limited to one IP. The nodes reach the API through the NAT gateway IPs, which are not in the allow-list. The EKS endpoint page recommends enabling the private endpoint when you limit the public CIDRs, or including the nodes' public egress addresses in the list [checked 2026-11-09]. It does not say what happens otherwise and never mentions `NodeCreationFailure`, so that predicted failure is `[unverified]`; we fixed the config before seeing it. The private endpoint also needs `enableDnsHostnames` and `enableDnsSupport` on the VPC..
  - An editor saved an old buffer over `eks.tf` and brought back the IP and the wrong principal; `git restore eks.tf` fixed it.
- **Fix:** `endpoint_private_access = true`; the allow-listed variable; read the saved plan (`terraform plan -out=tfplan`, then `terraform apply tfplan`) so you apply exactly what you reviewed.
- **Troubleshooting tip:** a plan passing does not mean apply passes. Read literal values (names, instance types, CIDRs) in the plan; ignore `(known after apply)`.
- **Real numbers (apply on 2026-11-09):** 27 resources added; cluster 9m56s, node group 2m2s, NAT gateways about 1m50s each, whole apply 12m20s. A `t3.small` node reported 11 allocatable pods and about 1.4 GiB allocatable memory (`1467988Ki`).
- **Cost note:** the only confirmed numbers (2026-11-09) are EKS $0.10 per cluster per hour for standard support ($0.60 with extended support) and $0.005 per hour per public IPv4 address; the NAT gateway rate for us-east-1 and the `t3.small` price were not in the fetched pricing pages, so the earlier "about $0.23 an hour" total is `[unverified]`.
- **Version note:** the tutorial's `AL2_x86_64` and Kubernetes 1.27 are outdated; this build uses `AL2023_x86_64_STANDARD` and 1.37. Nodes run containerd 2.3.x; Docker is not a runtime on them.
- **Post angle:** "The EKS plan that looked perfect and would have failed: 3 mistakes a plan cannot catch." Status: raw.

## A8: Connect with kubectl
- **What we built:** a kubeconfig entry for `taskflow-dev-eks`; result: 2 nodes `Ready` (v1.37.1-eks-6e7947a) in `us-east-1a` and `us-east-1b`, and 6 `kube-system` pods `Running` (2 `aws-node`, 2 `coredns`, 2 `kube-proxy`).
- **Fundamentals:** `aws eks update-kubeconfig` writes to the file named by the `KUBECONFIG` variable if it is set, otherwise to `~/.kube/config`. Authentication then comes from your AWS identity plus the access entry.
- **Best practices:** use an `--alias` for a short context name (`taskflow-dev`); one cluster per context; do not export a global `KUBECONFIG` that points at a single project's file.
- **Common mistakes (seen):** the cluster landed in `~/.kube/hooli-box.yaml` because `~/.zshrc` exported `KUBECONFIG` to that file from an earlier project. Terminals opened before the export was removed keep the old value.
- **Fix:** remove the export, `unset KUBECONFIG` in old terminals, run `aws eks update-kubeconfig --name taskflow-dev-eks --region us-east-1 --alias taskflow-dev`.
- **Troubleshooting tip:** `echo $KUBECONFIG` before blaming AWS; `kubectl config get-contexts` shows where you are. If `kubectl` times out later, your public IP may have changed and no longer matches `admin_cidrs`.
- **Version note:** mise per-directory `[env]` variables need `mise activate`; this machine uses static shims for startup speed, so they would be ignored.
- **Post angle:** "Why `kubectl` pointed at the wrong cluster file: one forgotten export." Status: raw.

## Environment issues (added)
- **Public repo hygiene:** a home IP almost reached a public repo; caught in review by scanning the staged diff. Keep per-person values in git-ignored `terraform.tfvars`.
- **Editor overwrite:** a stale open buffer replaced a file edited on disk. Close the file before another tool edits it; `git restore` recovers anything committed.
- **`git pull` over a URL** does not update `origin/main`, so the prompt shows `[⇡]` until `git fetch`.

---

## A9 onward (fill in as you go)
A9 Docker / A10 CI / A11 manifests / A12 CI updates manifests / A13 ArgoCD / A14 GitOps loop / A15 teardown / A16 write-up. Copy the template from `README.md` for each.
