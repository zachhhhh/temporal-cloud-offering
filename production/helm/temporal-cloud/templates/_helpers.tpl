{{/*
Expand the name of the chart.
*/}}
{{- define "temporal-cloud.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "temporal-cloud.fullname" -}}
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
{{- define "temporal-cloud.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "temporal-cloud.labels" -}}
helm.sh/chart: {{ include "temporal-cloud.chart" . }}
{{ include "temporal-cloud.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "temporal-cloud.selectorLabels" -}}
app.kubernetes.io/name: {{ include "temporal-cloud.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
OCIR image registry
*/}}
{{- define "temporal-cloud.ocirRegistry" -}}
{{- if .Values.global.ocir.enabled }}
{{- printf "%s.ocir.io/%s" .Values.global.ocir.region .Values.global.ocir.namespace }}
{{- else }}
{{- .Values.global.imageRegistry | default "" }}
{{- end }}
{{- end }}
