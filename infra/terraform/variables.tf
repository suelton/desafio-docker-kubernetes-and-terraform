variable "cluster_name" {
  type    = string
  default = "mural"
}

variable "namespace" {
  type    = string
  default = "mural"
}

variable "host" {
  description = "Host do Ingress (*.localtest.me resolve para 127.0.0.1)"
  type        = string
  default     = "mural.localtest.me"
}

variable "traefik_chart_version" {
  type    = string
  default = "34.4.1"
}

variable "http_port" {
  description = "Porta do host mapeada para o 80 do nó (mude se a 80 estiver ocupada)"
  type        = number
  default     = 80
}

variable "https_port" {
  type    = number
  default = 443
}

variable "node_image" {
  description = "Imagem do nó kind. Fixada: versões recentes do K8s exigem cgroup v2 (alguns Docker Desktop/WSL ainda usam v1)"
  type        = string
  default     = "kindest/node:v1.31.4"
}
