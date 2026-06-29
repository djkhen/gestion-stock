import 'package:flutter/material.dart';

import 'models/article.dart';
import 'services/article_service.dart';

/// Tableau de bord : statistiques calculées à partir de la liste d'articles.
///
/// Réutilise le même service + le pattern FutureBuilder que l'écran principal.
/// Les stats sont calculées côté client à partir de la liste reçue
/// (nombre, alertes, stock total, valorisation = Σ quantité × prix).
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ArticleService _service = ArticleService();
  late Future<List<Article>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getArticles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Tableau de bord'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<List<Article>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          final articles = snapshot.data ?? [];

          // --- Calcul des statistiques à partir de la liste ---
          final nbArticles = articles.length;
          // where(...) filtre, .length compte → nombre d'articles en alerte.
          final nbAlerte = articles.where((a) => a.enAlerte).length;
          // fold = "réduire" la liste en UNE valeur (accumulateur).
          final stockTotal =
              articles.fold<int>(0, (somme, a) => somme + a.quantiteStock);
          final valorisation = articles.fold<double>(
              0, (somme, a) => somme + a.quantiteStock * a.prixUnitaire);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.25,
              children: [
                _carteStat('Articles', '$nbArticles',
                    Icons.inventory_2_outlined, Colors.indigo),
                _carteStat('En alerte', '$nbAlerte',
                    Icons.warning_amber_rounded, Colors.orange,
                    onTap: () => Navigator.pop(context, 'alerte')),

                // ← pop AVEC résultat
                _carteStat(
                    'Stock total', '$stockTotal', Icons.layers, Colors.teal),
                _carteStat(
                    'Valorisation',
                    '${valorisation.toStringAsFixed(2)} €',
                    Icons.euro,
                    Colors.green),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Une carte de statistique : icône + grande valeur + libellé.
  Widget _carteStat(String label, String valeur, IconData icone, Color couleur,
      {VoidCallback? onTap}) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 36, color: couleur),
              const SizedBox(height: 10),
              Text(valeur,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}
