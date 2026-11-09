# Taskflow reference: docs, required arguments, gotchas

How to use this file: open the section for the step you are on, open the linked official page, then read "Must be there" and "Mistakes" before you write code. Everything here was checked on this project (Terraform 1.15.9, AWS provider 6.72.0, AWS CLI 2.37.9, Kubernetes 1.37). Items marked `[unverified]` were not observed here; check the official page before relying on them. Claims tagged `(checked 2026-11-09)` were confirmed against the official page or by running the command.

---

## 1. How to read the docs

### Terraform / provider docs (registry.terraform.io, developer.hashicorp.com)
- **Switch the version selector to the version you run** (6.72.0 here). The "latest" page can describe arguments your provider does not have yet. Open the page from the registry URL with the version in it, for example `https://registry.terraform.io/providers/hashicorp/aws/6.72.0/docs/resources/eks_cluster`.
- **Read in this order:** Example Usage, then **Argument Reference** (what you write; "Required" is marked and nested blocks are listed separately), then **Attribute Reference** (what you can read back, such as `.arn` and `.id`), then **Import** only when adopting existing resources.
- **The docs beat the schema for "one of" rules.** The provider schema marks an argument required only when it is always required. "Provide one of A or B" rules are written in prose in the docs, so read the sentence under each argument.
- **Get the required list offline, for your exact version:**
  ```sh
  terraform providers schema -json | jq -r '.provider_schemas["registry.terraform.io/hashicorp/aws"].resource_schemas["aws_eks_cluster"].block.attributes | to_entries[] | select(.value.required) | .key'
  ```
  This printed `name` and `role_arn` for the cluster. Required nested blocks need a second query on `block_types` (see section 2).

### AWS docs (docs.aws.amazon.com)
- **Pick the right guide type:** the *User Guide* explains concepts and procedures, the *API reference* lists every field and its limits, and the *CLI reference* shows command shapes. Concepts first, then CLI or API for exact names.
- **Check "Region" and "Version" notes on the page.** Many EKS pages describe a specific Kubernetes version or feature that is not in every region. The AWS CLI is also a source of truth: `aws eks describe-cluster-versions` told us 1.37 was supported when the docs page was only a list.
- **When docs and reality disagree, ask AWS:** `aws ... describe-*` shows the actual state (see each section's "Troubleshooting").

### The three habits
1. Open the docs for the version you actually run.
2. Copy the **names** from docs (policy names, argument names) but type the **values** yourself; most mistakes here were pasted examples that did not fit.
3. After writing a block, run `terraform validate`, then read the first error only.

---

## 2. What must be in each Terraform block

| Block | Required | Strongly recommended | Notes from this project |
|---|---|---|---|
| `terraform { }` | nothing | `required_version`, `required_providers` with `source` and `version` | `~> 1.15.1` would block 1.16; we use `>= 1.15`. Docs: https://developer.hashicorp.com/terraform/language/block/terraform |
| `backend "s3"` | `bucket`, `key`, and `region` (or `AWS_REGION`) | `encrypt = true`, `use_lockfile = true` | The backend never creates the bucket. Docs: https://developer.hashicorp.com/terraform/language/backend/s3 |
| `provider "aws"` | nothing | `region`, `default_tags` | Credentials come from the AWS credential chain, not the block. |
| `variable` | nothing | `type`, `description`, `default` or none on purpose | A `validation` needs both `condition` and `error_message`. A default cannot reference `locals`. Docs: https://developer.hashicorp.com/terraform/language/block/variable |
| `locals` | nothing | one value per name | Referenced as `local.x`, declared as `locals { }`. Not visible inside child modules. |
| `output` | `value` | `description` | |
| `module` | `source` | `version` for registry modules | Plus every child variable that has no default. Docs: https://developer.hashicorp.com/terraform/language/block/module |
| `data` | the type's required arguments (often none) | | Read-only lookup; evaluated at plan time. |
| `resource` | type, local name, and the type's required arguments | `depends_on` only for hidden links | Use `for_each` over a map or set; `count` shifts indexes when you remove an item. Docs: https://developer.hashicorp.com/terraform/language/meta-arguments/for_each |

---

## A0: Tools and AWS access
- **Docs to open:** AWS CLI quickstart https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html , budgets https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html , IAM concepts https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_terms-and-concepts.html
- **Must be there:** working credentials (`aws sts get-caller-identity`), a cost guard (budget alert, or a written teardown plan), tools on PATH.
- **Version gotchas:** none; check `terraform version`, `aws --version`, `kubectl version --client` and record them in `README.md`.
- **Mistakes:** the tutorial's admin IAM user with static keys; no budget alert (we skipped it on purpose, so teardown is the cost control).
- **Troubleshooting:** `aws configure list` shows which credential source is in use; `aws sts get-caller-identity` shows who AWS thinks you are. A shell function named `aws` printed nothing here (`compdef` noise from shell startup): run the real binary from `bash --noprofile --norc`.

## A1: Repo conventions
- **Docs to open:** Terraform ignore guidance and the GitHub secret-scanning docs.
- **Must be there:** `.gitignore` covering `.terraform/`, `*.tfstate*`, `*.tfvars` (with `!*.tfvars.example`), keys, kubeconfig; commit `.terraform.lock.hcl`; `SECURITY.md`.
- **Mistakes:** ignoring only `*.auto.tfvars` (a plain `terraform.tfvars` would have gone through).
- **Troubleshooting:** `git check-ignore -v <file>` names the rule that ignores a file. Always read `git diff --staged` in a public repo. SSH push failed here; `gh` over HTTPS worked.

## A2: Remote state (S3 backend)
- **Docs to open:** https://developer.hashicorp.com/terraform/language/backend/s3 and S3 bucket creation https://docs.aws.amazon.com/AmazonS3/latest/userguide/creating-bucket.html
- **Must be there:**
  - Backend block: `bucket`, `key`, `region`. Add `encrypt = true` and `use_lockfile = true` (S3-native locking; no DynamoDB table needed on this Terraform version).
  - Bucket (created outside Terraform): versioning on, all four public-access blocks on, default encryption on.
- **Version gotchas (checked 2026-11-09):** the S3 backend page lists `bucket`, `key` and `region` as required, `use_lockfile` as optional (default `false`), and says DynamoDB-based locking is deprecated and will be removed in a future minor version. The Terraform version that introduced `use_lockfile` is not stated on that page. For `s3api create-bucket`, `--create-bucket-configuration` is optional and the CLI example for `us-east-1` runs without it; regions other than `us-east-1` need a `LocationConstraint`.
- **Mistakes:** putting `versioning_configuration` in the backend block (the backend does not manage the bucket); assuming a new bucket is private; `Backend configuration changed` after editing the backend block.
- **Fix:** `terraform init -reconfigure` when there is no state to move; `-migrate-state` when there is.
- **Troubleshooting:** a plan ending in `Releasing state lock` shows locking works; `aws s3api get-bucket-versioning` and `get-public-access-block` show the real bucket settings. The bucket name contains the account ID and cannot be renamed.

## A3: Provider, variables, locals, default tags
- **Docs to open:** provider docs https://registry.terraform.io/providers/hashicorp/aws/6.72.0/docs and version constraints https://developer.hashicorp.com/terraform/language/expressions/version-constraints
- **Must be there:** `required_providers` with `source = "hashicorp/aws"` and a version constraint; `default_tags` driven by variables; one `locals.name`.
- **Version gotchas:**
  - `~> 6.0` allows any 6.x; `~> 1.15.1` allows only 1.15.x.
  - The tutorial's provider 4.67.0 is old; on 6.x every resource has its own `region` attribute (visible in plans as `region = "us-east-1"`), and some arguments changed (`aws_eip` uses `domain = "vpc"`, not `vpc = true`).
  - `.terraform.lock.hcl` pins the exact provider build; commit it.
- **Mistakes:** hard-coding region and tags in the provider block so variables did nothing; a default region that disagreed with the state bucket; `environment = "prd"` silently accepted until a `validation` block existed.
- **Troubleshooting:** `terraform plan -var environment=prd` tests a validation; `terraform providers` shows which provider versions are in use; `echo 'local.name' | terraform console` evaluates a value.

## A4: VPC module
- **Docs to open:** https://registry.terraform.io/providers/hashicorp/aws/6.72.0/docs/resources/vpc , `.../resources/subnet` , https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html , https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html
- **Required arguments (from the 6.72.0 schema):**

  | Resource | Schema-required | In practice also |
  |---|---|---|
  | `aws_vpc` | none | `cidr_block`, or IPAM (`ipv4_ipam_pool_id` with `ipv4_netmask_length`); both optional in the docs (checked 2026-11-09) |
  | `aws_subnet` | `vpc_id` | `cidr_block`, `availability_zone` |
  | `aws_internet_gateway` | none | `vpc_id` (to attach it) |
  | `aws_route_table` | `vpc_id` | a `route` block with a target |
  | `aws_route_table_association` | `route_table_id` | one of `subnet_id` or `gateway_id`; the docs say "one of either `subnet_id` or `gateway_id` is required" and that each conflicts with the other (checked 2026-11-09) |
  | `data "aws_availability_zones"` | none | `state = "available"` |

  "Schema-required: none" does not mean "write nothing". Read the sentence in the docs.
- **Must be there for EKS:** subnet tags `kubernetes.io/role/elb` (public) and `kubernetes.io/role/internal-elb` (private), plus `kubernetes.io/cluster/<cluster-name>`; DNS hostnames and DNS support on the VPC.
- **Version gotchas:** the 6.72.0 `aws_vpc` docs list no ClassicLink arguments at all, so the tutorial's `enable_classiclink` has no place there (checked 2026-11-09; when it was removed is not stated on that page).
- **Mistakes (all seen):** module call placed inside the module folder; a folder named `" modules"` with a leading space; `locals` vs `local`; a module cannot see the root's locals; variable defaults cannot reference locals (`Variables not allowed`); invented resource types such as `aws_subnet_public`; `count.index` on a resource with no `count`; a subnet using the VPC's own CIDR.
- **Troubleshooting:** `terraform validate` after every small change and fix the first error only. Use `for_each` keyed by AZ name, so removing one CIDR does not recreate the rest.

## A5: NAT gateways and private routing
- **Docs to open:** https://registry.terraform.io/providers/hashicorp/aws/6.72.0/docs/resources/nat_gateway , `.../resources/eip` , https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html
- **Required arguments:** `aws_eip` and `aws_nat_gateway` have none in the schema. The docs make `allocation_id` and `subnet_id` required for a zonal public NAT gateway (the default `availability_mode = "zonal"`, `connectivity_type = "public"`), and `subnet_id` must be a **public** subnet (checked 2026-11-09). Provider 6.72.0 also has a `regional` NAT mode (`availability_mode`, `vpc_id`, `availability_zone_address`); we did not use it.
- **Must be there:** `depends_on = [aws_internet_gateway.igw]`; one private route table per AZ with `0.0.0.0/0` pointing at the NAT in the same AZ; each private subnet associated with its own table.
- **Version gotchas:** the 6.72.0 `aws_eip` docs show `domain = "vpc"` in every example and do not list a `vpc` argument (checked 2026-11-09; whether it was deprecated first is not stated there). The NAT gateway docs include newer regional-mode fields, so docs for older versions will not match.
- **Mistakes (all seen):** private subnets on the public route table (they would be public in practice); `nat_gateway_id` on an association instead of the route; a copied `aws_network_interface` that was not needed; `aws_route_table.private_rt.id` without an index when the resource uses `count`/`for_each`.
- **Cost (checked 2026-11-09):** the VPC pricing page lists $0.005 per hour for each in-use public IPv4 address (so each Elastic IP costs $0.005 an hour). It does not show a us-east-1 NAT gateway rate in the fetched text; its worked example uses $0.045 an hour for US East (Ohio), so treat the us-east-1 NAT rate as `[unverified]` and look it up before quoting a number. Data processing is charged per GB on top.
- **Troubleshooting:** the plan is the review: count resources (17), read every `Name` tag, check each private route table points at the NAT in its own AZ. `aws ec2 describe-nat-gateways --filter Name=tag:Project,Values=taskflow` lists the live ones (returned 2).

## A6: IAM roles for EKS
- **Docs to open:** https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html (cluster role) , https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html (node role) , https://registry.terraform.io/providers/hashicorp/aws/6.72.0/docs/data-sources/iam_policy_document
- **Required arguments (schema):**

  | Block | Required |
  |---|---|
  | `aws_iam_role` | `assume_role_policy` (`name` is optional; we set it for readable names) |
  | `aws_iam_role_policy_attachment` | `role` (the role **name**), `policy_arn` |
  | `data "aws_iam_policy_document"` | none, but needs at least one `statement` |
  | `statement.principals` | `type`, `identifiers` |
  | `statement.condition` | `test`, `variable`, `values` |

  `effect` defaults to `Allow`; `actions` is what you must give.
- **Must be there (checked 2026-11-09):** cluster role trusted by `eks.amazonaws.com` (action `sts:AssumeRole`) with `AmazonEKSClusterPolicy`, or a custom policy. Node role trusted by `ec2.amazonaws.com` with `AmazonEKSWorkerNodePolicy` and `AmazonEC2ContainerRegistryPullOnly`; the node role page also lists `AmazonEKS_CNI_Policy` but recommends attaching it to a role mapped to the `aws-node` service account instead of the node role.
- **Where this repo differs from the docs:** `iam.tf` attaches `AmazonEC2ContainerRegistryReadOnly` (not named on the node role page) and attaches `AmazonEKS_CNI_Policy` to the node role. Both work, but the docs point to `AmazonEC2ContainerRegistryPullOnly` and a service-account role for the CNI. Candidate change for the refactor.
- **Version gotchas:** managed policy names are added over time (the node role page now names `AmazonEC2ContainerRegistryPullOnly`); the docs page is the source.
- **Mistakes (all seen):** JSON from the docs pasted into an HCL `statement` (`Argument names must not be quoted`); a leftover docs example `aws_iam_policy "example"`; `role` given a name that was never declared (`aws_iam_role.nodes` vs `node`); the tutorial's `ElasticLoadBalancingFullAccess` on the cluster role (left out).
- **Troubleshooting:** two layers, trust policy (who may assume) and permission policies (what it can do). If a service cannot assume a role, the trust policy is wrong; if it can assume but is denied, a permission is missing. `aws iam list-attached-role-policies --role-name <role>` lists attachments (run against `AWSServiceRoleForAmazonEKS`: returned `AmazonEKSServiceRolePolicy`).

## A7a: EKS control plane
- **Docs to open:** https://registry.terraform.io/providers/hashicorp/aws/6.72.0/docs/resources/eks_cluster , `.../resources/eks_access_entry` , `.../resources/eks_access_policy_association` , https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html , https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html , https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html
- **Required arguments (schema):**

  | Block | Required |
  |---|---|
  | `aws_eks_cluster` | `name`, `role_arn`, and a `vpc_config` block |
  | `vpc_config` | `subnet_ids` |
  | `access_config` | none (but set `authentication_mode`) |
  | `aws_eks_access_entry` | `cluster_name`, `principal_arn` |
  | `aws_eks_access_policy_association` | `cluster_name`, `policy_arn`, `principal_arn`, and an `access_scope` block |
  | `access_scope` | `type` (`cluster` or `namespace`; namespace scope also needs `namespaces`) |

  `role_arn` takes an **ARN** while the IAM attachment's `role` takes a **name**.
- **Must be there:** a pinned `version`; `depends_on` the cluster role's policy attachment; a deliberate endpoint decision (`endpoint_public_access`, `endpoint_private_access`, `public_access_cidrs`); an explicit admin grant when `bootstrap_cluster_creator_admin_permissions = false`.
- **Version gotchas:** list supported versions from AWS, not from a video: `aws eks describe-cluster-versions --region us-east-1` (1.37 was in standard support until 2027-12-01). Omitting `version` lets AWS pick its default. On `authentication_mode = "API"`, access is managed by access entries, not the old ConfigMap.
- **Mistakes (all seen in review):** `public_access_cidrs` as a string instead of `["x.x.x.x/32"]`; a home IP hard-coded in a public repo; the access entry pointed at the cluster's service role instead of a human identity; the wrong policy (`AmazonEKSViewPolicy` on `kube-system` instead of `AmazonEKSClusterAdminPolicy` with `type = "cluster"`).
- **Troubleshooting:** the plan cannot tell if a principal is the right person, so read the ARN. The EKS endpoint page (checked 2026-11-09) says: if you limit access to specific CIDR blocks, it recommends also enabling the private endpoint, or making sure the CIDRs include the addresses nodes access the public endpoint from. A private endpoint needs `enableDnsHostnames` and `enableDnsSupport` on the VPC. `aws eks describe-cluster --name <name> --query cluster.status` shows `CREATING`/`ACTIVE`; `aws eks list-access-entries --cluster-name <name>` lists who can reach the cluster.

## A7b: Managed node group
- **Docs to open:** https://registry.terraform.io/providers/hashicorp/aws/6.72.0/docs/resources/eks_node_group , https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html
- **Required arguments (schema):** `aws_eks_node_group`: `cluster_name`, `node_role_arn`, `subnet_ids`, and a `scaling_config` block with `min_size`, `max_size`, `desired_size`. `node_group_name` and `instance_types` are optional but you should set them.
- **Must be there:** `depends_on` the node role's policy attachments; `instance_types` as a **list**; an AMI type valid for your Kubernetes version.
- **Version gotchas:** the tutorial's `AL2_x86_64` and Kubernetes 1.27 are outdated; we used `AL2023_x86_64_STANDARD` on 1.37. Confirm an image exists before applying:
  `aws ssm get-parameter --region us-east-1 --name /aws/service/eks/optimized-ami/1.37/amazon-linux-2023/x86_64/standard/recommended/image_name` returned `amazon-eks-node-al2023-x86_64-standard-1.37-v20261031`. Graviton (`t4g`) nodes use ARM and need arm64 images.
- **Mistakes (seen):** `instance_type` typo `t3-small` (dash) that the plan did not catch because the provider only checks it at apply; a private cluster endpoint left off while the public endpoint was limited to one IP. The EKS endpoint page recommends enabling the private endpoint in that case (checked 2026-11-09); it does not say what happens to nodes otherwise and does not mention `NodeCreationFailure`, so that predicted error is `[unverified]`.
- **Fix:** an allow-list `validation` on `instance_type`; `endpoint_private_access = true`.
- **Troubleshooting:** `aws eks describe-nodegroup --cluster-name <c> --nodegroup-name <n> --query 'nodegroup.[status,health.issues]'` (returned `ACTIVE` and `[]`) shows why nodes failed to join. `kubectl get nodes -o wide` and `kubectl describe node <n>` show capacity; a `t3.small` showed 11 allocatable pods and about 1.4 GiB memory.
- **Also true:** EKS created an access entry for the node role by itself (`aws eks list-access-entries` shows it); you do not write that one.

## A8: Connect with kubectl
- **Docs to open:** https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html
- **Required arguments:** `aws eks update-kubeconfig --name <cluster>`; use `--region` and `--alias` to be clear and short.
- **Must be there:** an access entry for your identity (A7a); your IP in `admin_cidrs`; a `kubectl` within one minor version of the cluster (client 1.37.1 vs cluster 1.37).
- **Version gotchas:** `update-kubeconfig` writes to the file named by `KUBECONFIG` if it is set, otherwise to `~/.kube/config`.
- **Mistakes (seen):** a leftover `export KUBECONFIG=...` in `~/.zshrc` sent the new cluster into an old project's file; terminals opened before the fix keep the old value; mise `[env]` entries are ignored when mise runs as static shims.
- **Troubleshooting:** `echo $KUBECONFIG` first; `kubectl config get-contexts` shows where you are; `kubectl config current-context`. If `kubectl` times out, your public IP no longer matches `admin_cidrs`; if it says Unauthorized or Forbidden, check access entries. Done check: `kubectl get nodes` shows 2 nodes `Ready` and `kubectl get pods -n kube-system` shows `aws-node`, `coredns`, `kube-proxy` running.

---

## A9: Container image
- **Docs to open:** Dockerfile reference https://docs.docker.com/reference/dockerfile/ , multi-stage builds https://docs.docker.com/build/building/multi-stage/ , build cache https://docs.docker.com/build/cache/optimize/ , nginx headers module https://nginx.org/en/docs/http/ngx_http_headers_module.html , the runtime image https://hub.docker.com/r/nginxinc/nginx-unprivileged
- **Must be there:**
  - Dockerfile: a `FROM` for every stage (`FROM ... AS name` for stages you copy from), `COPY --from=<stage>` to take files across, a pinned tag on each base image, and `npm ci` (not `npm install`) in the build stage.
  - `.dockerignore`: at least `node_modules`, `dist`, `.git`, `.env*`, logs.
  - nginx: a `server` with `listen 8080` for the unprivileged image, a `root`, and `try_files $uri $uri/ /index.html` for a single-page app.
- **Version gotchas:**
  - Parser directives such as `# syntax=docker/dockerfile:1` must be at the very top. After a blank line, a comment or an instruction they are treated as comments (checked 2026-11-09).
  - `add_header` is inherited into a `location` only if that location defines no `add_header` of its own. nginx 1.29.3 and later has `add_header_inherit` to change this (stated on the nginx page, checked 2026-11-09); we used a shared include so it works on older nginx too.
  - `expires` adds or modifies `Cache-Control` for success responses; do not combine it with an `add_header Cache-Control`.
  - The unprivileged nginx image runs as uid 101 and listens on 8080, not 80.
- **Mistakes (all seen):** headers missing on assets, duplicate `Cache-Control`, ignored `# syntax=` line, `-p 8080:80` from the assignment, a README Node version guessed from memory.
- **Troubleshooting:** `curl -sI <url> | grep -i <header>` per path (page, hashed asset, unknown route); `docker exec <c> nginx -t`; `docker exec <c> id`; `docker images <name>` for size; `docker history <name>` to see which layer is big. Run the real build, then run it against a deliberately broken copy to prove your test can fail.
- **Required to ship:** each acceptance criterion has a check; `npm run test:image` in `taskflow-app` runs all seven.

## Cross-cutting: plan, apply, and security checks
- **Docs:** https://developer.hashicorp.com/terraform/cli/commands/plan and https://aquasecurity.github.io/trivy/latest/docs/scanner/misconfiguration/
- **Read a plan in this order:** the last `Plan:` line; symbols (`+` create, `~` change, `-` destroy, `-/+` replace; search for `must be replaced`); literal values (names, CIDRs, instance types, versions); IAM principals and wildcards. Skip `(known after apply)` and repeated `tags_all`.
- **A plan cannot catch:** typos in strings only AWS validates, the wrong (but valid) principal ARN, network reachability, and cost.
- **Apply the plan you read:** `terraform plan -out=tfplan` then `terraform apply tfplan` (`tfplan` is git-ignored).
- **Run the checks every time:** `terraform fmt -check -recursive`, `terraform validate`, `tflint --recursive`, `trivy config .`. Accepted trivy findings are documented next to the code with `#trivy:ignore:<ID>`; deferred ones are AWS-0039, AWS-0038 and AWS-0178.
- **Debug logging:** `TF_LOG=DEBUG terraform plan` for provider-level detail (can contain sensitive data; do not paste it publicly). Tested with `terraform validate`: it produced 147 `[DEBUG]` lines.
- **Inspect state:** `terraform state list`, `terraform state show <address>`.

## Sections still to fill in
A10 CI (GitHub Actions: workflow syntax https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax ; `GITHUB_TOKEN` is limited to the repository that holds the workflow, https://docs.github.com/en/actions/concepts/security/github_token ; a new GHCR package is private by default, https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry ; all checked 2026-11-09), A11 manifests, A12 CI updates manifests, A13 ArgoCD, A14 GitOps loop, A15 teardown, A16 write-up. Use the same shape: docs to open, must be there, required arguments, version gotchas, mistakes, troubleshooting.
