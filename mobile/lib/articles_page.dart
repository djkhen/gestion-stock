import 'package:flutter/material.dart';
import 'package:mobile/widgets/historique_dialog.dart';

import 'commandes_page.dart';
import 'dashboard_page.dart';
import 'models/article.dart';
import 'models/mouvement.dart';
import 'services/article_service.dart';
import 'services/mouvement_service.dart';
import 'widgets/article_form_dialog.dart';
import 'widgets/mouvement_dialog.dart';

/// ===========================================================================
///  Catalogue ARTICLES — cœur du MVP "gestion de stocks".
///
///  Écran CRUD complet branché sur l'API Quarkus /articles :
///    - liste + recherche (?q=)
///    - ajout / édition (même formulaire)
///    - suppression
///    - indicateur visuel d'alerte de rupture (stock <= seuil)
///
///  On réutilise la constante `apiBaseUrl` définie dans main.dart pour ne pas
///  dupliquer l'adresse du backend.
/// ===========================================================================

// Le modèle Article est désormais dans models/article.dart
// Les appels au backend sont dans services/article_service.dart

///---------------------------------------------------------------------------
///              StatefulWidget
///---------------------------------------------------------------------------
class PageArticles extends StatefulWidget {
  const PageArticles({super.key});

  @override
  State<PageArticles> createState() => _PageArticlesState();
}

///---------------------------------------------------------------------------
///             State<PageArticles>
///---------------------------------------------------------------------------
class _PageArticlesState extends State<PageArticles> {
  // Le service qui parle au backend (l'UI ne fait plus d'HTTP elle-même).
  final ArticleService _service = ArticleService();

  // Service dédié aux mouvements de stock (entrée / sortie / ajustement).
  final MouvementService _mouvementService = MouvementService();

  //  un controller pour le champ de recherche
  final TextEditingController _rechercheCtrl = TextEditingController();

  // --- état (remplace _produits / _chargement / _erreur) ---
  late Future<List<Article>> _futureArticle;

  String _recherche = '';

  String _tri = 'aucun'; // valeurs : 'aucun', 'nom', 'prix_asc', 'prix_desc'
  // Mode d'affichage choisi par l'utilisateur : false = liste, true = grille.
  bool _afficherEnGrille = false;
  bool _filtreAlerte = false;

  @override
  void initState() {
    super.initState();
    _futureArticle = _service.getArticles(recherche: _recherche);
  }

// 4. ⭐ libérer le controller (ta Q6 !) — dans dispose() du State
  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  ///---------------------------------------------------------------------------
  /// GET /articles (avec ?q= si une recherche est saisie), puis met à jour l'UI.
  ///---------------------------------------------------------------------------
  Future<void> _chargerArticle() async {
    // NB : le filtre "alerte" est CLIENT-SIDE (dans _construireCorps), pas ici.
    // Ici, _recherche sert UNIQUEMENT à la recherche texte backend (?q=).
    // On réassigne le Future DANS un setState → le FutureBuilder se reconstruit.
    final futur = _service.getArticles(recherche: _recherche);
    // ⚠️ Corps en { } (et pas `=> _futureArticle = futur`) : avec la flèche,
    // la closure RENVOIE le résultat de l'affectation (un Future), et setState
    // l'interdit (« setState callback returned a Future »).

    setState(() {
      _futureArticle = futur;
    });
    // On attend la fin du vrai chargement pour que le RefreshIndicator
    // tourne jusqu'au bout (sinon le spinner disparaîtrait instantanément).
    // try/catch OBLIGATOIRE : ce Future est aussi observé par le FutureBuilder,
    // qui affiche déjà l'erreur. Sans ce catch, l'erreur serait relancée ici
    // et deviendrait une "unhandled exception" (le refresh "casse").
    try {
      await futur;
    } catch (_) {
      // Erreur déjà gérée/affichée par le FutureBuilder (snapshot.hasError).
    }
  }

  ///---------------------------------------------------------------------------
  /// Création (POST) ou modification (PUT) selon que l'article a un id.
  ///---------------------------------------------------------------------------
  Future<void> _enregistrer(Article article) async {
    final estModification = article.id != null;
    try {
      // Le service renvoie le code HTTP, l'UI choisit le message à afficher.
      final code = await _service.enregistrer(article);
      if (!mounted) return;
      if (code == 200 || code == 201) {
        _afficherMessage(estModification
            ? 'Article « ${article.designation} » modifié ✅'
            : 'Article « ${article.designation} » ajouté ✅');
        await _chargerArticle();
      } else if (code == 409) {
        _afficherMessage('Référence déjà utilisée (${article.reference}).');
      } else {
        _afficherMessage('Erreur $code lors de l\'enregistrement.');
      }
    } catch (e) {
      if (!mounted) return;
      _afficherMessage("Impossible de joindre l'API.");
    }
  }

  ///---------------------------------------------------------------------------
  /// Suppression (DELETE) après confirmation.
  ///---------------------------------------------------------------------------
  Future<void> _supprimer(Article article) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer définitivement « ${article.designation} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      final code = await _service.supprimer(article.id!);
      if (!mounted) return;
      if (code == 204) {
        _afficherMessage('Article supprimé 🗑️');
        await _chargerArticle();
      } else {
        _afficherMessage('Erreur suppression : $code');
      }
    } catch (e) {
      if (!mounted) return;
      _afficherMessage("Impossible de joindre l'API.");
    }
  }

  ///---------------------------------------------------------------------------
  /// Ouverir historique  d'article donné
  ///---------------------------------------------------------------------------
  Future<void> _ouvrirHistorique(Article article) async {
    // 1) CHARGER d'abord
    final List<Mouvement> mouvements;
    try {
      final m = await _mouvementService.historique(article.id!);
      if (!mounted) return;
      mouvements = m;
    } catch (e) {
      if (!mounted) return;
      _afficherMessage("Impossible de charger l'historique.");
      return;
    }
    // 2) AFFICHER la liste dans le dialogue
    await showDialog(
      context: context,
      builder: (_) =>
          HistoriqueDialog(article: article, mouvements: mouvements),
    );
  }

  ///---------------------------------------------------------------------------
  /// Formulaire d'ajout / édition. Pré-rempli si `existant` est fourni.
  ///  édition  => Article exite
  ///  Sreation =>  Article NON exite
  ///---------------------------------------------------------------------------
  Future<void> _ouvrirFormulaire({Article? existant}) async {
    // Le dialogue (widget) pré-remplit, capture la saisie et renvoie un Article
    // (ou null si annulé). Il gère ses 7 controllers dans son propre dispose().
    final article = await showDialog<Article>(
      context: context,
      builder: (_) => ArticleFormDialog(existant: existant),
    );
    if (article != null) {
      await _enregistrer(article);
    }
  }

  void _afficherMessage(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  ///---------------------------------------------------------------------------
  /// Dialogue pour enregistrer un mouvement de stock sur un article.
  /// Saisie : type (entrée/sortie/ajustement) + quantité + motif.
  /// Puis POST via le service, gestion des codes HTTP, et refresh de la liste.
  ///---------------------------------------------------------------------------
  Future<void> _ouvrirMouvement(Article art) async {
    // Le dialogue (widget) capture la saisie et la RENVOIE ; la page orchestre
    // (appel du service + messages + refresh). Le widget gère ses controllers seul.
    final saisie = await showDialog<SaisieMouvement>(
      context: context,
      builder: (_) => MouvementDialog(article: art),
    );
    if (saisie == null) return; // annulé (Navigator.pop sans valeur)

    final code = await _mouvementService.creer(
      articleId: art.id!,
      type: saisie.type,
      quantite: saisie.quantite,
      motif: saisie.motif,
    );
    if (!mounted) {
      return; // après un await : on vérifie que l'écran existe encore
    }

    // On traduit le code HTTP du backend en message utilisateur.
    switch (code) {
      case 201:
        _afficherMessage('Mouvement enregistré ✅');
        await _chargerArticle(); // recharge → le stock affiché se met à jour
        break;
      case 400:
        _afficherMessage('Quantité invalide (doit être positive).');
        break;
      case 409:
        _afficherMessage('Stock insuffisant pour cette sortie.');
        break;
      case 501:
        _afficherMessage('Transfert pas encore disponible.');
        break;
      default:
        _afficherMessage('Erreur $code.');
    }
  }

  ///---------------------------------------------------------------------------
  ///  build
  ///---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 Catalogue articles'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Trier',
            onSelected: (valeur) => setState(() => _tri = valeur),
            // change le tri + redessine
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'nom', child: Text('Nom (A → Z)')),
              PopupMenuItem(value: 'prix_asc', child: Text('Prix croissant ↑')),
              PopupMenuItem(
                  value: 'prix_desc', child: Text('Prix décroissant ↓')),
              PopupMenuItem(value: 'aucun', child: Text('Aucun tri')),
            ],
          ),
          IconButton(
            // Navigator.push : empile l'écran dashboard par-dessus (retour via la flèche).
            onPressed: () async {
              // ← async (car on await)
              final res = await Navigator.push<String>(
                // ← AWAIT → récupère le résultat du pop
                context,
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
              if (!mounted) return; // ← ta Q8 ! (après un await)
              if (res == 'alerte') {
                // ← LÀ on lit ce que le dashboard a renvoyé
                setState(() => _filtreAlerte = true); // applique le filtre
                _chargerArticle;
              }
            },
            tooltip: 'Tableau de bord',
            icon: const Icon(Icons.dashboard_outlined),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CommandesPage()),
            ),
            tooltip: 'Commandes',
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            onPressed: () =>
                setState(() => _afficherEnGrille = !_afficherEnGrille),
            tooltip: _afficherEnGrille ? 'Vue liste' : 'Vue grille',
            icon: Icon(_afficherEnGrille ? Icons.view_list : Icons.grid_view),
          ),
          IconButton(
            onPressed: _chargerArticle,
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Bandeau "filtre alerte actif" : pleine largeur, dans le Column ---
          // width: double.infinity → le Container prend toute la largeur (bornée par
          // le Column) → le Row interne a une largeur finie → le Spacer fonctionne.
          if (_filtreAlerte)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  const Text('Alerte uniquement'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _filtreAlerte = false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Tout afficher'),
                  ),
                ],
              ),
            ),
          // --- Barre de recherche (référence ou désignation) ---
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Expanded : borne la largeur du TextField dans la Row
                // (un TextField ne peut pas avoir une largeur infinie).
                Expanded(
                  child: TextField(
                    controller: _rechercheCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Rechercher (référence, désignation)...',
                      border: const OutlineInputBorder(),
                      suffixIcon: _recherche.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _rechercheCtrl
                                    .clear(); // ← vide le texte AFFICHÉ
                                setState(() => _recherche = '');
                                _chargerArticle();
                              },
                            ),
                    ),
                    onChanged: (v) => _recherche = v,
                    onSubmitted: (_) => _chargerArticle(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _chargerArticle,
              child: _construireCorps(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(),
        tooltip: 'Ajouter un article',
        icon: const Icon(Icons.add),
        label: const Text('Article'),
      ),
    );
  }

  ///---------------------------------------------------------------------------
  ///                      _construireCorps
  ///---------------------------------------------------------------------------
  Widget _construireCorps() {
    debugPrint("_construireCorps");
    return FutureBuilder<List<Article>>(
      future: _futureArticle,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
            ),
          );
        }

        final articles = snapshot.data ?? [];
        // Filtre CLIENT-SIDE : si _filtreAlerte actif, on ne garde que les "en alerte".
        // [...articles] = COPIE : sort() modifie EN PLACE → on ne touche pas
        // la liste du snapshot (sinon "Aucun tri" ne restaurerait plus l'ordre).
        final visibles = _filtreAlerte
            ? articles.where((a) => a.enAlerte).toList()
            : [...articles];

        if (visibles.isEmpty) {
          return Center(
            child: Text(_filtreAlerte
                ? 'Aucun article en alerte. 🎉'
                : 'Aucun article.'),
          );
        }
        switch (_tri) {
          case 'nom':
            visibles.sort((a, b) => a.designation.compareTo(b.designation));
            break;
          case 'prix_asc':
            visibles.sort((a, b) => a.prixUnitaire.compareTo(b.prixUnitaire));
            break;
          case 'prix_desc':
            visibles.sort((a, b) =>
                b.prixUnitaire.compareTo(a.prixUnitaire)); // ← a/b inversés
            break;
          // 'aucun' → on ne trie pas
        }
        // Cas DONNÉES : on renvoie la liste ou la grille selon le mode (liste FILTRÉE).
        return LayoutBuilder(
          builder: (context, constraints) => _afficherEnGrille
              ? _vueGrille(constraints.maxWidth, visibles)
              : _vueListe(visibles),
        );
      },
    );
  }

  /// Menu ⋮ des actions sur un article (centralisé : utilisé en liste ET en grille).
  Widget _menuActions(Article art) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Actions',
      onSelected: (valeur) {
        switch (valeur) {
          case 'historique':
            _ouvrirHistorique(art);
            break;
          case 'mouvement':
            _ouvrirMouvement(art);
            break;
          case 'modifier':
            _ouvrirFormulaire(existant: art);
            break;
          case 'supprimer':
            _supprimer(art);
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
            value: 'historique',
            child: Row(children: [
              Icon(Icons.history),
              SizedBox(width: 12),
              Text('Historique')
            ])),
        PopupMenuItem(
            value: 'mouvement',
            child: Row(children: [
              Icon(Icons.swap_vert),
              SizedBox(width: 12),
              Text('Mouvement')
            ])),
        PopupMenuItem(
            value: 'modifier',
            child: Row(children: [
              Icon(Icons.edit_outlined),
              SizedBox(width: 12),
              Text('Modifier')
            ])),
        PopupMenuItem(
            value: 'supprimer',
            child: Row(children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 12),
              Text('Supprimer')
            ])),
      ],
    );
  }

  //----------------------------------------------------------------------------
  // Widget presented on the PAD
  // MÉTHODE = une fonction DANS la classe
  //----------------------------------------------------------------------------
  Widget _vueListe(List<Article> articles) {
    debugPrint(" DK -- _vueListe Gestion de stock");
    // ListView (et non Center) pour que le "tirer pour rafraîchir" marche
    // même en cas d'erreur.
    // Un Center tout seul ne défile pas → le geste ne marche pas.
    // Donc on met un ListView — et oui tu peux centrer, mais DANS le ListView, pas un Center seul.

    return ListView.separated(
      itemCount: articles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final art = articles[i];
        return Container(
          // Marge horizontale : décolle le filet du bord de l'écran.
          margin: const EdgeInsets.symmetric(horizontal: 8),
          // A : filet coloré à gauche (orange si rupture, sinon indigo).
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                // Normal : gris discret. Alerte : orange franc (ça claque).
                color: art.enAlerte ? Colors.orange : Colors.grey.shade300,
                width: 4,
              ),
            ),
          ),
          child: ListTile(
            // C : fond légèrement teinté si l'article est en alerte.
            tileColor: art.enAlerte ? Colors.orange.shade50 : null,
            leading: Icon(
              art.enAlerte
                  ? Icons.warning_amber_rounded
                  : Icons.inventory_2_outlined,
              color: art.enAlerte ? Colors.orange : null,
            ),
            title: Text('${art.reference} — ${art.designation}'),
            subtitle: Text('${art.description}\n'
                '${art.prixUnitaire.toStringAsFixed(2)} € Stock ${art.quantiteStock} ${art.unite} '),
            isThreeLine: true,
            onTap: () => _ouvrirFormulaire(existant: art),
            // taper = éditer
            // Modifier puis Supprimer, côte à côte (tient dans le trailing court).
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _menuActions(art),
              ],
            ),
          ),
        );
      },
    );
  }

  // MÉTHODE = une fonction DANS la classe
  Widget _vueGrille(double largeur, List<Article> articles) {
    debugPrint(" DK -- _vueGrille Gestion de stock");
    // Une colonne par tranche d'environ 300px (minimum 2, maximum 5).
    final nbColonnes = (largeur / 300).floor().clamp(2, 5);
    return GridView.builder(
        padding: const EdgeInsets.all(12),
        /*gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),*/
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: nbColonnes,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // CHOIX : mainAxisExtent (hauteur fixe en px) PLUTOT que childAspectRatio.
          //   - mainAxisExtent  -> hauteur stable, ideal quand le contenu a une
          //     hauteur ~constante (texte + boutons). Pas de deformation au resize.
          //   - childAspectRatio -> hauteur = largeur / ratio (varie avec la largeur),
          //     plutot pour des images/tuiles qui doivent garder une forme.
          //   NB : les deux sont EXCLUSIFS (si on met les deux, mainAxisExtent gagne).
          mainAxisExtent: 150,
        ),
        itemCount: articles.length,
        itemBuilder: (context, i) {
          final art = articles[i];
          // Design "signal" : normal SOBRE (gris), alerte qui CLAQUE (orange).
          final enTeteFond =
              art.enAlerte ? Colors.orange : Colors.grey.shade200;
          final enTeteTexte = art.enAlerte ? Colors.white : Colors.black87;
          return Card(
            color: art.enAlerte ? Colors.orange.shade50 : null,
            // clipBehavior : indispensable pour que l'en-tête coloré respecte
            // les coins arrondis (sinon les angles de la bande dépassent).
            clipBehavior: Clip.antiAlias,
            // Bordure de la carte ; orange si l'article est en alerte de rupture.
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: art.enAlerte ? Colors.orange : Colors.grey.shade300,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              // taper sur la carte = éditer l'article.
              onTap: () => _ouvrirFormulaire(existant: art),
              child: Column(
                // stretch : l'en-tête prend toute la largeur de la carte.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ===== EN-TÊTE COLORÉ (icône + titre en blanc) =====
                  Container(
                    color: enTeteFond,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          art.enAlerte
                              ? Icons.warning_amber_rounded
                              : Icons.inventory_2_outlined,
                          color: enTeteTexte,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(art.reference,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: enTeteTexte),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  // ===== CORPS (description + bas de carte) =====
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Expanded : la description absorbe l'espace restant
                          // et s'ellipse -> la carte ne déborde jamais.
                          Expanded(
                            child: Text(art.description,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.grey)),
                          ),
                          const SizedBox(height: 6),
                          // Bas : unité à gauche, actions à droite (Spacer).
                          Row(
                            children: [
                              Text(
                                  "${art.prixUnitaire.toStringAsFixed(2)} € Stock ${art.quantiteStock} ${art.unite}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              // Un seul bouton ⋮ → menu des 4 actions (plus d'overflow).
                              _menuActions(art),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }
}
