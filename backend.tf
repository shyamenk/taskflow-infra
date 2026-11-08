terraform {
  backend "s3" {
    bucket       = "taskflow-tfstate-588738575653-use1"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
