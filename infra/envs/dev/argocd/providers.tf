provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]
}

# Short-lived token from `aws eks get-token`; nothing written to a kubeconfig.
provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.aws.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.aws.outputs.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", data.terraform_remote_state.aws.outputs.cluster_name,
        "--region", var.region,
      ]
    }
  }
}
