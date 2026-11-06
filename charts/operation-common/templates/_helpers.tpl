{{- define "operation-common.podSecurity" -}}
runAsNonRoot: true
runAsUser: 1000
runAsGroup: 1000
fsGroup: 1000
seccompProfile: {type: RuntimeDefault}
{{- end -}}

{{- define "operation-common.containerSecurity" -}}
readOnlyRootFilesystem: true
allowPrivilegeEscalation: false
capabilities: {drop: [ALL]}
{{- end -}}

{{- define "operation-common.resources" -}}
requests: {cpu: 100m, memory: 64Mi}
limits: {memory: 256Mi}
{{- end -}}

{{- define "operation-common.mounts" -}}
- {name: work, mountPath: /work}
- {name: temporary, mountPath: /tmp}
{{- end -}}

{{- define "operation-common.volumes" -}}
- name: work
  emptyDir: {medium: Memory, sizeLimit: 1Mi}
- name: temporary
  emptyDir: {medium: Memory, sizeLimit: 16Mi}
{{- end -}}
