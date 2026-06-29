// Tests UNITAIRES du modèle Article.
//
// Un test unitaire = on teste UNE unité de logique (ici une classe), SANS
// Flutter, sans réseau, sans écran. C'est rapide et ça cible la règle métier.
//
// On utilise `test(...)` (et pas `testWidgets`) car il n'y a aucun widget.
// Lancer :  flutter test test/models/article_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/article.dart';

void main() {
  // group = regroupe des tests liés sous un même titre (lisibilité du rapport).
  group('Article.enAlerte', () {
    // Petite fabrique locale : un Article "de base" qu'on personnalise.
    // Évite de répéter les 8 champs requis dans chaque test.
    Article articleAvec({required int stock, required int seuil}) => Article(
          reference: 'REF-1',
          designation: 'Vis M6',
          description: '',
          unite: 'piece',
          quantiteStock: stock,
          seuilAlerte: seuil,
          prixUnitaire: 1.0,
        );

    test('en alerte quand le stock est SOUS le seuil', () {
      final a = articleAvec(stock: 3, seuil: 5);
      expect(a.enAlerte, isTrue);
    });

    test('en alerte quand le stock EST ÉGAL au seuil (cas limite <=)', () {
      // Le cas limite est le plus important : la règle est `<=`, pas `<`.
      final a = articleAvec(stock: 5, seuil: 5);
      expect(a.enAlerte, isTrue);
    });

    test('PAS en alerte quand le stock est AU-DESSUS du seuil', () {
      final a = articleAvec(stock: 10, seuil: 5);
      expect(a.enAlerte, isFalse);
    });
  });

  group('Article.fromJson', () {
    test('mappe correctement tous les champs', () {
      final json = {
        'id': 42,
        'reference': 'REF-9',
        'designation': 'Boulon',
        'description': 'inox',
        'unite': 'piece',
        'quantiteStock': 100,
        'seuilAlerte': 20,
        'prixUnitaire': 2.5,
      };

      final a = Article.fromJson(json);

      expect(a.id, 42);
      expect(a.reference, 'REF-9');
      expect(a.designation, 'Boulon');
      expect(a.quantiteStock, 100);
      expect(a.prixUnitaire, 2.5);
    });

    test('applique les valeurs par défaut quand des champs manquent', () {
      // Le backend peut renvoyer un JSON partiel → les `?? défaut` protègent.
      final a = Article.fromJson({'id': 1});

      expect(a.reference, '');
      expect(a.unite, 'piece'); // défaut métier
      expect(a.quantiteStock, 0);
      expect(a.seuilAlerte, 0);
      expect(a.prixUnitaire, 0.0);
    });

    test('convertit un prix ENTIER du JSON en double (.toDouble())', () {
      // Piège JSON : si le backend envoie 7 (int) et non 7.0, le cast `as double`
      // planterait. fromJson fait `.toDouble()` → on vérifie que ça tient.
      final a = Article.fromJson({'id': 1, 'prixUnitaire': 7});

      expect(a.prixUnitaire, 7.0);
      expect(a.prixUnitaire, isA<double>());
    });
  });

  group('Article.toJson', () {
    test("n'inclut PAS l'id (généré par le backend à la création)", () {
      final a = Article(
        id: 99,
        reference: 'REF',
        designation: 'X',
        description: '',
        unite: 'piece',
        quantiteStock: 1,
        seuilAlerte: 0,
        prixUnitaire: 1.0,
      );

      final json = a.toJson();

      expect(json.containsKey('id'), isFalse);
      expect(json['reference'], 'REF');
    });
  });
}
