import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'articles_page.dart';

void main() => runApp(const MonApp());

/// Adresse de l'API Quarkus.
///
/// IMPORTANT selon la cible :
///   - Émulateur Android  : http://10.0.2.2:8080  (10.0.2.2 = "localhost" de la machine hôte)
///   - Simulateur iOS     : http://localhost:8080
///   - Téléphone réel     : http://<IP_LOCALE_DE_VOTRE_PC>:8080  (ex: http://192.168.1.20:8080)
const String apiBaseUrl = 'http://10.0.2.2:8080';

class MonApp extends StatelessWidget {
  const MonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catalogue produits',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4F46E5),
        useMaterial3: true,
      ),
      home: const PageProduits(),
    );
  }
}

/// Modèle Produit (miroir de l'entité Quarkus).
class Produit {
  final int? id;
  final String nom;
  final String description;
  final double prix;

  Produit({this.id, required this.nom, required this.description, required this.prix});

  factory Produit.fromJson(Map<String, dynamic> json) => Produit(
        id: json['id'],
        nom: json['nom'] ?? '',
        description: json['description'] ?? '',
        prix: (json['prix'] ?? 0).toDouble(),
      );

  /// Convertit un Produit en Map JSON (l'inverse de fromJson).
  /// Utilisé pour ENVOYER le produit à l'API (POST/PUT).
  /// On n'envoie pas l'id : c'est le backend qui le génère à la création.
  Map<String, dynamic> toJson() => {
        'nom': nom,
        'description': description,
        'prix': prix,
      };
}
///---------------------------------------------------------------------------
///              StatefulWidget
///---------------------------------------------------------------------------
class PageProduits extends StatefulWidget {
  const PageProduits({super.key});

  @override
  State<PageProduits> createState() => _PageProduitsState();
}
///---------------------------------------------------------------------------
///             State<PageProduits>
///---------------------------------------------------------------------------
class _PageProduitsState extends State<PageProduits> {
  List<Produit> _produits = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }
  ///---------------------------------------------------------------------------
  ///
  ///---------------------------------------------------------------------------
  Future<void> _charger() async {
    // async et await L'appel réseau prend du temps → on attend sans bloquer l'interface
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final reponse = await http.get(Uri.parse('$apiBaseUrl/produits'));
      if (reponse.statusCode == 200) {
        //Transforme le texte JSON en liste Dart
        final List<dynamic> data = jsonDecode(reponse.body);
        setState(() {
          //Convertit chaque élément JSON en objet Produit
          _produits = data.map((e) => Produit.fromJson(e)).toList();
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
        _erreur = "Impossible de joindre l'API.\nVérifiez l'adresse ($apiBaseUrl) et que le backend tourne.";
        _chargement = false;
      });
    }
  }

  ///---------------------------------------------------------------------------
  /// Envoie un nouveau produit au backend (POST), puis recharge la liste.
  ///---------------------------------------------------------------------------
  Future<void> _creer(Produit produit) async {
    try {
      final reponse = await http.post(
        Uri.parse('$apiBaseUrl/produits'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(produit.toJson()),
      );
      // Après un await, le widget peut avoir été retiré de l'écran :
      // on vérifie `mounted` avant de toucher au contexte (bonne pratique).
      if (!mounted) return;
      if (reponse.statusCode == 201) {
        _afficherMessage('Produit « ${produit.nom} » ajouté ✅');
        await _charger(); // rafraîchit la liste avec le nouveau produit
      } else {
        _afficherMessage('Erreur création : ${reponse.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _afficherMessage("Impossible de joindre l'API.");
    }
  }
  ///---------------------------------------------------------------------------
  /// Ouvre une boîte de dialogue avec un formulaire de saisie.
  /// Retourne un Produit (via Navigator.pop) si l'utilisateur valide.
  ///----------------------------------------------------------------------------
  Future<void> _ouvrirFormulaireAjout() async {
    // Les controllers donnent accès au texte saisi dans chaque champ.
    final nomCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final prixCtrl = TextEditingController();

    final produit = await showDialog<Produit>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau produit'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomCtrl,
                // autofocus : le champ prend le focus dès l'ouverture du
                // dialogue -> le clavier s'affiche automatiquement.
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nom'),
                textCapitalization: TextCapitalization.sentences,
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: prixCtrl,
                decoration: const InputDecoration(labelText: 'Prix (ex: 19.90)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // ferme sans rien renvoyer
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final nom = nomCtrl.text.trim();
              if (nom.isEmpty) return; // validation minimale : nom obligatoire
              // On accepte la virgule ET le point pour le prix (clavier FR/EN).
              final prix = double.tryParse(prixCtrl.text.replaceAll(',', '.')) ?? 0;
              Navigator.pop(
                context,
                Produit(nom: nom, description: descCtrl.text.trim(), prix: prix),
              );
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    // showDialog renvoie le Produit passé à Navigator.pop (ou null si annulé).
    if (produit != null) {
      await _creer(produit);
    }
  }
  //----------------------------------------------------------------------------
  /// Affiche un petit message temporaire en bas de l'écran.
  //----------------------------------------------------------------------------
   void _afficherMessage(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texte)),
    );
  }
  //----------------------------------------------------------------------------
  //
  //----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛍️ Catalogue produits'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PageArticles()),
            ),
            tooltip: 'Catalogue articles (stock)',
            icon: const Icon(Icons.inventory_2),
          ),
          IconButton(
            onPressed: _charger,
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      //RefreshIndicator	⭐ Permet de tirer vers le bas pour rafraîchir (geste mobile classique) → rappelle _charger()
      body: RefreshIndicator(
        onRefresh: _charger,
        child: _construireCorps(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _ouvrirFormulaireAjout,
        tooltip: 'Ajouter un produit',
        child: const Icon(Icons.add),
      ),
    );
  }
  //----------------------------------------------------------------------------
  //
  //----------------------------------------------------------------------------
  Widget _construireCorps() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_erreur!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    if (_produits.isEmpty) {
      return const Center(child: Text('Aucun produit.'));
    }
    return ListView.separated(
      itemCount: _produits.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = _produits[i];
        return ListTile(
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(p.nom),
          subtitle: Text(p.description),
          trailing: Text('${p.prix.toStringAsFixed(2)} €',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}
