{{/*
Expand the name of the chart.
*/}}
{{- define "mac-connect.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "mac-connect.fullname" -}}
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
{{- define "mac-connect.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mac-connect.labels" -}}
helm.sh/chart: {{ include "mac-connect.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Relay selector labels
*/}}
{{- define "mac-connect.relaySelectorLabels" -}}
app.kubernetes.io/name: {{ include "mac-connect.name" . }}-relay
app.kubernetes.io/instance: {{ .Release.Name }}
app: mac-connect-relay
{{- end }}

{{/*
Web selector labels
*/}}
{{- define "mac-connect.webSelectorLabels" -}}
app.kubernetes.io/name: {{ include "mac-connect.name" . }}-web
app.kubernetes.io/instance: {{ .Release.Name }}
app: mac-connect-web
{{- end }}
