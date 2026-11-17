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
{{- $instance := deepCopy .Values.instance -}}
{{- if .Values.retirementId -}}
{{- if ne $instance.spec.deploymentId .Values.retirementId }}{{ fail "Retirement request belongs to a different deployment" }}{{ end -}}
{{- $_ := set $instance.spec "retirementId" .Values.retirementId -}}
{{- $_ := set $instance.spec "retirementBeforeAccess" .Values.retirementBeforeAccess -}}
{{- end -}}
{{ $instance | toYaml }}
{{- else -}}
{{- $v := .Values -}}
{{- if and $v.retirementId (ne $v.retirementId $v.deploymentId) }}{{ fail "Retirement request belongs to a different deployment" }}{{ end }}
apiVersion: tamoss.livewyer.io/v1alpha1
kind: TamossBootstrap
metadata:
  name: {{ $v.name }}
  namespace: tamoss-infra
spec:
  deploymentId: {{ required "deploymentId is required" $v.deploymentId | quote }}
  retirementBeforeAccess: {{ $v.retirementBeforeAccess }}
  retirementId: {{ $v.retirementId | quote }}
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

{{- define "management.settingsInputs" -}}
{{- $environment := include "management.environment" . | fromYaml -}}
{{- $settings := dict
  "tadoss" (dict "enabled" .Values.tadoss.enabled)
  "deploymentId" .Values.deploymentId
  "region" $environment.region
  "databaseAdministrator" .Values.database.administrator
  "services" (dict "name" .Values.name "compartmentId" $environment.compartmentId "owner" $environment.owner "storageNamespace" $environment.storage.namespace "database" (omit .Values.database "administrator"))
  "runtime" (dict "bucket" $environment.storage.bucket "objectEndpoint" (printf "https://%s.compat.objectstorage.%s.oci.customer-oci.com" $environment.storage.namespace $environment.region) "acmeEmail" (.Values.acmeEmail | default .Values.contactEmail) "adminEmail" (.Values.adminEmail | default .Values.contactEmail)) -}}
{{- $assets := dict "tadoss" (dict "release" .Values.tadoss.release) "dependencies" .Values.dependencies "packages" .Values.packages "externalSecrets" .Values.externalSecrets "connectionImages" .Values.connectionImages "release" .Values.release "assets" .Values.assets -}}
{{ dict "tamoss-gitops-values" $settings "tamoss-assets" $assets | toYaml }}
{{- end -}}
