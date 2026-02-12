{{/*
Expand the name of the chart.
*/}}
{{- define "shared-elastic.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "shared-elastic.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "shared-elastic.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "shared-elastic.labels" -}}
helm.sh/chart: {{ include "shared-elastic.chart" . }}
{{ include "shared-elastic.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "shared-elastic.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shared-elastic.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Pod Disruption Budget configuration
*/}}
{{- define "elastic.podDisruptionBudget" -}}
{{- if .Values.appspace.elastic.podDisruptionBudget.enabled }}
podDisruptionBudget:
  {{- toYaml .Values.appspace.elastic.podDisruptionBudget.spec | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Node Sets configuration
*/}}
{{- define "elastic.nodeSets" -}}
{{- if .Values.appspace.elastic.nodeSets }}
nodeSets:
{{- range .Values.appspace.elastic.nodeSets }}
- name: {{ .name }}
  count: {{ .count }}
  config:
    {{- toYaml .config | nindent 4 }}
  {{- if .podTemplate }}
  podTemplate:
    {{- toYaml .podTemplate | nindent 4 }}
  {{- end }}
  {{- if .volumeClaimTemplates }}
  volumeClaimTemplates:
    {{- toYaml .volumeClaimTemplates | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Secure Settings configuration
*/}}
{{- define "elastic.secureSettings" -}}
{{- if .Values.appspace.elastic.secureSettings.enabled }}
secureSettings:
{{- range .Values.appspace.elastic.secureSettings.entries }}
- secretName: {{ .secretName }}
  {{- if .key }}
  key: {{ .key }}
  {{- end }}
  {{- if .path }}
  path: {{ .path }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
HTTP configuration
*/}}
{{- define "elastic.http" -}}
{{- if .Values.appspace.elastic.http }}
http:
  {{- if .Values.appspace.elastic.http.tls }}
  tls:
    {{- if .Values.appspace.elastic.http.tls.certificate }}
    certificate:
      secretName: {{ .Values.appspace.elastic.http.tls.certificate.secretName }}
    {{- else }}
    selfSignedCertificate:
      disabled: false
    {{- end }}
  {{- end }}
  {{- if .Values.appspace.elastic.http.service }}
  service:
    {{- if .Values.appspace.elastic.http.service.metadata }}
    metadata:
      {{- toYaml .Values.appspace.elastic.http.service.metadata | nindent 6 }}
    {{- end }}
    {{- if .Values.appspace.elastic.http.service.spec }}
    spec:
      {{- toYaml .Values.appspace.elastic.http.service.spec | nindent 6 }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Transport configuration
*/}}
{{- define "elastic.transport" -}}
{{- if .Values.appspace.elastic.transport }}
transport:
  {{- if .Values.appspace.elastic.transport.tls }}
  tls:
    {{- if .Values.appspace.elastic.transport.tls.certificate }}
    certificate:
      secretName: {{ .Values.appspace.elastic.transport.tls.certificate.secretName }}
    {{- else }}
    selfSignedCertificate:
      disabled: false
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Monitoring configuration
*/}}
{{- define "elastic.monitoring" -}}
{{- if .Values.appspace.elastic.monitoring.enabled }}
monitoring:
  {{- if .Values.appspace.elastic.monitoring.metrics }}
  metrics:
    {{- toYaml .Values.appspace.elastic.monitoring.metrics | nindent 4 }}
  {{- end }}
  {{- if .Values.appspace.elastic.monitoring.logs }}
  logs:
    {{- toYaml .Values.appspace.elastic.monitoring.logs | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Update Strategy configuration
*/}}
{{- define "elastic.updateStrategy" -}}
{{- if .Values.appspace.elastic.updateStrategy }}
updateStrategy:
  {{- toYaml .Values.appspace.elastic.updateStrategy | nindent 2 }}
{{- end }}
{{- end }}
