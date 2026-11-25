locals {
  app_dir = "${path.module}/../../app"

  # tag = hash do código: só muda (e só rebuilda/redeploya) quando a fonte muda
  api_files = concat(tolist(fileset(local.app_dir, "api/*.go")), tolist(fileset(local.app_dir, "api/go.*")), ["docker/api.Dockerfile"])
  web_files = concat(tolist(fileset(local.app_dir, "web/*")), ["docker/web.Dockerfile"])
  api_tag   = substr(sha1(join("", [for f in local.api_files : filesha1("${local.app_dir}/${f}")])), 0, 12)
  web_tag   = substr(sha1(join("", [for f in local.web_files : filesha1("${local.app_dir}/${f}")])), 0, 12)
}

# --- Cluster: o nó recebe o label ingress-ready e mapeia 80/443 para o host ---
resource "kind_cluster" "this" {
  name           = var.cluster_name
  wait_for_ready = true
  node_image     = var.node_image

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      kubeadm_config_patches = [
        <<-EOT
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
        EOT
      ]

      extra_port_mappings {
        container_port = 80
        host_port      = var.http_port
      }
      extra_port_mappings {
        container_port = 443
        host_port      = var.https_port
      }
    }
  }
}

# --- Imagens: build local + kind load (requer docker e kind no PATH) ---
resource "terraform_data" "images" {
  triggers_replace = [local.api_tag, local.web_tag, kind_cluster.this.id]

  provisioner "local-exec" {
    command = "docker build -f ${local.app_dir}/docker/api.Dockerfile -t mural-api:${local.api_tag} ${local.app_dir}"
  }
  provisioner "local-exec" {
    command = "docker build -f ${local.app_dir}/docker/web.Dockerfile -t mural-web:${local.web_tag} ${local.app_dir}"
  }
  provisioner "local-exec" {
    command = "kind load docker-image mural-api:${local.api_tag} mural-web:${local.web_tag} --name ${var.cluster_name}"
  }
}

# --- Ingress controller: Traefik no nó ingress-ready, em hostPort 80/443 ---
resource "helm_release" "traefik" {
  name             = "traefik"
  namespace        = "traefik"
  create_namespace = true
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = var.traefik_chart_version
  wait             = true

  values = [yamlencode({
    service      = { type = "ClusterIP" }
    ports        = { web = { hostPort = 80 }, websecure = { hostPort = 443 } }
    nodeSelector = { "ingress-ready" = "true" }
    tolerations  = [{ key = "node-role.kubernetes.io/control-plane", operator = "Exists", effect = "NoSchedule" }]
  })]
}

# --- Credencial do banco: gerada uma vez e guardada no state (nunca no git) ---
resource "random_password" "db" {
  length  = 24
  special = false
}

resource "kubernetes_namespace" "mural" {
  metadata {
    name = var.namespace
  }
  depends_on = [kind_cluster.this]
}

# --- A aplicação ---
resource "helm_release" "mural" {
  name          = "mural"
  namespace     = kubernetes_namespace.mural.metadata[0].name
  chart         = "${path.module}/../helm/mural"
  wait          = true
  wait_for_jobs = true
  timeout       = 600
  atomic        = false

  values = [yamlencode({
    host = var.host
    api  = { image = { tag = local.api_tag } }
    web  = { image = { tag = local.web_tag } }
  })]

  set_sensitive {
    name  = "postgres.password"
    value = random_password.db.result
  }

  depends_on = [terraform_data.images, helm_release.traefik]
}
