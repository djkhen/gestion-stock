import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'main.dart' show apiBaseUrl;

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

/// Modèle Article — miroir de l'entité Quarkus du même nom.
class Article {
  final int? id;
  final String reference;
  final String designation;
  final String description;
  final String unite;
  final int quantiteStock;
  final int seuilAlerte;
  final double prixUnitaire;

  Article({
    this.id,
    required this.reference,
    required this.designation,
    required this.description,
    required this.unite,
    required this.quantiteStock,
    required this.seuilAlerte,
    required this.prixUnitaire,
  });

  /// Vrai si le stock est au niveau d'alerte ou en dessous (rupture imminente).
  bool get enAlerte => quantiteStock <= seuilAlerte;

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id'],
        reference: json['reference'] ?? '',
        designation: json['designation'] ?? '',
        description: json['description'] ?? '',
        unite: json['unite'] ?? 'piece',
        quantiteStock: (json['quantiteStock'] ?? 0) as int,
        seuilAlerte: (json['seuilAlerte'] ?? 0) as int,
        prixUnitaire: (json['prixUnitaire'] ?? 0).toDouble(),
      );

  /// On n'envoie pas l'id : le backend le génère à la création.
  Map<String, dynamic> toJson() => {
        'reference': reference,
        'designation': designation,
        'description': description,
        'unite': unite,
        'quantiteStock': quantiteStock,
        'seuilAlerte': seuilAlerte,
        'prixUnitaire': prixUnitaire,
      };
}

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
      // Construit l'URL avec le paramètre de recherche éventuel.
      final uri = Uri.parse('$apiBaseUrl/articles').replace(
        queryParameters:
            _recherche.trim().isEmpty ? null : {'q': _recherche.trim()},
      );
      final reponse = await http.get(uri);
      if (reponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(reponse.bodyBytes));
        setState(() {
          _articles = data.map((e) => Article.fromJson(e)).toList();
          _chargement = false;
        });
      } else {
        setState(() {
          _erreur = 'Erreur serveur : ${reponse.statusCode}';
          _chargement = false;
        });
      }
    } catch (e) {
      setState(() {
        _erreur = "Impossible de joindre l'API.\n"
            "Vérifiez l'adresse ($apiBaseUrl) et que le backend tourne.";
        _chargement = false;
      });
    }
  }

  ///---------------------------------------------------------------------------
  /// Création (POST) ou modification (PUT) selon que l'article a un id.
  ///---------------------------------------------------------------------------
  Future<void> _enregistrer(Article article) async {
    final estModification = article.id != null;
    final uri = estModification
        ? Uri.parse('$apiBaseUrl/articles/${article.id}')
        : Uri.parse('$apiBaseUrl/articles');
    try {
      final reponse = estModification
          ? await http.put(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(article.toJson()))
          : await http.post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(article.toJson()));
      if (!mounted) return;
      // 200 (PUT) ou 201 (POST) = succès.
      if (reponse.statusCode == 200 || reponse.statusCode == 201) {
        _afficherMessage(estModification
            ? 'Article « ${article.designation} » modifié ✅'
            : 'Article « ${article.designation} » ajouté ✅');
        await _charger();
      } else if (reponse.statusCode == 409) {
        _afficherMessage('Référence déjà utilisée (${article.reference}).');
      } else {
        _afficherMessage('Erreur ${reponse.statusCode} : ${reponse.body}');
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
      final reponse =
          await http.delete(Uri.parse('$apiBaseUrl/articles/${article.id}'));
      if (!mounted) return;
      if (reponse.statusCode == 204) {
        _afficherMessage('Article supprimé 🗑️');
        await _charger();
      } else {
        _afficherMessage('Erreur suppression : ${reponse.statusCode}');
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
    final prixCtrl = TextEditingController(
        text: (existant?.prixUnitaire ?? 0).toString());

    final article = await showDialog<Article>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existant == null ? 'Nouvel article' : 'Modifier l\'article'),
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
                decoration: const InputDecoration(labelText: 'Quantité en stock'),
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
                  id: existant?.id, // conserve l'id en édition -> déclenche un PUT
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
            child: TextField(
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
      return ListView(
        // ListView (et non Center) pour que le "tirer pour rafraîchir" marche
        // même en cas d'erreur.
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_erreur!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
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
    return ListView.separated(
      itemCount: _articles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final a = _articles[i];
        return ListTile(
          leading: Icon(
            a.enAlerte ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
            color: a.enAlerte ? Colors.orange : null,
          ),
          title: Text('${a.reference} — ${a.designation}'),
          subtitle: Text(
            'Stock : ${a.quantiteStock} ${a.unite}'
            '${a.enAlerte ? '  ⚠️ sous le seuil (${a.seuilAlerte})' : ''}'
            '\n${a.prixUnitaire.toStringAsFixed(2)} € / ${a.unite}',
          ),
          isThreeLine: true,
          onTap: () => _ouvrirFormulaire(existant: a),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
            onPressed: () => _supprimer(a),
          ),
        );
      },
    );
  }
}
