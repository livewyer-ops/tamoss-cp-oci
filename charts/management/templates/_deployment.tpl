{{- define "management.environment" -}}
{{- $v := .Values -}}
region: {{ required "OCI profile region is required" $v.oci.region | quote }}
compartmentId: {{ $v.compartmentId | quote }}
providerConfigName: oci
owner: {{ $v.owner | default $v.contactEmail | quote }}
network:
{{ $v.network | toYaml | indent 2 }}
  adminCidrs: {{ $v.adminCidrs | toJson }}
oke:
{{ $v.oke | toYaml | indent 2 }}
storage:
  namespace: {{ $v.storage.namespace | quote }}
  bucket: {{ $v.storage.bucket | default (printf "tamoss-%s-media" $v.name) | quote }}
{{- end -}}

{{- define "management.instance" -}}
{{- if .Values.instance -}}
{{ .Values.instance | toYaml }}
{{- else -}}
{{- $v := .Values -}}
apiVersion: tamoss.livewyer.io/v1alpha1
kind: TamossBootstrap
metadata:
  name: {{ $v.name }}
  namespace: tamoss-infra
spec:
  deploymentId: {{ required "deploymentId is required" $v.deploymentId | quote }}
  released: false
  credentialsEstablished: false
  storageCredentials:
    domainId: {{ $v.storageIdentity.domainId | quote }}
    idcsEndpoint: {{ $v.storageIdentity.idcsEndpoint | trimSuffix "/" | quote }}
    email: {{ $v.contactEmail | quote }}
    images:
      oci: {{ required "connectionImages.oci is required" $v.connectionImages.oci | quote }}
      kubectl: {{ required "connectionImages.kubectl is required" $v.connectionImages.kubectl | quote }}
  vaultAuth:
    user: {{ required "OCI profile user is required" $v.oci.user | quote }}
    tenancy: {{ required "OCI profile tenancy is required" $v.oci.tenancy | quote }}
  foundationName: {{ $v.foundation.name | default (printf "%s-vault" $v.name) | quote }}
  foundation:
    owner: {{ $v.owner | default $v.contactEmail | quote }}
    region: {{ $v.oci.region | quote }}
    compartmentId: {{ $v.compartmentId | quote }}
    providerConfigName: oci
{{- with $v.foundation.adoption }}
    adoption:
{{ toYaml . | indent 6 }}
{{- end }}
  environment:
{{ include "management.environment" . | indent 4 }}
{{- end -}}
{{- end -}}
