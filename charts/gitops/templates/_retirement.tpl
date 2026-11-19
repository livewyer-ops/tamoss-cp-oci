{{- define "gitops.retirementBudgetPatch" -}}
- target: {group: policy, version: v1, kind: PodDisruptionBudget}
  patch: |
    [
      {"op":"replace", "path":"/spec/{{ .field }}", "value":{{ .value | toJson }}},
      {"op":"add", "path":"/spec/unhealthyPodEvictionPolicy", "value":"AlwaysAllow"}
    ]
{{- end -}}
