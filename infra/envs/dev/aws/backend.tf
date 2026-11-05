# Partial config: bucket comes from `terraform init -backend-config=../../backend.hcl`
# (output of infra/global), so the account id is not hard-coded here.
terraform {
  backend "s3" {
    key          = "dev/aws.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
