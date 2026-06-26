# Notes de développement — gestion-stock (gs)

Mémo pratique du projet : architecture, commandes, pièges rencontrés et leurs
solutions. À lire en premier quand on (re)prend le projet sur une machine.

> 🧭 **Repère d'univers** : **gs = gestion-stock = ARTICLES 📦** (endpoint `/articles`).
> À NE PAS confondre avec **mp = mini-projet = produits 🛍️** (`/produits`), le labo.
> Le titre de l'app le confirme d'un coup d'œil : « 📦 Catalogue articles » = gs.

---

## ⚡ Aide-mémoire express (ce que j'oublie tout le temps)

```bash
# --- Lancer le mobile sur ÉMULATEUR Android ---
flutter emulators --launch Small_Phone_API_35     # démarre l'émulateur
flutter run -d emulator-5554                       # API = 10.0.2.2:8080 (défaut)

# --- Lancer le mobile sur CHROME (web) ---
flutter run -d chrome --web-port=5000 --dart-define=API_URL=http://localhost:8080
#   web-port=5000 → autorisé par le CORS │ dart-define → localhost au lieu de 10.0.2.2

# --- Backend gs (UN SEUL backend sur 8080 !) ---
cd C:\Users\dk\StudioProjects\mini-projet   && docker compose down   # libère 8080
cd C:\Users\dk\StudioProjects\gestion-stock && docker compose up -d  # démarre gs

# --- Réflexes debug ---
docker ps -a                       # qui tourne ? (gs-* ou mp-*) + qui est mort
curl localhost:8080/articles       # 200=OK  404=mauvais backend/route  500=base/code
```

### 📍 Adresse de l'API selon la cible (constante `apiBaseUrl` dans `lib/main.dart`)
| Cible | URL API | Pourquoi |
|---|---|---|
| Émulateur Android | `http://10.0.2.2:8080` | alias spécial Android = "localhost du PC" |
| **Chrome / Web** | `http://localhost:8080` | `10.0.2.2` n'existe PAS pour un navigateur ! + CORS |
| Simulateur iOS | `http://localhost:8080` | — |
| Téléphone réel | `http://<IP_DU_PC>:8080` | ex. 192.168.x.x |

---

## 🏗️ Architecture en un coup d'œil

Une **seule API** (Quarkus) consommée par **deux clients** (web Angular + mobile
Flutter), le tout conteneurisé avec **Docker**.

```
  Angular (web)  ──/api/articles──►  Nginx ──►  ┐
                                                 ├──►  Quarkus :8080 ──►  PostgreSQL
  Flutter (mobile) ──:8080/articles──────────────┘
```

| Dossier         | Rôle                          | Techno             | IDE conseillé |
|-----------------|-------------------------------|--------------------|---------------|
| `backend/`      | API REST `/articles` (CRUD)   | Quarkus + Panache  | IntelliJ IDEA |
| `frontend-web/` | App web                       | Angular + Nginx    | VS Code       |
| `mobile/`       | App mobile                    | Flutter            | IntelliJ IDEA |
| `docker-compose.yml` | Orchestration db+backend+web | Docker        | —             |

### 📂 Architecture mobile (en couches)
```
mobile/lib/
├── models/article.dart          → la donnée + fromJson/toJson (enAlerte)
├── services/article_service.dart→ appels HTTP /articles (liste, enregistrer, supprimer)
├── articles_page.dart           → l'écran (liste/grille responsive, CRUD)
└── main.dart                    → apiBaseUrl + MaterialApp
```

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
| API Quarkus      | http://localhost:8080/articles     |
| Swagger UI       | http://localhost:8080/q/swagger-ui |

### Développer Angular (mode "dev")
```bash
docker compose up -d db backend    # backend + base seulement
cd frontend-web && npm install     # 1re fois
npm start                          # ng serve → http://localhost:4200
```

> ⚠️ **Premier réflexe après un clone** : `npm install` (Angular),
> `flutter pub get` (mobile), `mvn install` (backend).

---

## 🐛 Pièges rencontrés & solutions

### 1. ⭐ « Pas d'articles » → mauvais backend sur le port 8080
**Symptôme** : l'app gs (articles) ne charge rien ; `curl localhost:8080/articles` = **404**.
**Cause** : c'est le backend **mp** (produits) qui tournait sur 8080, pas gs.
Un **seul** backend peut occuper 8080 à la fois.
**Solution** :
```bash
cd ../mini-projet   && docker compose down     # arrêter mp
cd ../gestion-stock && docker compose up -d    # démarrer gs
docker ps                                       # vérifier : gs-* présents
```
> 🔑 **404 = problème de ROUTE/backend**, pas de base de données.

### 2. ⭐ Renommage de base ignoré (volume Docker persistant)
**Symptôme** : après avoir renommé `POSTGRES_DB`/`POSTGRES_USER`, le backend
n'arrive pas à se connecter (la base au nouveau nom n'existe pas).
**Cause** : `POSTGRES_DB`/`USER` ne sont lus qu'à la **1re création** d'un volume
vide. Si le volume existe déjà, Postgres le réutilise → l'ancien nom survit.
**Solution** : purger le volume pour forcer la réinitialisation.
```bash
docker compose down -v        # -v = supprime le volume
docker compose up -d --build  # base recréée avec gestionstockdb / gs
```

### 3. ⭐ Web (Chrome) ne charge pas les articles (mais l'émulateur oui)
**Cause** : config DIFFÉRENTE du mobile.
- `10.0.2.2` n'existe **que** pour l'émulateur Android → invisible pour un navigateur.
- Sur web, le **CORS** s'applique (le navigateur l'impose, pas l'émulateur).
**Solution** :
```bash
flutter run -d chrome --web-port=5000 --dart-define=API_URL=http://localhost:8080
```
(le port 5000/5001 est dans la liste blanche CORS du backend.)

### 4. CORS : POST/PUT/DELETE en 403 depuis `:4200` ou `:5000`
**Cause** : origine non autorisée. Le GET *same-origin* passe (pas d'en-tête
`Origin`), mais POST envoie `Origin` → refus si absent de la liste blanche.
`curl` n'envoie jamais d'`Origin` → passe toujours (normal).
**Solution** : ajouter l'origine dans `docker-compose.yml` puis recréer le backend.
```yaml
CORS_ORIGINS: http://localhost:8090,http://localhost:4200,http://localhost:5000,http://localhost:5001
```

### 5. Émulateur qui crashe au lancement (Vulkan)
**Solution** : `C:\Users\dk\.android\advancedFeatures.ini` avec `Vulkan = off`,
ou lancer avec `-gpu swiftshader_indirect`.

---

## 📡 API REST `/articles` (codes HTTP)

| Opération | Méthode | Chemin            | Succès            | Erreur          |
|-----------|---------|-------------------|-------------------|-----------------|
| Lister    | GET     | `/articles`       | 200               | —               |
| Détail    | GET     | `/articles/{id}`  | 200               | 404 si absent   |
| Créer     | POST    | `/articles`       | 201 Created       | 409 réf. en double |
| Modifier  | PUT     | `/articles/{id}`  | 200               | 404 si absent   |
| Supprimer | DELETE  | `/articles/{id}`  | 204 No Content    | 404 si absent   |

Champs d'un article : `reference`, `designation`, `description`, `unite`,
`quantiteStock`, `seuilAlerte`, `prixUnitaire` (+ `enAlerte` calculé : stock ≤ seuil).

---

## 🔧 Commandes Docker utiles

```bash
docker compose ps                       # état des conteneurs
docker compose logs -f backend          # logs backend en direct
docker compose up -d --build web        # reconstruire SEULEMENT le web
docker compose up -d backend            # recréer le backend (après changement d'env)
docker compose exec db psql -U gs -d gestionstockdb   # console SQL
```

---

## 🗂️ Repères du projet

| Élément | Valeur |
|---|---|
| Entité | **articles** (`/articles`) |
| Base de données | `gestionstockdb` (user `gs`) |
| Conteneurs Docker | `gs-db`, `gs-backend`, `gs-web` |
| Port backend / web | 8080 / 8090 |
| Origines CORS autorisées | `:8090`, `:4200`, `:5000`, `:5001` |

---

## 🗺️ Feuille de route (MVP portfolio)

1. ✅ Infra Docker + backend Quarkus (articles, CRUD, PUT façon PATCH)
2. ✅ Mobile Flutter en couches (models/ services/) + CRUD + responsive
3. ⏳ Tests (widget_test, tests unitaires des services/modèles)
4. 🔒 **Auth / RBAC** (Keycloak + `@RolesAllowed` + login) — étape entreprise
5. 🚀 Déploiement (VPS + Docker + CI/CD GitHub Actions)
