{{/*
Expand the name of the chart.
*/}}
{{- define "68k-web.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "68k-web.fullname" -}}
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
{{- define "68k-web.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "68k-web.labels" -}}
helm.sh/chart: {{ include "68k-web.chart" . }}
{{ include "68k-web.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "68k-web.selectorLabels" -}}
app.kubernetes.io/name: {{ include "68k-web.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: 68k-web
{{- end }}

{{/*
Shared PVC name prefix (from relay release)
*/}}
{{- define "68k-web.sharedPvcPrefix" -}}
{{- .Values.sharedPvc.relayReleaseName }}-68k-relay
{{- end }}
