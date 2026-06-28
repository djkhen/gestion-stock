import 'package:flutter/material.dart';

import '../models/article.dart';
import '../models/mouvement.dart';

/// Dialogue affichant l'historique des mouvements d'un article.
/// STATELESS : il ne fait qu'AFFICHER une liste reçue toute prête
/// (pas de controller, pas d'état, pas de dispose → le plus simple).
class HistoriqueDialog extends StatelessWidget {
  final Article article;
  final List<Mouvement> mouvements; // ← la liste, déjà chargée par la page
  const HistoriqueDialog({
    super.key,
    required this.article,
    required this.mouvements,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Historique — ${article.designation}'),
      content: mouvements.isEmpty
          ? const Text('Aucun mouvement.')
          : SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: mouvements
                    .map((m) => ListTile(
                          onTap: () {
                            /* ex: afficher le détail du mouvement ? */
                          },
                          title: Text('${m.type}  ×${m.quantite}'),
                          subtitle: Text(
                            '${m.date.day}/${m.date.month}/${m.date.year} '
                            '${m.date.hour}h${m.date.minute} — ${m.motif}',
                          ),
                        ))
                    .toList(),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
      ],
    );
  }
}
