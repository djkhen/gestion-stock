# =====================================================================
#  Dockerfile multi-stage pour le frontend Angular
#  Stage 1 : build des fichiers statiques avec Node
#  Stage 2 : Nginx sert les fichiers + fait reverse proxy vers Quarkus
# =====================================================================

# ---------- Stage 1 : build ----------
FROM node:20-alpine AS build
WORKDIR /app

COPY package.json ./
RUN npm install

COPY . .
RUN npm run build -- --configuration production

# ---------- Stage 2 : serveur Nginx ----------
FROM nginx:alpine

# Notre configuration (SPA + reverse proxy /api)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Les fichiers compilés (le builder Angular 19 sort dans dist/<projet>/browser)
COPY --from=build /app/dist/frontend-web/browser /usr/share/nginx/html

EXPOSE 80
