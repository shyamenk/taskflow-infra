# Taskflow: assignments

You implement. I give goals, hints, reading, and a "done when" check. Ask me to review any assignment when you finish it.
Source tutorial: https://www.youtube.com/watch?v=LgBnbmfsIdA (timestamps given per assignment).
Tutorial repos to peek at when stuck (not to copy blindly): `piyushsachdeva/10weeksofcloudops-week4-tf`, `AppCode`, `kube_manifest`.

## Naming (locked)
- Repos: `taskflow-app`, `taskflow-infra`, `taskflow-gitops`
- Prefix: `taskflow-dev` + resource, for example `taskflow-dev-vpc`, `taskflow-dev-eks`
- Tags (via provider `default_tags`): Project, Environment, ManagedBy, Repository, Owner
- State bucket: `taskflow-tfstate-<account-id>-<region-code>` (default region is `us-east-1`, so `use1`)
- AWS: use the default credentials, never pass `--profile` or set `AWS_PROFILE`. Account ID kept out of the repo (see `SECURITY.md`), region `us-east-1`.

## Security rule (applies to every assignment)
The repos are public. Never commit secrets, `*.tfvars`, `.env`, keys, kubeconfig, state files, or other sensitive data (see `SECURITY.md` in each repo). Secrets live in GitHub Actions secrets or AWS Secrets Manager. Commit `*.example` files with placeholders instead. Before every commit, read `git diff --staged`. If a secret leaks, revoke it first, then clean history.

## Content capture (applies to every assignment)
After each assignment, add an entry to `content/NOTES.md` using the template in `content/README.md`: fundamentals, best practices, common mistakes with the exact error text, fix, troubleshooting tip, and a post angle. Always cite the official docs and open the page for the version actually in use (versions table in `content/README.md`). A claim without an official source is marked `[unverified]`.

Pattern for every assignment: branch `type/issue-number-slug`, one GitHub issue, Conventional Commits, squash merge.

---

## Phase 0: Setup

### A0. Tools, AWS access, cost guard (video 4:00-7:30)
Goal: a safe way to talk to AWS, with a spending alarm.
Hints:
- Do not copy the video's admin IAM user with static access keys. Look at IAM Identity Center (SSO) or an assumed role.
- Set a monthly budget alert before creating anything. EKS control plane plus two NAT gateways cost money every hour.
- Account is decided: the default credentials (an admin IAM user with static keys). A mistake can touch anything, so keep every resource tagged `Project=taskflow` so you can find and delete them.
Read: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html , https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html
Done when: `aws sts get-caller-identity` works, a budget alert exists, and `terraform version`, `kubectl version --client`, `docker --version` all run.

### A1. Repo conventions
Goal: three repos with README, .gitignore, and your usual issue/branch flow.
Hints: `.gitignore` for infra must exclude `.terraform/`, `*.tfstate*`, `*.tfvars` with secrets. The folders and `git init` already exist in `~/projects/taskflow/`.
Done when: each repo has a first commit on `main` and a matching private GitHub repo made with `gh`.

---

## Phase 1: Infrastructure (`taskflow-infra`)

### A2. Remote state bootstrap (video 9:16-12:10)
Goal: a versioned, private S3 bucket for Terraform state.
Hints:
- The video also makes a DynamoDB lock table. Newer Terraform supports locking in S3 itself; read the S3 backend page and decide.
- Bootstrap problem: the bucket cannot be created by the config that stores state in it. Create it by CLI, or a tiny separate config.
- Turn on versioning, block public access, and default encryption.
Read: https://developer.hashicorp.com/terraform/language/backend/s3
Done when: bucket exists with versioning and public access block on, and `terraform init` in `taskflow-infra` connects to it.

### A3. Provider, locals, default tags
Goal: root module where every resource gets your tags and name prefix for free.
Hints: `default_tags` in the provider block; a `locals { name = "..." }` so no resource hard-codes a name. Pin the provider version (the video's 4.67.0 is old; check what current looks like and read the upgrade notes).
Read: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
Done when: `terraform fmt -check` and `terraform validate` pass.

### A4. VPC module (video 8:06-9:10, 16:50)
Goal: VPC, internet gateway, 2 public + 2 private subnets across 2 AZs, public route table.
Hints:
- Build it as `modules/vpc` with variables and outputs, called from the root.
- Subnets need Kubernetes tags: `kubernetes.io/role/elb` (public), `kubernetes.io/role/internal-elb` (private), and a cluster tag. Find out what each does for load balancers.
- Names like `taskflow-dev-public-1a` come from `local.name`, not hard-coded strings.
- The tutorial uses `enable_classiclink`; check if your provider version still accepts it.
Read: https://developer.hashicorp.com/terraform/language/modules , https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html
Done when: `terraform plan` shows the VPC resources with correct names and tags.

### A5. NAT gateways and private routing
Goal: private subnets reach the internet through a NAT gateway in each AZ.
Hints: one Elastic IP per NAT; NAT lives in a public subnet; one private route table per AZ. The EIP `vpc = true` argument is deprecated in newer providers; look up the replacement. Think about the cost trade-off of 2 NATs vs 1 for a dev environment, and decide.
Done when: plan shows private route tables with a `0.0.0.0/0` route to the NAT.

### A6. IAM roles for EKS
Goal: one role for the cluster, one for the worker nodes.
Hints: assume-role policy for `eks.amazonaws.com` and `ec2.amazonaws.com`. Attach AWS managed policies: cluster policy; worker node, CNI, and ECR read-only for nodes. Prefer `aws_iam_policy_document` data sources over inline JSON heredocs. Ask whether the video's `ElasticLoadBalancingFullAccess` on the cluster role is actually needed.
Read: https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html , https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html
Done when: plan shows 2 roles and their policy attachments.

### A7. EKS cluster and node group (video 14:00-16:20)
Goal: control plane plus a managed node group in the private subnets.
Hints:
- The video uses Kubernetes 1.27 and `AL2_x86_64`. Both are outdated; look up currently supported EKS versions and the current AMI type.
- Node group scaling 2/2/2, `t3.small` is fine for dev; check pod capacity limits per instance type.
- Run `terraform plan` and read the whole output before any apply.
Read: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
Done when: plan is clean, you can explain every resource in it, and (once you choose to apply) `terraform apply` finishes. Apply only after A0 is settled.

### A8. Connect with kubectl (video 17:20-19:00)
Goal: kubeconfig for the new cluster and healthy nodes.
Hints: `aws eks update-kubeconfig`; check `kubectl get nodes` and `kubectl get pods -n kube-system`. If you get an authorization error, look at EKS access entries for your IAM identity.
Done when: 2 nodes `Ready`.

---

## Phase 2: Application and CI (`taskflow-app`)

### A9. Container image (video 38:15-38:50)
Goal: the app builds into a small Docker image locally.
Hints: decided: a small own React + Vite app (the tutorial's AppCode has no license and uses Create React App). Multi-stage Dockerfile (build stage, then a pinned non-root nginx to serve; `nginx-unprivileged` listens on 8080). Add `.dockerignore`. Pin image tags, never `latest`.
Read: https://docs.docker.com/build/building/multi-stage/ , https://docs.docker.com/build/cache/optimize/
Done when: `docker build` and `docker run -p 8080:8080` serve the app on localhost. (Done 2026-11-09: app PR #2, image PR #4 in `taskflow-app`; `npm run test:image` checks it.)

### A10. GitHub Actions build and push (video 19:10-23:10, 30:00-39:40; the video uses CircleCI, decided 2026-11-09 to use GitHub Actions)
Goal: every push to `main` runs the checks, builds the image and pushes `<registry>/taskflow-app:<tag>`.
Hints:
- Workflow file `.github/workflows/ci.yml` with two jobs: `test` (`npm ci`, `npm run lint`, `format:check`, `npm test`, `npm run build`, `npm run test:image`) and `publish` (`needs: test`, only on pushes to `main`).
- Registry decided 2026-11-09: GHCR (`ghcr.io/shyamenk/taskflow-app`). It needs no stored secret: it uses `GITHUB_TOKEN` with `packages: write`. A newly published package is private by default, so make it public after the first publish or the cluster will need an image pull secret. (Alternatives not chosen: Docker Hub needs a token in Actions secrets; ECR matches the node role's ECR policy but needs Terraform for the repository and an OIDC role, a candidate for the refactor.)
- Tag with the short commit SHA (immutable and traceable) or the run number. Never `latest`.
- Give each job the minimum `permissions:` and pin third-party actions to a version.
Read: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax , https://docs.github.com/en/actions/use-cases-and-examples/publishing-packages/publishing-docker-images , https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry , https://github.com/docker/build-push-action
Done when: the workflow is green on `main` and the tagged image is visible in the registry (and pullable without credentials if the package is public).

---

## Phase 3: GitOps (`taskflow-gitops` + ArgoCD)

### A11. Manifests (video 28:00-29:20)
Goal: a Deployment (2 replicas) and a Service of type LoadBalancer in `manifest/`.
Hints: seed the image tag with a tag that really exists in your registry (the video's hard-coded tag caused `ImagePullBackOff` at 46:17). Add resource requests/limits and readiness probes.
Read: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
Done when: `kubectl apply --dry-run=server -f manifest/` passes.

### A12. CI updates the manifest repo (video 22:00-23:10, 50:50-53:20)
Goal: a second GitHub Actions job rewrites the image tag in `taskflow-gitops` and pushes.
Hints: the job uses `needs: publish`. The built-in `GITHUB_TOKEN` is limited to the repository that holds the workflow, so it cannot push to `taskflow-gitops`. Use a fine-grained personal access token limited to that one repository with contents read/write (the video's token lacked this and failed), stored as an Actions secret in `taskflow-app`. Never force-push.
Read: https://docs.github.com/en/actions/concepts/security/github_token , https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
Done when: after a push to `taskflow-app`, a new commit with the new tag appears in `taskflow-gitops`.

### A13. ArgoCD (video 39:50-46:00)
Goal: ArgoCD installed on the cluster and syncing `taskflow-gitops`.
Hints: install manifest from the official docs; reach the UI with `kubectl port-forward`; the initial admin password lives in the `argocd-initial-admin-secret` secret (base64). Write an `Application` manifest with automated sync, self-heal, and CreateNamespace. Keep it in `taskflow-gitops` under `argocd/`.
Read: https://argo-cd.readthedocs.io/en/stable/getting_started/
Done when: the app shows Synced and Healthy in the UI.

### A14. Prove the GitOps loop (video 46:00-55:00)
Goal: edit app text, push, and watch it reach the cluster without touching kubectl.
Hints: also try editing the Deployment by hand in the cluster and watch self-heal revert it. That is the point of GitOps.
Read: https://opengitops.dev
Done when: the new text shows on the LoadBalancer URL.

---

## Phase 4: Finish

### A15. Teardown
Hints: delete the LoadBalancer Service (or the ArgoCD app) first so AWS removes the ELB, then `terraform destroy`. Check the console for leftovers (ELB, ENI, EIP, NAT).
Done when: no billable resources remain; budget alert quiet.

### A16. Docs and write-up
README per repo (what, setup, env vars), an architecture diagram, `CHANGELOG.md`, and optionally a LinkedIn post (`/linkedin-post`).
Done when: a stranger could reproduce it from the READMEs.
