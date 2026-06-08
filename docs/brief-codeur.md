# Brief — Session « Codeur »

> Fichier de passation entre sessions. La session **Codeur** n'a pas la mémoire de la
> conversation d'origine, mais elle a accès à ce fichier et au code du repo.
> Objectif : utiliser le cahier des charges ci-dessous comme **fil rouge** pour
> construire le MVP en vrai (certif Flutter) et en faire une **démo / référence**.

---

## 1. Cahier des charges (appel d'offres réel)

**Contexte client** : PME industrielle (~50 collaborateurs, plusieurs sites en France).
Remplacer un système de gestion de stocks basé sur des fichiers Excel partagés par une
**application métier sur mesure**.

**Contrainte technique forte** : infrastructure sous Linux → l'application doit être
**cross-platform : Windows, Linux & macOS**.

**Périmètre MVP attendu :**
- Gestion du catalogue articles
- Entrées / sorties de stock avec historique
- Tableau de bord avec alertes de rupture
- Gestion multi-utilisateurs avec rôles
- Recherche / filtres
- Export CSV

**Organisation en 3 jalons :**
- **Jalon 1 — MVP** : fonctionnalités essentielles. Budget envisagé : **1 000 € à 10 000 €**.
- **Jalon 2** : multi-sites, gestion fournisseurs, bons de commande, valorisation du stock,
  rapports avancés — à chiffrer.
- **Jalon 3** : optimisation, scan code-barres, PWA/mobile léger, API documentée, CI/CD — à chiffrer.

**Autres exigences :** code source propriété du client à la livraison, versionné sur Git.
Références projets similaires (stocks, logistique, ERP), stack envisagée, délais par jalon,
tarif MVP, devis structuré jalon par jalon, proposition commerciale.

---

## 2. Analyse d'écart (« je suis loin de combien ? »)

### Stack demandée vs la mienne → 🟢 quasi parfaite
Le cœur du besoin = appli **desktop cross-platform** → terrain de **Flutter Desktop**.

| Besoin client | Ma stack | Match |
|---|---|---|
| Appli desktop cross-platform | Flutter Desktop | 🟢 idéal |
| Backend métier / API | Quarkus | 🟢 idéal |
| Base de données | PostgreSQL | 🟢 idéal |
| Déploiement Linux | Docker | 🟢 idéal |
| Livraison versionnée Git | Workflow branche-par-branche | 🟢 |

Angular (frontend-web) ne sert pas pour le MVP desktop — utile seulement si Jalon 3 → PWA.

### Fonctionnalités MVP → 🟡 faisables, non encore maîtrisées

| Fonction | Demande technique | Niveau |
|---|---|---|
| Catalogue articles | CRUD Flutter ↔ Quarkus ↔ Postgres | 🟡 cœur certif |
| Entrées/sorties + historique | Modèle données + transactions + audit | 🟡 à travailler |
| Dashboard + alertes rupture | Requêtes agrégées + UI réactive | 🟡 |
| Multi-utilisateurs + rôles | **Auth + RBAC** (JWT/OIDC Quarkus) | 🔴 le plus dur |
| Recherche / filtres | Requêtes paramétrées | 🟢 |
| Export CSV | Génération fichier | 🟢 facile |

**Point dur = authentification multi-utilisateurs + rôles** (Quarkus Security / OIDC / Keycloak).

### Écart réel = expérience + commercial → 🔴
- **Références** : aucun projet réel livré → éliminatoire tel quel.
- **Devis / proposition commerciale** : à produire de zéro.
- **Estimation de délais** : risque de sous-estimation sans expérience.
- **Contrat / cession de code / relation client** : à apprendre.

### ⚠️ Piège du cahier des charges
Budget MVP « 1 000 € à 10 000 € » : le bas (1 000 €) est **irréaliste** pour du sur-mesure
avec auth/RBAC/dashboard/cross-platform. MVP réaliste ≈ **15 à 30 jours/homme**.

### Verdict « loin de combien »
| Axe | Distance |
|---|---|
| Stack / outils | 🟢 ~10 % |
| Compétences techniques MVP | 🟡 ~40 % |
| Expérience / références | 🔴 ~80 % |
| Commercial (devis, délais) | 🔴 ~90 % |

**Conclusion** : techniquement très proche — ce cahier des charges est presque taillé pour
ma stack. L'écart bloquant est l'**expérience démontrable** et le **commercial**, pas le code.

---

## 3. Mission de la session Codeur

Construire le **MVP** en vrai, branche-par-branche, en suivant le périmètre ci-dessus.
Priorité de montée en compétence : l'**auth multi-utilisateurs + rôles**.

### Backlog MVP suggéré (une branche par item)
1. `feat/articles-crud` — modèle Article + CRUD complet (Quarkus + Postgres + UI Flutter).
2. `feat/stock-movements` — entrées/sorties avec historique (table mouvements + transactions).
3. `feat/auth-rbac` — authentification + rôles (Quarkus Security / OIDC). **Sujet clé.**
4. `feat/dashboard-alerts` — tableau de bord + alertes de rupture (seuils + agrégations).
5. `feat/search-filters` — recherche et filtres sur le catalogue.
6. `feat/csv-export` — export CSV des articles / mouvements.

> À traiter après le MVP : estimation de charge jalon par jalon, squelette de devis.
