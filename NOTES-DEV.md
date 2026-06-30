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
├── models/        → la donnée + (dé)sérialisation JSON
│   ├── article.dart      (enAlerte)
│   └── mouvement.dart
├── services/      → appels HTTP, ZÉRO logique d'UI
│   ├── article_service.dart
│   └── mouvement_service.dart
├── widgets/       → les DIALOGUES extraits (UI réutilisable, se gèrent seuls)
│   ├── article_form_dialog.dart   (Stateful : 7 controllers + dispose AUTO)
│   ├── mouvement_dialog.dart       (Stateful : controllers + dispose AUTO)
│   └── historique_dialog.dart      (Stateless : juste l'affichage)
├── articles_page.dart  → l'écran : ORCHESTRE (ouvre dialogues, appelle services, refresh)
└── main.dart           → apiBaseUrl + MaterialApp
```

> 🧩 **Pourquoi extraire les dialogues dans `widgets/`** :
> - Chaque dialogue = un `StatefulWidget` → il gère ses `TextEditingController` dans **son propre `dispose()`** → **plus aucune fuite mémoire** (Flutter l'appelle tout seul à la fermeture). Fini la gestion manuelle des controllers.
> - **Séparation** : le dialogue = UI pure (capture + renvoie un résultat) ; la page = orchestration (service + messages + refresh).
> - Piège : `late final` controllers déclarés SEULS, créés dans `initState()` (où `widget` est accessible), JAMAIS dans les initialiseurs de champ. Et le widget doit être **public** (sans `_`) pour être importable.

### 🧩 Design : que RENVOIE un dialogue ? (saisie/DTO vs Entité)

Un dialogue renvoie son résultat via `Navigator.pop(context, resultat)`. **Que choisir comme type ?**

| Cas | Renvoyer | Pourquoi |
|---|---|---|
| Le modèle gère déjà « neuf » (`id` nullable, pas de champ « serveur » obligatoire) | **l'objet** (ex. `Article`, `id: null` = création) | le modèle est conçu pour ça |
| La saisie ≠ l'entité stockée (`id`/`date` générés par le serveur) | **un record** ou une **petite classe de saisie** (ex. `({type, quantite, motif})`) | l'INPUT de création n'est PAS l'ENTITÉ |

**Exemples du projet :**
- `ArticleFormDialog` → renvoie un **`Article`** (car `Article.id` est `int?` nullable → article neuf = `id: null`, article édité = `id` rempli → déclenche un PUT).
- `MouvementDialog` → renvoie un **record** `({String type, int quantite, String motif})` (car `Mouvement` exige `id` + `date` posés par le serveur via `@PrePersist` → impossible d'en construire un « propre » à la saisie).

> 🧠 **Concept d'archi : DTO/Command ≠ Entity.** Ce qu'on **envoie pour créer** (la saisie) ≠ ce qui est **stocké** (l'entité). Si l'entité a des champs « serveur uniquement » obligatoires → utiliser un **record** (léger, zéro classe) ou une **classe de saisie** dédiée, surtout pas une entité à moitié remplie de valeurs bidon.

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

### 6. docker-compose : `services.db.environment.ports must be a boolean...`
**Cause** : **indentation YAML** ! `ports:` mis **SOUS** `environment:` (trop indenté) → Docker
le prend pour une **variable d'environnement** « ports ». En YAML, **l'indentation = la hiérarchie**.
```yaml
    environment:
      POSTGRES_DB: ...
      ports:          # ❌ 6 espaces → ENFANT de environment
    ports:            # ✅ 4 espaces → FRÈRE de environment (vraie config de ports)
      - "5432:5432"
```
**Lire l'erreur** : le chemin `services.db.environment.ports` **pointe l'endroit** (ports était sous environment).
**Valider** un compose avant de lancer : `docker compose config --quiet` (silencieux = OK).
> 🧠 YAML : indentation par **espaces** (jamais de tabs) ; les « frères » ont le **même** niveau.

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
> - **⭐ 1er push d'une branche** → `git push -u origin <branche>` (le `-u` = *set upstream*, dit à git **OÙ** pousser). L'erreur `fatal: ... has no upstream branch` = tu as oublié le `-u origin <branche>`. Les pushes **suivants** → `git push` tout court (il sait déjà).
> - **Renommer un fichier** suivi par git → `git mv <ancien> <nouveau>` (renomme **ET** garde l'historique ; mieux que supprimer/recréer). ⚠️ Penser à corriger les `import` qui le référencent.

### Oups, j'ai déjà modifié... alors que je suis sur `main`

Cas fréquent : on a codé **directement sur `main`** sans avoir créé de branche. Pas de panique — on déplace ça sur une branche **sans rien perdre**.

**Le truc clé** : `git checkout -b <branche>` **EMPORTE** les modifs non commitées sur la nouvelle branche (pas besoin de `git stash`).

**La bonne séquence :**
```bash
git checkout -b fix/<nom>          # 1. crée la branche → ta modif non commitée SUIT
git add .                          # 2. stage (sur la branche, c'est clean)
git commit -m "fix: <description>"
# 3. puis le cycle habituel :
git push -u origin fix/<nom>
git checkout main && git pull
git merge fix/<nom>
git push
```

> 🧠 **À retenir :**
> - `git add` = **STAGE** (inoffensif, même sur main) ≠ `git commit` = **ENREGISTRE** (à faire sur une branche).
> - **Ne JAMAIS `commit` directement sur `main`** (sauf micro-doc) → toujours **brancher d'abord**.
> - `git checkout -b` transporte les modifs en cours → la branche « hérite » de ton travail non commité.

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
Un outil externe se connecte **depuis l'hôte** → il faut **exposer le port** de la base
(par défaut elle est interne au réseau Docker). C'est **déjà configuré** dans le service `db` :
```yaml
db:
  ports:
    - "5432:5432"     # hôte:conteneur
```
Après ajout du `ports:`, recréer le conteneur (⚠️ **SANS `-v`** sinon la base est effacée) :
```bash
docker compose up -d
```
**Connexion** (DBeaver → New Connection → PostgreSQL) :
```
Host : localhost   Port : 5432   Database : gestionstockdb   User/Mdp : gs / gs
```
(DBeaver télécharge le driver PostgreSQL tout seul à la 1re connexion.)

> 🧠 **Port HÔTE vs CONTENEUR** (`"hôte:conteneur"`) :
> - **Conteneur** (droite, `5432`) = port **standard de PostgreSQL** → toujours 5432, identique pour TOUTE base (pas spécifique à gestionstockdb).
> - **Hôte** (gauche) = **ton choix**, doit être **unique** sur la machine.
> - **2 bases exposées en même temps** (gs + mp) → port hôte différent pour l'une (ex. mp `"5433:5432"`) sinon **conflit**. Dans l'outil → connecte-toi alors sur 5433.
> - Si `localhost:5432` est déjà pris (Postgres installé en local, autre conteneur) → même solution : mappe sur un autre port hôte.

> 🧠 `docker compose exec <service> <commande>` = exécuter une commande **dans** un conteneur qui tourne.
> Pour la base : `psql -U <user> -d <base>`.

---

## 🧬 Enums, schéma & migrations (code-first)

**Question posée** : les enums (ex. `SensCommande`, `StatutCommande`), vaut-il mieux les
définir **en code** et **impacter la BD ensuite** ? → **Oui, et c'est DÉJÀ ce qu'on fait.**

### Le code est la SOURCE DE VÉRITÉ
- L'enum vit en **Java** (`@Enumerated(EnumType.STRING)` → stocké en clair, lisible).
- `quarkus.hibernate-orm.database.generation=update` **génère/met à jour le schéma à partir des entités**.
- **Bonus Hibernate 6** : il crée **tout seul une contrainte CHECK** en base à partir des valeurs de l'enum :
```sql
-- vérifiable via :  docker compose exec db psql -U gs -d gestionstockdb -c "\d commande"
Check constraints:
  commande_statut_check  CHECK (statut IN ('BROUILLON','VALIDEE','ANNULEE'))
  commande_sens_check    CHECK (sens   IN ('ACHAT','VENTE'))
```
→ Résultat : **code = vérité**, ET **la BD applique la règle** (un `INSERT statut='BANANE'` en SQL direct est **rejeté** par PostgreSQL). L'enum n'est PAS « défini dans la base » : la base n'en est qu'un **reflet contraint**. Le mieux des deux mondes, **zéro travail en plus**.

### ⚠️ Le piège de `generation=update`
`update` est **pratique en dev mais limité** : si on **ajoute** plus tard une valeur d'enum
(ex. `RECEPTIONNEE`), `update` **ne met pas toujours à jour la contrainte CHECK existante**
→ l'ancienne contrainte traîne et **rejette la nouvelle valeur**. Symptôme : « ça marche en
code, la BD refuse ». `update` ne sait pas non plus renommer une colonne, migrer des données,
droper proprement → **dangereux en prod**.
```
update = bon pour prototyper │ JAMAIS pour une base de prod avec des données à préserver
```

### 🏭 La vraie réponse « pro » : migrations versionnées (Flyway / Liquibase)
Le **code (enum Java) reste source de vérité**, mais le schéma SQL est piloté par des
**scripts versionnés** qu'on écrit et qu'on relit en PR :
```
V1__create_commande.sql
V2__add_statut_receptionnee.sql   -- ALTER TABLE ... DROP/ADD CONSTRAINT explicite
```
On passe alors de `generation=update` → `generation=none` + Flyway (historisé, rejouable, contrôlé).

> 🧠 **À retenir :**
> - **Maintenant (projet pédago)** : on garde `update` + enum Java + CHECK auto → **correct et élégant**, ne pas complexifier.
> - **Pour la prod / le portfolio** : **Flyway** est le réflexe attendu dès qu'il y a des données à préserver.
> - **Pour `gestion-flux`** (migration legacy PHP→Quarkus) : Flyway sera **quasi obligatoire** (on reprend un schéma existant, Hibernate ne doit rien « deviner »). C'est LE bon terrain pour l'apprendre.

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
