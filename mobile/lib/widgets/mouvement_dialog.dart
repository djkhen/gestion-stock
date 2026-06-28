import 'package:flutter/material.dart';

import '../models/article.dart';

/// Résultat de la saisie d'un mouvement, renvoyé par le dialogue à la page.
/// (C'est un *record* Dart 3 : un petit regroupement de valeurs sans créer une classe.)
typedef SaisieMouvement = ({String type, int quantite, String motif});

/// Dialogue de saisie d'un mouvement de stock pour un article.
///
/// UI PURE : il capture la saisie et la RENVOIE (via Navigator.pop) — c'est la
/// PAGE qui appelle le service et rafraîchit. Étant un StatefulWidget, il gère
/// ses TextEditingController dans son propre dispose() → plus aucune fuite mémoire.
class MouvementDialog extends StatefulWidget {
  final Article article;

  const MouvementDialog({super.key, required this.article});

  @override
  State<MouvementDialog> createState() => _MouvementDialogState();
}

class _MouvementDialogState extends State<MouvementDialog> {
  String _type = 'ENTREE'; // type sélectionné (défaut)
  final _qteCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();

  @override
  void dispose() {
    // Flutter appelle dispose() tout seul à la fermeture du dialogue.
    _qteCtrl.dispose();
    _motifCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = widget.article; // accès au paramètre passé au widget
    return AlertDialog(
      title: Text('Mouvement — ${art.reference}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Stock actuel : ${art.quantiteStock}'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'ENTREE', child: Text('Entrée (+)')),
              DropdownMenuItem(value: 'SORTIE', child: Text('Sortie (−)')),
              DropdownMenuItem(
                  value: 'AJUSTEMENT', child: Text('Ajustement (=)')),
            ],
            // setState NORMAL : plus besoin de StatefulBuilder, le dialogue EST Stateful.
            onChanged: (v) => setState(() => _type = v!),
          ),
          TextField(
            controller: _qteCtrl,
            decoration: const InputDecoration(labelText: 'Quantité'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _motifCtrl,
            decoration: const InputDecoration(labelText: 'Motif (optionnel)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // Annuler → renvoie null
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final quantite = int.tryParse(_qteCtrl.text.trim()) ?? 0;
            // Valider → renvoie la saisie à la page (record).
            Navigator.pop(context, (
              type: _type,
              quantite: quantite,
              motif: _motifCtrl.text.trim(),
            ));
          },
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
