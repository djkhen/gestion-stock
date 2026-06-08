# Mini-projet — Flutter + Angular + Quarkus + PostgreSQL (Docker)

Démonstration d'une architecture moderne : **une seule API** consommée par
**deux clients** (web et mobile), le tout conteneurisé avec Docker.

```
┌──────────────┐        ┌──────────────┐
│   Flutter    │        │   Angular    │
│  (mobile)    │        │   (web)      │
└──────┬───────┘        └──────┬───────┘
       │  http://10.0.2.2:8080  │  /api/...  (proxy Nginx)
       │                        ▼
       │                ┌───────────────┐
       │                │ Nginx (web)   │  :8090
       │                └───────┬───────┘
       └───────────┬────────────┘
                   ▼
          ┌─────────────────┐
          │ Quarkus (API)   │  :8080
          └────────┬────────┘
                   ▼
          ┌─────────────────┐
          │ PostgreSQL      │  :5432 (interne)
          └─────────────────┘
```

## Contenu

| Dossier         | Rôle                          | Techno              |
|-----------------|-------------------------------|---------------------|
| `backend/`      | API REST `/produits` (CRUD)   | Quarkus + Maven     |
| `frontend-web/` | Application web               | Angular 19 + Nginx  |
| `mobile/`       | Application mobile            | Flutter             |
| `docker-compose.yml` | Orchestration db + backend + web | Docker         |

---

## Prérequis

- **Docker Desktop** (avec WSL2) — pour lancer backend + web + base
- **Flutter SDK** + un émulateur Android / iOS — pour l'app mobile
- *(optionnel)* Node.js + Angular CLI si vous voulez lancer le web hors Docker
- *(optionnel)* JDK 21 + Maven si vous voulez lancer Quarkus hors Docker
  *(non requis : le build Quarkus se fait dans Docker)*

---

## 1) Lancer la partie serveur (web + API + base)

Depuis ce dossier :

```bash
docker compose up --build
```

Au premier lancement, Docker télécharge les dépendances et compile (quelques
minutes). Ensuite :

| Service          | URL                                |
|------------------|------------------------------------|
| Application web  | http://localhost:8090              |
| API Quarkus      | http://localhost:8080/produits     |
| Doc API (Swagger)| http://localhost:8080/q/swagger-ui |

Pour arrêter : `Ctrl+C` puis `docker compose down`
Pour repartir de zéro (efface la base) : `docker compose down -v`

---

## 2) Lancer l'app mobile Flutter

L'app mobile ne tourne **pas** dans Docker : elle s'installe sur le téléphone /
émulateur. Assurez-vous que la partie serveur (étape 1) tourne, puis :

```bash
cd mobile
flutter pub get
flutter run
```

⚠️ **Adresse de l'API selon la cible** (à régler dans `mobile/lib/main.dart`,
constante `apiBaseUrl`) :

| Cible                | Adresse                          |
|----------------------|----------------------------------|
| Émulateur Android    | `http://10.0.2.2:8080` (défaut)  |
| Simulateur iOS       | `http://localhost:8080`          |
| Téléphone réel       | `http://<IP_LOCALE_DU_PC>:8080`  |

---

## Détails techniques

### Pourquoi pas de CORS côté web ?
Angular appelle un chemin **relatif** `/api/...`. En production, **Nginx**
redirige `/api` vers le backend ; en développement (`ng serve`), c'est le proxy
`proxy.conf.json`. Le navigateur reste donc sur la même origine.
Le CORS reste **activé côté Quarkus** quand même (utile pour les appels directs).

### Persistance
Hibernate est en mode `update` : le schéma est créé/mis à jour automatiquement
et les données **survivent aux redémarrages** (volume Docker `db-data`).
Des produits de démonstration sont insérés au premier démarrage si la base est
vide (voir `DataInitializer.java`).

### Endpoints de l'API
| Méthode | Chemin            | Description           |
|---------|-------------------|-----------------------|
| GET     | `/produits`       | Liste les produits    |
| GET     | `/produits/{id}`  | Détail d'un produit   |
| POST    | `/produits`       | Crée un produit       |
| PUT     | `/produits/{id}`  | Modifie un produit    |
| DELETE  | `/produits/{id}`  | Supprime un produit   |

---

## Et après ? (Phase 2)

La prochaine étape sera d'ajouter **Keycloak** (authentification / autorisation)
comme conteneur supplémentaire, puis de protéger les endpoints Quarkus
(`@RolesAllowed`) et de brancher le login côté Angular et Flutter.
