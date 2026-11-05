terraform {
  backend "s3" {
    key          = "dev/argocd.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
