output "url" {
  value = "http://${var.host}${var.http_port == 80 ? "" : ":${var.http_port}"}"
}

output "kubeconfig" {
  value     = kind_cluster.this.kubeconfig
  sensitive = true
}
