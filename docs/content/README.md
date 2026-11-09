# Taskflow content room

Raw material for the LinkedIn series about this project (one post, or one short thread, per assignment, plus an overview and a wrap-up). Capture while you build. A mistake you just made is better material than a polished lesson written later.

## Rules

1. **Official docs first.** Every technical claim in a post links to the official documentation page for the tool, not a blog or video. If a claim has no official source, mark it `[unverified]` and do not publish it as fact.
2. **Match the version.** Docs change between versions. For each step, record the version you actually ran and open the docs for that version. If the docs and your result disagree, say so in the notes.
3. **Evidence over memory.** Each mistake or error entry holds the exact error text or command output you saw. If it was not seen, it is `[unverified]`.
4. **No secrets.** Same rule as the repos: no account IDs you do not want public, keys, tokens, or `tfvars` contents in notes or posts. (The account ID appears in the state bucket name, an accepted exception in `SECURITY.md`; blur it in screenshots.)
5. Run drafts through the existing skills: `/linkedin-post`, `/linkedin-hooks`, `/linkedin-score`, then `/linkedin-humanizer`.

## Versions in use (update when anything changes)

| Tool | Version | Docs to open |
|---|---|---|
| Terraform | 1.15.9 | https://developer.hashicorp.com/terraform/docs |
| AWS provider (hashicorp/aws) | 6.72.0 (constraint `~> 6.0`) | https://registry.terraform.io/providers/hashicorp/aws/latest/docs (switch the version selector to 6.72.0) |
| AWS CLI | 2.37.9 | https://docs.aws.amazon.com/cli/latest/ |
| kubectl (client) | 1.37.1 | https://kubernetes.io/docs/reference/kubectl/ |
| Docker | 29.9.2 | https://docs.docker.com/ |
| Kubernetes / EKS version | 1.37 (node AMI `amazon-eks-node-al2023-x86_64-standard-1.37-v20261031`) | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| Node (image build stage) | 24.15 (`node:24.15-alpine3.23`) | https://nodejs.org/docs/latest/api/ |
| nginx runtime image | `nginx/nginx-unprivileged:1.31.7-alpine3.24` | https://hub.docker.com/r/nginxinc/nginx-unprivileged , https://nginx.org/en/docs/ |
| CI | GitHub Actions (decided 2026-11-09) | https://docs.github.com/en/actions |
| ArgoCD | decided in A13 | https://argo-cd.readthedocs.io/en/stable/ |

## Per-step template (copy into `NOTES.md` for each assignment)

- **What we built:** one sentence.
- **Fundamentals:** the concept someone needs first, in plain language.
- **Best practices:** what production setups do, with the official doc link.
- **Common mistakes:** what went wrong, with the exact error text.
- **Fix:** what resolved it.
- **Troubleshooting tip:** the command that finds the problem fast.
- **Version note:** anything that differs by version or from the tutorial video.
- **Post angle:** the one idea for the post, and a candidate hook.
- **Status:** `raw` / `drafted` / `published (date)`.

## Series plan (working)

0. Overview post: what Taskflow is and why production-style naming matters.
1. One post per phase boundary, built from the step notes: state backend, networking, IAM/EKS, CI, GitOps, teardown.
2. Wrap-up: total cost, the five mistakes that cost the most time, the repo links.
