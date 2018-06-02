{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "wallarm-support-bot.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "wallarm-support-bot.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "wallarm-support-bot.mysql.fullname" -}}
{{- printf "%s-%s" .Release.Name "mysql" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
docker image name
*/}}
{{- define "wallarm-support-bot.dockerImage" -}}
{{-   if .Values.image.repository -}}
{{-     printf .Values.image.repository ":%s" .Values.image.tag -}}
{{-   else -}}
{{-     printf "wallarm-dkr-support.jfrog.io/wallarm-support-bot:%s" .Chart.Version -}}
{{-   end -}}
{{- end -}}

