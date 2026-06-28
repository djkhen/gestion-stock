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

## 🔀 Git

### Workflow branche-par-branche — LE CYCLE COMPLET

```bash
# ── 1. CRÉER la branche (depuis un main à jour) ───────────────
git checkout main
git pull
git checkout -b feature/<nom>

# ── 2. ... coder la feature ... ───────────────────────────────

# ── 3. ENREGISTRER (stage puis commit) ────────────────────────
git add .                          # stage TOUT (relatif au dossier courant)
git commit -m "feat: <description>"

# ── 4. SAUVEGARDER + FUSIONNER ────────────────────────────────
git push -u origin feature/<nom>   # 1) pousse la branche sur GitHub
git checkout main                  # 2) retour sur main
git pull                           # 3) main à jour (si bossé ailleurs)
git merge feature/<nom>            # 4) fusionne la feature dans main
git push                           # 5) envoie main à jour sur GitHub

# ── 5. (optionnel) NETTOYER la branche fusionnée ──────────────
git branch -d feature/<nom>
```

> 🧠 **Mantra à mémoriser** :
> **brancher → coder → `add` → `commit` → `push` branche → `main` → `pull` → `merge` → `push`**
>
> **Pièges à retenir :**
> - **`commit` AVANT `push`** : `push` envoie les **commits**, pas les modifs en cours. (Modif après un push ? → re-`add` → re-`commit` → re-`push`.)
> - `git add <chemin>` est **relatif au dossier courant** → `git add .` = « tout depuis ici »
>   (évite l'erreur `pathspec '...' did not match` quand on est déjà dans un sous-dossier).
> - `git branch -d` **refuse** de supprimer une branche **non fusionnée** = garde-fou (`-D` force, à éviter).
> - Vérifier l'état à tout moment : `git status` (modifs) · `git log --oneline -3` (derniers commits) · `git branch` (branches).

### Avertissement fins de ligne (LF / CRLF)

**1. Le warning** (sur Windows, au moment du `git add`) :
```
warning: in the working copy of '...', LF will be replaced by CRLF the next time Git touches it
```
👉 Simple ***warning*, PAS une erreur** : le `git add` / `commit` marche quand même.
Git normalise les fins de ligne — **LF** (`\n`, standard Unix) stocké dans le dépôt,
**CRLF** (`\r\n`, Windows) affiché sur la machine.

**2. La recommandation** : créer un fichier **`.gitattributes`** à la racine du repo, contenant :
```
* text=auto
```
→ fixe une politique de fins de ligne homogène pour tout le monde (surtout utile en équipe
ou multi-OS). Optionnel en solo, mais propre.

> 🧠 Rappel : `warning:` = info, ça continue ; `fatal:` / `error:` = ça s'arrête.

---

## 🗄️ Consulter la base de données (PostgreSQL dans Docker)

La base tourne dans le conteneur **`gs-db`** (base `gestionstockdb`, user/mdp `gs`/`gs`).

### Session interactive psql
```bash
# depuis le dossier gestion-stock (db = le SERVICE docker-compose)
docker compose exec db psql -U gs -d gestionstockdb
# ou par le NOM du conteneur, de n'importe où :
docker exec -it gs-db psql -U gs -d gestionstockdb
```

### Commandes psql utiles (une fois dedans)
```sql
\dt                                  -- liste les TABLES
\d article                           -- décrit une table (colonnes, types, contraintes)
SELECT * FROM article;               -- voir les données
SELECT * FROM mouvement;             -- voir les mouvements
SELECT * FROM mouvement WHERE article_id = 1;   -- filtrer
\q                                   -- QUITTER
```

### Requête « one-shot » (sans entrer dans psql)
```bash
docker compose exec db psql -U gs -d gestionstockdb -c "SELECT * FROM article;"
```
Le `-c "..."` exécute UNE requête et rend la main (check rapide).

### Outil graphique (DBeaver / IntelliJ Database / pgAdmin)
⚠️ Le conteneur `gs-db` **n'expose PAS** le port 5432 à l'hôte par défaut (interne au réseau Docker).
Pour brancher un outil GUI, **mapper le port** dans `docker-compose.yml` :
```yaml
db:
  ports:
    - "5432:5432"
```
puis se connecter à `localhost:5432`, base `gestionstockdb`, user/mdp `gs`/`gs`.

> 🧠 `docker compose exec <service> <commande>` = exécuter une commande **dans** un conteneur qui tourne.
> Pour la base : `psql -U <user> -d <base>`.

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
