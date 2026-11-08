# Security rules

This repo is public. Anything committed is visible to everyone, and git history keeps it forever.

## Never commit

- Passwords, API keys, access tokens, private keys, certificates
- AWS credentials or anything from `~/.aws/`
- `.env` files, `*.tfvars` files, kubeconfig files, Terraform state files
- Account IDs, internal hostnames, or personal data that are not already public

## Do instead

- Keep secrets in the CI provider's secret store (CircleCI project environment variables) or in AWS Secrets Manager.
- Commit a `.example` file with placeholder values (for example `terraform.tfvars.example`).
- Give every token the minimum scope and expiry, limited to one repository.
- Stage files by name; avoid `git add .`.

## If a secret is committed

1. Revoke or rotate it immediately. Deleting the commit is not enough.
2. Then clean the history if needed.

GitHub secret scanning and push protection are enabled on this repo.
