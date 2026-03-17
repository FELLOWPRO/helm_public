{{/*
Expand the name of the chart.
*/}}
{{- define "base.name" -}}
{{- default .Chart.Name .Values.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "base.fullname" -}}
{{- if .Values.fullnameOverride }}
  {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
  {{- printf "%s-%s" (.Release.Name | default "my-release") "base" | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "base.serviceNames" -}}
{{- range .Values.service }}
  {{- .name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "base.serviceLabels" -}}
{{- range .Values.service }}
  app.kubernetes.io/name: {{ include "base.fullname" . }}
  app.kubernetes.io/instance: {{ .Release.Name }}
  app.kubernetes.io/service: {{ .name }}
{{- end }}
{{- end }}

{{- define "base.serviceSelector" -}}
{{- range .Values.service }}
  app.kubernetes.io/name: {{ include "base.fullname" . }}
  app.kubernetes.io/instance: {{ .Release.Name }}
  app.kubernetes.io/service: {{ .name }}
{{- end }}
{{- end }}

{{- define "base.version" -}}
{{- default .Chart.Version .Values.version | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "base.appVersion" -}}
{{- default .Chart.AppVersion .Values.appVersion | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "base.chart" -}}
{{- printf "%s-%s" (include "base.name" .) (include "base.version" .) | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "base.labels" -}}
helm.sh/chart: {{ include "base.chart" . }}
{{ include "base.selectorLabels" . }}
app.kubernetes.io/version: {{ include "base.appVersion" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "base.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "base.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "base.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the target/server Kubernetes version
*/}}
{{- define "base.capabilities.kubeVersion" -}}
{{- default .Capabilities.KubeVersion.Version .Values.kubeVersion -}}
{{- end -}}

{{- define "annotations" -}}
{{- $ingressAnnotations := .annotations -}}

{{- if eq .class "alb" }}
{{- $defaultAnnotations := dict "kubernetes.io/ingress.class" "alb"
                    "alb.ingress.kubernetes.io/target-type" "ip"
                    "alb.ingress.kubernetes.io/scheme" "internet-facing"
                    "alb.ingress.kubernetes.io/group.order" "20"
                    "alb.ingress.kubernetes.io/healthcheck-path" "/"
                    "alb.ingress.kubernetes.io/listen-ports" "[{\"HTTP\":80},{\"HTTPS\":443}]"
                    "alb.ingress.kubernetes.io/success-codes" "200-399" -}}
{{- $mergedAnnotations := merge $ingressAnnotations $defaultAnnotations -}}
{{- $mergedAnnotations | toYaml }}
{{- else if eq .class "application-gateway" }}
{{- $defaultAnnotations := dict "kubernetes.io/ingress.class" "azure/application-gateway"
                    "external-dns.alpha.kubernetes.io/ttl" "60"
                    "appgw.ingress.kubernetes.io/backend-protocol" "http"
                    "appgw.ingress.kubernetes.io/ssl-redirect" "true" -}}
{{- $mergedAnnotations := merge $defaultAnnotations $ingressAnnotations -}}
{{- $mergedAnnotations | toYaml }}
{{- else if eq .class "cce" }}
{{- $defaultAnnotations := dict "kubernetes.io/ingress.class" "cce"
                    "kubernetes.io/elb.port" "443" -}}
{{- $mergedAnnotations := merge $ingressAnnotations $defaultAnnotations -}}
{{- $mergedAnnotations | toYaml }}
{{- else }}
{{- $defaultAnnotations := (ternary ("{}" | fromYaml) (dict "kubernetes.io/ingress.class" .class) .Values.setIngressClassByField) -}}
{{- $mergedAnnotations := merge $ingressAnnotations $defaultAnnotations -}}
{{- $mergedAnnotations | toYaml }}
{{- end }}
{{- end }}

{{/*
=============================================================================
NODE POOL AUTO-DETECTION (v0.1.75)
=============================================================================
Automatically selects the correct DigitalOcean node pool based on namespace.
dev/stage namespaces → dev-stage, sandbox/pre-prod/demo → sandbox, prod → prod
*/}}
{{- define "base.nodePool.auto" -}}
{{- $ns := .Release.Namespace -}}
{{- if or (contains "dev" $ns) (contains "stage" $ns) -}}
dev-stage
{{- else if or (contains "sandbox" $ns) (contains "pre-prod" $ns) (contains "demo" $ns) -}}
sandbox
{{- else if or (eq $ns "prod") (eq $ns "prod-v2") -}}
prod
{{- else -}}
dev-stage
{{- end -}}
{{- end -}}

{{/*
=============================================================================
INGRESS HOST GENERATION (v0.1.75)
=============================================================================
Generates ingress hostname: <namespace>.<baseDomain>
prod namespace gets bare domain (no prefix).
Usage: set ingress.baseDomain in values to enable auto-generated ingress mode.
*/}}
{{- define "base.ingressHost" -}}
{{- $ns := .Release.Namespace -}}
{{- $baseDomain := .Values.ingress.baseDomain | default "api.docbits.com" -}}
{{- if eq $ns "prod" -}}
{{ $baseDomain }}
{{- else -}}
{{ $ns }}.{{ $baseDomain }}
{{- end -}}
{{- end -}}

{{/*
Sticky session ingress host: <namespace>.<baseDomainSticky>
*/}}
{{- define "base.ingressHostSticky" -}}
{{- $ns := .Release.Namespace -}}
{{- $baseDomain := .Values.ingress.baseDomainSticky | default "api-sticky.docbits.com" -}}
{{- if eq $ns "prod" -}}
{{ $baseDomain }}
{{- else -}}
{{ $ns }}.{{ $baseDomain }}
{{- end -}}
{{- end -}}

{{/*
=============================================================================
TLS SECRET NAME GENERATION (v0.1.75)
=============================================================================
Generates TLS secret name: <namespace>-<tlsSuffix>
prod namespace gets bare suffix (no prefix).
*/}}
{{- define "base.tlsSecretName" -}}
{{- $ns := .Release.Namespace -}}
{{- $suffix := .Values.ingress.tlsSuffix | default "api-cert" -}}
{{- if eq $ns "prod" -}}
{{ $suffix }}
{{- else -}}
{{ $ns }}-{{ $suffix }}
{{- end -}}
{{- end -}}