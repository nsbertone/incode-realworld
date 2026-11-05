output "argocd_ui" {
  description = "ArgoCD is not exposed publicly; reach it through a port-forward."
  value       = "kubectl -n argocd port-forward svc/argocd-server 8080:443  # user: admin, password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
