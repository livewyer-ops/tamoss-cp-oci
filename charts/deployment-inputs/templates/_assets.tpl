{{- define "deployment.assets" -}}
{{- $lock := .Values.files.assets | default "data: {}" | fromYaml -}}
{{- (index $lock.data "values.yaml" | default "{}" | fromYaml).assets | default dict | toYaml -}}
{{- end -}}
