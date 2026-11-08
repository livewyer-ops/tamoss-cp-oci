{{- define "deployment.assets" -}}
{{- $lock := .Values.files.assets | default "data: {}" | fromYaml -}}
{{- pick $lock.data "bucketName" "endpoint" "region" "prefix" "storeId" "manifestSha256" | toYaml -}}
{{- end -}}
