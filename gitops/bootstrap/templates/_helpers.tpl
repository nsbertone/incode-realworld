{{/* Common Application boilerplate */}}
{{- define "bootstrap.syncPolicy" -}}
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  retry:
    limit: 10
    backoff:
      duration: 10s
      factor: 2
      maxDuration: 5m
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
{{- end }}
