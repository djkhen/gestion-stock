import 'package:flutter/material.dart';

import '../models/article.dart';

/// Dialogue de création / édition d'un article.
///
/// PUBLIC (pas de `_`) → importable depuis la page. Pré-rempli si [existant]
/// est fourni (édition). Il RENVOIE un [Article] via Navigator.pop (ou null si
/// annulé). StatefulWidget → il gère ses 7 controllers dans son propre
/// dispose() (zéro fuite, plus de gestion manuelle).
class ArticleFormDialog extends StatefulWidget {
  /// L'article à éditer ; null = création.
  final Article? existant;

  const ArticleFormDialog({super.key, this.existant});

  @override
  State<ArticleFormDialog> createState() => _ArticleFormDialogState();
}

class _ArticleFormDialogState extends State<ArticleFormDialog> {
  // late final = déclaration SEULE (type explicite, pas d'initialiseur) :
  // on les crée dans initState, là où `widget` est accessible.
  late final TextEditingController _refCtrl;
  late final TextEditingController _desigCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _uniteCtrl;
  late final TextEditingController _qteCtrl;
  late final TextEditingController _seuilCtrl;
  late final TextEditingController _prixCtrl;

  @override
  void initState() {
    super.initState();
    final a = widget.existant; // null = création
    _refCtrl = TextEditingController(text: a?.reference ?? '');
    _desigCtrl = TextEditingController(text: a?.designation ?? '');
    _descCtrl = TextEditingController(text: a?.description ?? '');
    _uniteCtrl = TextEditingController(text: a?.unite ?? 'piece');
    // ⚠️ un int doit devenir une String pour un controller → .toString()
    _qteCtrl = TextEditingController(text: (a?.quantiteStock ?? 0).toString());
    _seuilCtrl = TextEditingController(text: (a?.seuilAlerte ?? 0).toString());
    _prixCtrl = TextEditingController(text: (a?.prixUnitaire ?? 0).toString());
  }

  @override
  void dispose() {
    // Le but du refacto : chaque controller libéré automatiquement.
    _refCtrl.dispose();
    _desigCtrl.dispose();
    _descCtrl.dispose();
    _uniteCtrl.dispose();
    _qteCtrl.dispose();
    _seuilCtrl.dispose();
    _prixCtrl.dispose();
    super.dispose();
  }

  /// Valide la saisie puis renvoie l'Article construit à la page.
  void _valider() {
    final reference = _refCtrl.text.trim();
    final designation = _desigCtrl.text.trim();
    // Validation minimale côté client (le backend revalide de toute façon).
    if (reference.isEmpty || designation.isEmpty) return;
    Navigator.pop(
      context,
      Article(
        id: widget.existant?.id,
        // conserve l'id en édition -> déclenche un PUT
        reference: reference,
        designation: designation,
        description: _descCtrl.text.trim(),
        unite:
            _uniteCtrl.text.trim().isEmpty ? 'piece' : _uniteCtrl.text.trim(),
        quantiteStock: int.tryParse(_qteCtrl.text.trim()) ?? 0,
        seuilAlerte: int.tryParse(_seuilCtrl.text.trim()) ?? 0,
        prixUnitaire: double.tryParse(_prixCtrl.text.replaceAll(',', '.')) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estEdition = widget.existant != null;
    return AlertDialog(
      title: Text(estEdition ? 'Modifier l\'article' : 'Nouvel article'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _refCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Référence *', hintText: 'ex: VIS-M6-20'),
            ),
            TextField(
              controller: _desigCtrl,
              decoration: const InputDecoration(labelText: 'Désignation *'),
              textCapitalization: TextCapitalization.sentences,
            ),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: _uniteCtrl,
              decoration: const InputDecoration(
                  labelText: 'Unité', hintText: 'piece, kg, litre...'),
            ),
            TextField(
              controller: _qteCtrl,
              readOnly: estEdition, // en édition : non modifiable directement
              decoration: InputDecoration(
                labelText: 'Quantité en stock',
                // Signale visuellement que le stock se change via les Mouvements.
                helperText:
                    estEdition ? '🔒 Modifiable via les Mouvements (⋮)' : null,
                filled: estEdition,
                fillColor: estEdition ? Colors.grey.shade200 : null,
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _seuilCtrl,
              decoration: const InputDecoration(labelText: 'Seuil d\'alerte'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _prixCtrl,
              decoration:
                  const InputDecoration(labelText: 'Prix unitaire (ex: 1.45)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // Annuler -> renvoie null
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _valider,
          child: Text(estEdition ? 'Enregistrer' : 'Ajouter'),
        ),
      ],
    );
  }
}
