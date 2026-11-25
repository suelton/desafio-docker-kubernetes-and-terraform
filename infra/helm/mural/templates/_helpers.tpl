{{- define "mural.labels" -}}
app.kubernetes.io/part-of: mural
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "mural.pgHost" -}}{{ .Release.Name }}-postgres{{- end -}}

{{- define "mural.migrationsHash" -}}
{{- $s := "" -}}
{{- range $p, $_ := .Files.Glob "files/migrations/*.sql" }}{{ $s = print $s ($.Files.Get $p) }}{{ end -}}
{{- $s | sha256sum | trunc 8 -}}
{{- end -}}
