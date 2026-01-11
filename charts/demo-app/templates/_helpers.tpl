{{/*
Expand the name of the chart.
*/}}
{{- define "demo-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "demo-app.fullname" -}}
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
{{- define "demo-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "demo-app.labels" -}}
helm.sh/chart: {{ include "demo-app.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Frontend selector labels
*/}}
{{- define "demo-app.frontendSelectorLabels" -}}
app.kubernetes.io/name: {{ include "demo-app.name" . }}-frontend
app.kubernetes.io/instance: {{ .Release.Name }}
app: frontend
{{- end }}

{{/*
Backend selector labels
*/}}
{{- define "demo-app.backendSelectorLabels" -}}
app.kubernetes.io/name: {{ include "demo-app.name" . }}-backend
app.kubernetes.io/instance: {{ .Release.Name }}
app: backend
{{- end }}

{{/*
Redis selector labels
*/}}
{{- define "demo-app.redisSelectorLabels" -}}
app.kubernetes.io/name: {{ include "demo-app.name" . }}-redis
app.kubernetes.io/instance: {{ .Release.Name }}
app: redis
{{- end }}
