# Contexto de build: ./app  (docker build -f app/docker/api.Dockerfile app)
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY api/go.mod api/go.sum ./
RUN go mod download
COPY api/*.go ./
# binário estático: sem libc, sem toolchain na imagem final
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api .

FROM scratch
COPY --from=build /out/api /api
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/api"]
