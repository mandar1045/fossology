{{/*
SPDX-FileCopyrightText: © Fossology contributors

SPDX-License-Identifier: FSFAP
*/}}
{{- define "fossology.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "fossology.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "fossology.name" . -}}
{{- end -}}
{{- end -}}

{{- define "fossology.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "fossology.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "fossology.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (printf "%s-web" (include "fossology.fullname" .)) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "fossology.dbHost" -}}
{{- if .Values.database.host -}}
{{- .Values.database.host -}}
{{- else -}}
{{- printf "%s-db" (include "fossology.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "fossology.dbConfSecretName" -}}
{{- default (printf "%s-db-conf" (include "fossology.fullname" .)) .Values.database.dbConfSecretName -}}
{{- end -}}

{{- define "fossology.repoPvcName" -}}
{{- default (printf "%s-repo" (include "fossology.fullname" .)) .Values.repoPersistence.existingClaim -}}
{{- end -}}

{{- define "fossology.postgresPvcName" -}}
{{- printf "%s-postgres-data" (include "fossology.fullname" .) -}}
{{- end -}}

{{- define "fossology.runtimeConfigName" -}}
{{- printf "%s-runtime-config" (include "fossology.fullname" .) -}}
{{- end -}}

{{- define "fossology.webImage" -}}
{{- printf "%s:%s" .Values.images.web.repository .Values.images.web.tag -}}
{{- end -}}

{{- define "fossology.workerImage" -}}
{{- printf "%s:%s" .Values.images.worker.repository .Values.images.worker.tag -}}
{{- end -}}

{{- define "fossology.postgresImage" -}}
{{- printf "%s:%s" .Values.images.postgres.repository .Values.images.postgres.tag -}}
{{- end -}}

{{- define "fossology.envPodIp" -}}
- name: MY_POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
{{- end -}}

{{- define "fossology.envPodNamespace" -}}
- name: POD_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
{{- end -}}

{{- define "fossology.envDatabase" -}}
- name: FOSSOLOGY_DB_HOST
  value: {{ include "fossology.dbHost" . | quote }}
- name: FOSSOLOGY_DB_NAME
  value: {{ .Values.database.name | quote }}
- name: FOSSOLOGY_DB_USER
  value: {{ .Values.database.user | quote }}
- name: FOSSOLOGY_DB_PASSWORD
  value: {{ .Values.database.password | quote }}
{{- end -}}

{{- define "fossology.envWaitForDb" -}}
- name: FOSSOLOGY_DB_HOST
  value: {{ include "fossology.dbHost" . | quote }}
- name: FOSSOLOGY_DB_NAME
  value: {{ .Values.database.name | quote }}
- name: FOSSOLOGY_DB_USER
  value: {{ .Values.database.user | quote }}
{{- end -}}

{{- define "fossology.envRenderConfig" -}}
{{ include "fossology.envPodIp" . }}
{{ include "fossology.envPodNamespace" . }}
- name: WORKER_MAX_AGENTS
  value: {{ .Values.workers.maxAgentsPerWorker | quote }}
- name: FOSSOLOGY_WORKER_LABEL_SELECTOR
  value: {{ printf "app=%s-worker" (include "fossology.fullname" .) | quote }}
- name: FOSSOLOGY_WORKER_HEADLESS_SERVICE
  value: {{ printf "%s-workers" (include "fossology.fullname" .) | quote }}
- name: FOSSOLOGY_WORKER_CONF_DIR
  value: "/usr/local/etc/fossology"
- name: FOSSOLOGY_RENDER_TEMPLATE
  value: /config-source/fossology.conf.tmpl
- name: FOSSOLOGY_RENDER_TIMEOUT_SECONDS
  value: {{ .Values.runtimeConfig.timeoutSeconds | quote }}
{{- end -}}
