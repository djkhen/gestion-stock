import 'package:flutter/material.dart';

import 'models/article.dart';
import 'services/article_service.dart';

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

  List<Article> _articles = [];
  bool _chargement = true;
  String? _erreur;
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  ///---------------------------------------------------------------------------
  /// GET /articles (avec ?q= si une recherche est saisie), puis met à jour l'UI.
  ///---------------------------------------------------------------------------
  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      // Tout l'HTTP est dans le service → ici on ne fait que demander la liste.
      final articles = await _service.liste(recherche: _recherche);
      if (!mounted) return;
      setState(() {
        _articles = articles;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = "Impossible de charger les articles.\n"
            "Vérifiez que le backend tourne.";
        _chargement = false;
      });
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
        await _charger();
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
        await _charger();
      } else {
        _afficherMessage('Erreur suppression : $code');
      }
    } catch (e) {
      if (!mounted) return;
      _afficherMessage("Impossible de joindre l'API.");
    }
  }

  ///---------------------------------------------------------------------------
  /// Formulaire d'ajout / édition. Pré-rempli si `existant` est fourni.
  ///---------------------------------------------------------------------------
  Future<void> _ouvrirFormulaire({Article? existant}) async {
    final refCtrl = TextEditingController(text: existant?.reference ?? '');
    final desigCtrl = TextEditingController(text: existant?.designation ?? '');
    final descCtrl = TextEditingController(text: existant?.description ?? '');
    final uniteCtrl = TextEditingController(text: existant?.unite ?? 'piece');
    final qteCtrl =
        TextEditingController(text: (existant?.quantiteStock ?? 0).toString());
    final seuilCtrl =
        TextEditingController(text: (existant?.seuilAlerte ?? 0).toString());
    final prixCtrl =
        TextEditingController(text: (existant?.prixUnitaire ?? 0).toString());

    final article = await showDialog<Article>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(existant == null ? 'Nouvel article' : 'Modifier l\'article'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: refCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Référence *', hintText: 'ex: VIS-M6-20'),
              ),
              TextField(
                controller: desigCtrl,
                decoration: const InputDecoration(labelText: 'Désignation *'),
                textCapitalization: TextCapitalization.sentences,
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: uniteCtrl,
                decoration: const InputDecoration(
                    labelText: 'Unité', hintText: 'piece, kg, litre...'),
              ),
              TextField(
                controller: qteCtrl,
                decoration:
                    const InputDecoration(labelText: 'Quantité en stock'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: seuilCtrl,
                decoration: const InputDecoration(labelText: 'Seuil d\'alerte'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: prixCtrl,
                decoration: const InputDecoration(
                    labelText: 'Prix unitaire (ex: 1.45)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final reference = refCtrl.text.trim();
              final designation = desigCtrl.text.trim();
              // Validation minimale côté client (le backend revalide de toute façon).
              if (reference.isEmpty || designation.isEmpty) return;
              Navigator.pop(
                context,
                Article(
                  id: existant?.id,
                  // conserve l'id en édition -> déclenche un PUT
                  reference: reference,
                  designation: designation,
                  description: descCtrl.text.trim(),
                  unite: uniteCtrl.text.trim().isEmpty
                      ? 'piece'
                      : uniteCtrl.text.trim(),
                  quantiteStock: int.tryParse(qteCtrl.text.trim()) ?? 0,
                  seuilAlerte: int.tryParse(seuilCtrl.text.trim()) ?? 0,
                  prixUnitaire:
                      double.tryParse(prixCtrl.text.replaceAll(',', '.')) ?? 0,
                ),
              );
            },
            child: Text(existant == null ? 'Ajouter' : 'Enregistrer'),
          ),
        ],
      ),
    );

    if (article != null) {
      await _enregistrer(article);
    }
  }

  void _afficherMessage(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
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
          IconButton(
            onPressed: _charger,
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Barre de recherche (référence ou désignation) ---
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Rechercher (référence, désignation)...',
                    border: const OutlineInputBorder(),
                    suffixIcon: _recherche.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _recherche = '');
                              _charger();
                            },
                          ),
                  ),
                  onChanged: (v) => _recherche = v,
                  onSubmitted: (_) => _charger(),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _charger,
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

  Widget _construireCorps() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreur != null) {
      return Center(
        // ← le message d'erreur revient ICI
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_erreur!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    if (_articles.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.all(24),
            child: Text('Aucun article.', textAlign: TextAlign.center),
          ),
        ],
      );
    }

    // Liste ADAPTATIVE : la mise en page change selon la largeur disponible.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint : < 600px = mobile (listeView.Builder) ; si >= 600px = grand écran (GridView.builder)
        if (constraints.maxWidth < 600) {
          return _vueListe();
        }
        return _vueGrille(constraints.maxWidth);
      },
    );
  }

  //----------------------------------------------------------------------------
  // Widget presented on the PAD
  // MÉTHODE = une fonction DANS la classe
  //----------------------------------------------------------------------------
  Widget _vueListe() {
    debugPrint(" DK -- _vueGrille Gestion de stock");
    // ListView (et non Center) pour que le "tirer pour rafraîchir" marche
    // même en cas d'erreur.
    // Un Center tout seul ne défile pas → le geste ne marche pas.
    // Donc on met un ListView — et oui tu peux centrer, mais DANS le ListView, pas un Center seul.

    return ListView.separated(
      itemCount: _articles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = _articles[i];
        return ListTile(
          leading: Icon(
            p.enAlerte
                ? Icons.warning_amber_rounded
                : Icons.inventory_2_outlined,
            color: p.enAlerte ? Colors.orange : null,
          ),
          title: Text('${p.reference} — ${p.designation}'),
          subtitle:
              Text('${p.description}\n${p.prixUnitaire.toStringAsFixed(2)} €'),
          isThreeLine: true,
          onTap: () => _ouvrirFormulaire(existant: p),
          // taper = éditer aussi
          // Modifier puis Supprimer, côte à côte (Row : tient dans le trailing court du ListTile).

          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Modifier',
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _ouvrirFormulaire(existant: p),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Supprimer',
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _supprimer(p),
              ),
            ],
          ),
        );
      },
    );
  }

  // MÉTHODE = une fonction DANS la classe
  Widget _vueGrille(double largeur) {
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
          childAspectRatio: 1.6,
        ),
        /*
        final int? id;
        final String reference;
        final String designation;
        final String description;
        final String unite;
        final int quantiteStock;
        final int seuilAlerte;
        final double prixUnitaire;
        */
        itemCount: _articles.length,
        itemBuilder: (context, i) {
          final art = _articles[i];
          return Card(
            color: art.enAlerte ? Colors.orange.shade50 : null,
            child: InkWell(
              //------------------------------------------------
              // pour éditer l'article le ckick est sur InkWell
              //------------------------------------------------
              onTap: () => _ouvrirFormulaire(existant: art), // taper = éditer
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          art.enAlerte
                              ? Icons.warning_amber_rounded
                              : Icons.inventory_2_outlined,
                          color: art.enAlerte ? Colors.orange : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(art.reference,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                        ),
                        // Modifier puis Supprimer, côte à côte (Row : tient dans le trailing court du ListTile).

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Modifier',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _ouvrirFormulaire(existant: art),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Supprimer',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _supprimer(art),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(art.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 6),
                    Text(art.unite.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          );
        });
  }
}
