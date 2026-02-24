{{/*
Common labels
*/}}
{{- define "silentpulse.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/*
Selector labels for a component
*/}}
{{- define "silentpulse.selectorLabels" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .instance }}
{{- end }}

{{/*
Full name helper
*/}}
{{- define "silentpulse.fullname" -}}
{{- printf "silentpulse-%s" . -}}
{{- end }}

{{/*
PostgreSQL DSN
*/}}
{{- define "silentpulse.postgresDSN" -}}
{{- printf "postgres://%s:%s@silentpulse-postgres:5432/%s?sslmode=disable" .Values.postgresql.username .Values.postgresql.password .Values.postgresql.database -}}
{{- end }}
