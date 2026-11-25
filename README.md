# Mural de Recados: do compose ao cluster

Docker + Helm + Terraform (kind). O código em `app/api` e `app/web` não foi alterado.

## Como rodar

Pré-requisitos: Docker, kind e Terraform (>= 1.5) no PATH. O Helm CLI não é necessário (o provider cuida).

```sh
cd infra/terraform
terraform init
terraform apply      # cluster + imagens + Traefik + chart; abre http://mural.localtest.me
terraform apply      # 2º apply: 0 changes
terraform destroy    # remove cluster e state
```

Se a porta 80/443 do host estiver ocupada (ex.: IIS no Windows):
`terraform apply -var http_port=8088 -var https_port=8443` → `http://mural.localtest.me:8088`.
Atalhos: `make up` / `make down`.

`docker compose up --build` roda a app com imagens oficiais, só para entendê-la (`http://localhost:8080`).

## Tamanho da imagem da API

| Imagem | Tamanho |
|---|---|
| Antes: `golang:1.23-alpine` (`go run`, toolchain + fonte) | 246 MB (`golang:1.23` Debian: 838 MB) |
| Depois: multi-stage, binário estático em `scratch` | **9,4 MB** |

## Decisões

- **Migração = Job comum, não hook Helm.** Um `pre-install` rodaria antes do Postgres existir; um `post-install` travaria o `wait` do Helm (a API só fica Ready após a migração). O Job espera o `pg_isready`, aplica `files/migrations/*.sql` (idempotentes) e tem o hash das migrations no nome, então só é recriado se elas mudarem. `wait_for_jobs=true` faz o Terraform esperar por ele.
- **Probes:** liveness da API em `/healthz`, readiness em `/readyz`. Assim a migração não causa CrashLoop.
- **Segredo:** `values.yaml` não tem senha e o chart falha sem ela. O Terraform gera `random_password`, passa por `set_sensitive` e o chart materializa o Secret (`POSTGRES_PASSWORD` e `DATABASE_URL`), injetado via `secretKeyRef`. A senha fica no state do Terraform (não versionado, `.gitignore`).
- **Postgres:** StatefulSet + `volumeClaimTemplates`; `PGDATA` em subdiretório por causa do `lost+found` do volume.
- **Idempotência:** as imagens usam como tag o hash do código-fonte (`terraform_data` faz `docker build` + `kind load` só quando o hash muda); nada muda entre applies.
- **Ingress:** Traefik com `hostPort` 80/443 no nó com label `ingress-ready=true`; `/api` → api, `/` → web.
- **Node image do kind fixada** (`kindest/node:v1.31.4`): versões recentes exigem cgroup v2.
- `requests/limits` em todos os workloads, inclusive no Job.

## Não feito / limites

- Bônus HPA + teste de carga não implementado.
- **O ciclo `apply → apply → destroy` não foi executado de ponta a ponta nesta máquina**: o Docker local (Rancher Desktop, cgroup v1) não consegue iniciar nenhum nó kind (`kind create cluster` simples também falha). Foram verificados: `terraform validate`, `helm lint`/`helm template`, build das duas imagens, o compose e as imagens novas contra o Postgres. Rode o ciclo num Docker com cgroup v2 antes de entregar.
