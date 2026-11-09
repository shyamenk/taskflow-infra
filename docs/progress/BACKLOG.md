# Taskflow backlog

Details for each item are in `../ASSIGNMENTS.md`.
Last updated: 2026-11-09. Next task: A9.

## Phase 0: Setup
- [x] A0 Tools, AWS access, cost guard (budget alert skipped on purpose; teardown in A15 is the cost control)
- [x] A1 Repo conventions and GitHub repos (all three public)

## Phase 1: Infrastructure (taskflow-infra)
- [x] A2 Remote state bootstrap (commit 497a3f6)
- [x] A3 Provider, locals, default tags (commit e219fc7)
- [x] A4 VPC module (commit fe50f64)
- [x] A5 NAT gateways and private routing (commit 7b711fa; applied 2026-11-09)
- [x] A6 IAM roles (PR #4)
- [x] A7 EKS cluster and node group (7a PR #6, 7b PR #8; applied 2026-11-09, 27 resources)
- [x] A8 Connect with kubectl (2 nodes Ready, kube-system pods Running)

## Phase 2: Application and CI (taskflow-app)
- [ ] A9 Container image
- [ ] A10 CircleCI build and push

## Phase 3: GitOps (taskflow-gitops)
- [ ] A11 Manifests
- [ ] A12 CI updates the manifest repo
- [ ] A13 ArgoCD
- [ ] A14 Prove the GitOps loop

## Phase 4: Finish
- [ ] A15 Teardown
- [ ] A16 Docs and write-up

## Notes for the next session
- The cluster `taskflow-dev-eks` is applied and BILLING (about $0.23 an hour: EKS, 2 NAT gateways, 2 x t3.small). Run `terraform destroy` in `taskflow-infra` when not working; the same config rebuilds in about 12 minutes.
- kubectl uses the default `~/.kube/config`, context `taskflow-dev`. Terminals opened before the `.zshrc` KUBECONFIG export was removed need `unset KUBECONFIG`.
- `terraform.tfvars` (git-ignored) holds `admin_cidrs` = your home IP. If kubectl times out, your IP probably changed: update it and apply.
- Deferred to the refactor (trivy findings): AWS-0039 KMS secrets encryption (high), AWS-0038 control plane logging, AWS-0178 VPC flow logs. AWS-0040 and AWS-0041 are accepted and documented in `eks.tf`.
- Open decision for A10: the assignment says CircleCI, but the global rule and the infra plan lean to GitHub Actions. Decide before starting A10.
- Before A13/A15: ArgoCD's LoadBalancer Service creates an ELB outside Terraform. Delete the Service (or the ArgoCD app) before `terraform destroy`.
- Optional cleanups: node group could use Spot capacity for dev; rename `nodes_assume` to `node_assume` in `iam.tf`; leftover `# Hooli-Box cluster config` comment at `~/.zshrc:278`.
- Old broken `.git` of taskflow-infra is backed up in the Claude scratchpad (safe to ignore).
