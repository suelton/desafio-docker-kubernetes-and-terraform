# Contexto de build: ./app
FROM nginx:1.27-alpine
# a imagem oficial roda envsubst em /etc/nginx/templates/*.template no boot,
# então o upstream da API vem de env, sem recompilar
ENV API_UPSTREAM=api:8080
COPY web/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY web/index.html web/app.js web/styles.css /usr/share/nginx/html/
EXPOSE 8080
