// WIDGET test de HistoriqueDialog.
//
// Différence avec un test unitaire : ici on CONSTRUIT réellement le widget dans
// un arbre Flutter (tester.pumpWidget) et on inspecte ce qui est affiché à
// l'écran (find.text...). On utilise donc `testWidgets`, pas `test`.
//
// HistoriqueDialog est idéal : il reçoit ses données en paramètre (pas de HTTP),
// donc le test est déterministe et rapide.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/article.dart';
import 'package:mobile/models/mouvement.dart';
import 'package:mobile/widgets/historique_dialog.dart';

void main() {
  // Un article minimal réutilisé dans les tests.
  final article = Article(
    reference: 'REF-1',
    designation: 'Vis M6',
    description: '',
    unite: 'piece',
    quantiteStock: 10,
    seuilAlerte: 5,
    prixUnitaire: 1.0,
  );

  // Helper : enrobe le dialog dans un MaterialApp (un widget Material a besoin
  // d'un Directionality + Theme fournis par MaterialApp/Scaffold).
  Widget enrober(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('affiche "Aucun mouvement." quand la liste est vide',
      (tester) async {
    await tester.pumpWidget(
      enrober(HistoriqueDialog(article: article, mouvements: const [])),
    );

    expect(find.text('Aucun mouvement.'), findsOneWidget);
    // Le titre reprend la désignation de l'article.
    expect(find.text('Historique — Vis M6'), findsOneWidget);
  });

  testWidgets('affiche une ligne par mouvement', (tester) async {
    final mouvements = [
      Mouvement(
        id: 1,
        type: 'ENTREE',
        quantite: 50,
        date: DateTime(2026, 6, 29, 14, 30),
        motif: 'Réception',
      ),
      Mouvement(
        id: 2,
        type: 'SORTIE',
        quantite: 5,
        date: DateTime(2026, 6, 30, 9, 0),
        motif: 'Commande',
      ),
    ];

    await tester.pumpWidget(
      enrober(HistoriqueDialog(article: article, mouvements: mouvements)),
    );

    // Le message "vide" ne doit PAS apparaître.
    expect(find.text('Aucun mouvement.'), findsNothing);
    // Chaque mouvement affiche "type  ×quantite".
    expect(find.text('ENTREE  ×50'), findsOneWidget);
    expect(find.text('SORTIE  ×5'), findsOneWidget);
    // Deux ListTile attendues (une par mouvement).
    expect(find.byType(ListTile), findsNWidgets(2));
  });
}
