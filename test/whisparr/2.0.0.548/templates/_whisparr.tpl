{{- define "whisparr.workload" -}}
workload:
  whisparr:
    enabled: true
    primary: true
    type: Deployment
    podSpec:
      hostNetwork: {{ .Values.whisparrNetwork.hostNetwork }}
      containers:
        whisparr:
          enabled: true
          primary: true
          imageSelector: image
          securityContext:
            runAsUser: {{ .Values.whisparrRunAs.user }}
            runAsGroup: {{ .Values.whisparrRunAs.group }}
          env:
            WHISPARR__SERVER__PORT: {{ .Values.whisparrNetwork.webPort }}
            WHISPARR__APP__INSTANCENAME: {{ .Values.whisparrConfig.instanceName }}
          {{ with .Values.whisparrConfig.additionalEnvs }}
          envList:
            {{ range $env := . }}
            - name: {{ $env.name }}
              value: {{ $env.value }}
            {{ end }}
          {{ end }}
          probes:
            liveness:
              enabled: true
              type: http
              port: "{{ .Values.whisparrNetwork.webPort }}"
              path: /ping
            readiness:
              enabled: true
              type: http
              port: "{{ .Values.whisparrNetwork.webPort }}"
              path: /ping
            startup:
              enabled: true
              type: http
              port: "{{ .Values.whisparrNetwork.webPort }}"
              path: /ping
      initContainers:
      {{- include "ix.v1.common.app.permissions" (dict "containerName" "01-permissions"
                                                        "UID" .Values.whisparrRunAs.user
                                                        "GID" .Values.whisparrRunAs.group
                                                        "mode" "check"
                                                        "type" "install") | nindent 8 }}

{{/* Service */}}
service:
  whisparr:
    enabled: true
    primary: true
    type: NodePort
    targetSelector: whisparr
    ports:
      webui:
        enabled: true
        primary: true
        port: {{ .Values.whisparrNetwork.webPort }}
        nodePort: {{ .Values.whisparrNetwork.webPort }}
        targetSelector: whisparr

{{/* Persistence */}}
persistence:
  config:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.whisparrStorage.config) | nindent 4 }}
    targetSelector:
      whisparr:
        whisparr:
          mountPath: /config
        {{- if and (eq .Values.whisparrStorage.config.type "ixVolume")
                  (not (.Values.whisparrStorage.config.ixVolumeConfig | default dict).aclEnable) }}
        01-permissions:
          mountPath: /mnt/directories/config
        {{- end }}
  tmp:
    enabled: true
    type: emptyDir
    targetSelector:
      whisparr:
        whisparr:
          mountPath: /tmp
  {{- range $idx, $storage := .Values.whisparrStorage.additionalStorages }}
  {{ printf "whisparr-%v:" (int $idx) }}
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" $storage) | nindent 4 }}
    targetSelector:
      whisparr:
        whisparr:
          mountPath: {{ $storage.mountPath }}
        {{- if and (eq $storage.type "ixVolume") (not ($storage.ixVolumeConfig | default dict).aclEnable) }}
        01-permissions:
          mountPath: /mnt/directories{{ $storage.mountPath }}
        {{- end }}
  {{- end }}
{{- end -}}
