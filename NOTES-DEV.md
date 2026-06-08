# Notes de développement — mini-projet

Mémo pratique du projet : architecture, commandes, pièges rencontrés et leurs
solutions. À lire en premier quand on (re)prend le projet sur une machine.

---

## 🏗️ Architecture en un coup d'œil

Une **seule API** (Quarkus) consommée par **deux clients** (web Angular + mobile
Flutter), le tout conteneurisé avec **Docker**.

```
  Angular (web)  ──/api/produits──►  Nginx ──►  ┐
                                                 ├──►  Quarkus :8080 ──►  PostgreSQL
  Flutter (mobile) ──:8080/produits──────────────┘
```

| Dossier         | Rôle                          | Techno             | IDE conseillé |
|-----------------|-------------------------------|--------------------|---------------|
| `backend/`      | API REST `/produits` (CRUD)   | Quarkus + Panache  | IntelliJ IDEA |
| `frontend-web/` | App web                       | Angular 19 + Nginx | VS Code       |
| `mobile/`       | App mobile                    | Flutter            | IntelliJ IDEA |
| `docker-compose.yml` | Orchestration db+backend+web | Docker        | —             |

---

## 🚀 Lancer le projet

### Tout en Docker (mode "production")

```bash
docker compose up --build         # build + démarre db, backend, web
docker compose up -d              # en arrière-plan
docker compose down               # arrêter (garde la base)
docker compose down -v            # arrêter ET effacer la base (volume)
```

| Service          | URL                                |
|------------------|------------------------------------|
| App web (Nginx)  | http://localhost:8090              |
| API Quarkus      | http://localhost:8080/produits     |
| Swagger UI       | http://localhost:8080/q/swagger-ui |

### Développer Angular (mode "dev", recommandé au quotidien)

Le serveur de dev `ng serve` (port **4200**) recompile à chaud à chaque
sauvegarde — bien plus rapide que rebuilder l'image Docker.

```bash
# 1) Lancer SEULEMENT le backend + la base (pas besoin du conteneur web)
docker compose up -d db backend

# 2) Lancer le serveur de dev Angular
cd frontend-web
npm install          # la 1re fois (ou après un clone) — installe node_modules
npm start            # = ng serve, sert sur http://localhost:4200
```

> ⚠️ **Premier réflexe après un clone** : `npm install` (Angular),
> `flutter pub get` (mobile), `mvn install` (backend). Les dépendances ne sont
> pas dans git, chaque machine doit les télécharger.

### Lancer le mobile Flutter

```bash
cd mobile
flutter pub get
flutter run          # nécessite un émulateur/téléphone
```

Adresse de l'API selon la cible (constante `apiBaseUrl` dans `lib/main.dart`) :
- Émulateur Android : `http://10.0.2.2:8080`
- Simulateur iOS    : `http://localhost:8080`
- Téléphone réel    : `http://<IP_LOCALE_DU_PC>:8080`

---

## 🔀 Pourquoi `:8090` ET `:4200` marchent tous les deux

Deux serveurs différents servent la même app sur deux ports :

| | `:8090` (Docker) | `:4200` (ng serve) |
|---|---|---|
| Qui sert l'app | Nginx (build de prod) | ng serve (compil à la volée) |
| Proxy `/api` → backend | `nginx.conf` (`proxy_pass`) | `proxy.conf.json` |
| Rechargement à chaud | non | **oui** ⚡ |
| Usage | prod / vérif finale | dev quotidien |

Dans les deux cas, le code Angular appelle le chemin **relatif** `/api/produits` ;
c'est l'environnement qui fournit le bon proxy. Le code ne change jamais.

---

## 🐛 Pièges rencontrés & solutions

### 1. CORS : POST/PUT/DELETE en 403 depuis `:4200`

**Symptôme** : sur `:4200`, le GET (liste) marche mais créer/modifier renvoie
**403**. Avec `curl` tout marche. Sur `:8090` aucun souci.

**Cause** : le CORS est une sécurité **du navigateur**. Le backend tient une
liste blanche d'origines autorisées (`quarkus.http.cors.origins`). En Docker,
seule `http://localhost:8090` était autorisée → l'origine `http://localhost:4200`
du serveur de dev était rejetée.
- Le GET *same-origin* n'envoie pas d'en-tête `Origin` → pas de vérif → OK.
- Le POST envoie `Origin: http://localhost:4200` → vérif → refus → 403.
- `curl` n'envoie pas d'`Origin` → pas soumis au CORS → c'est normal qu'il passe.

**Solution** : ajouter `:4200` à la liste blanche dans `docker-compose.yml`,
puis recréer le backend.
```yaml
CORS_ORIGINS: http://localhost:8090,http://localhost:4200
```
```bash
docker compose up -d backend
```

> 💡 Sur `:8090`, navigateur et API sont vus comme la **même origine** (grâce au
> proxy Nginx) → pas de CORS. C'est une subtilité propre au mode dev `:4200`.

### 2. Soulignements rouges dans VS Code (imports Angular introuvables)

**Cause** : `node_modules` absent (le projet ne se compilait que dans Docker).
**Solution** : `cd frontend-web && npm install`, puis au besoin dans VS Code :
`Ctrl+Shift+P` → « TypeScript: Restart TS Server ».

### 3. POST en `curl` qui échoue (400) sous Windows

Le JSON en ligne avec guillemets se fait "manger" par le shell. Mettre le JSON
dans un fichier :
```bash
curl -X POST http://localhost:8080/produits \
  -H "Content-Type: application/json" -d @produit.json
```

### 4. Prix avec virgule → 400

Quarkus attend un `double` : `"5,90"` (virgule) n'est pas parsable → 400.
Utiliser un **point** (`5.90`), ou valider/convertir la saisie côté formulaire.

---

## 📡 API REST `/produits` (codes HTTP)

| Opération | Méthode | Chemin            | Succès            | Erreur          |
|-----------|---------|-------------------|-------------------|-----------------|
| Lister    | GET     | `/produits`       | 200               | —               |
| Détail    | GET     | `/produits/{id}`  | 200               | 404 si absent   |
| Créer     | POST    | `/produits`       | 201 Created       | 422 si id fourni|
| Modifier  | PUT     | `/produits/{id}`  | 200               | 404 si absent   |
| Supprimer | DELETE  | `/produits/{id}`  | 204 No Content    | 404 si absent   |

---

## 🔧 Commandes Docker utiles

```bash
docker compose ps                       # état des conteneurs
docker compose logs -f backend          # logs backend en direct
docker compose up -d --build web        # reconstruire SEULEMENT le web
docker compose up -d backend            # recréer le backend (ex: après changement d'env)
docker compose exec db psql -U produits -d produitsdb   # console SQL
```

---

## 🗺️ Feuille de route (apprentissage)

1. ✅ Infra Docker (compose, Dockerfiles, nginx.conf)
2. ✅ Backend Quarkus (entité Panache, API REST, CRUD)
3. ✅ Clients : Angular (web) + Flutter (mobile, lecture)
4. ⏳ CRUD complet dans l'interface (web ✏️ / mobile)
5. 🔒 **Keycloak** — sécurité (authentification/autorisation) — **étape finale** :
   conteneur Keycloak + `@RolesAllowed` côté Quarkus + login Angular/Flutter.

---

## ℹ️ Notes diverses

- `node_modules/`, `target/`, `build/`, `dist/`, `.claude/` sont **ignorés par git**
  (voir `.gitignore`). Normal qu'ils ne soient pas dans le dépôt.
- La base insère 3 produits de démo au 1er démarrage si elle est vide
  (`DataInitializer.java`). Les données **persistent** (volume Docker `db-data`,
  Hibernate en mode `update`).
