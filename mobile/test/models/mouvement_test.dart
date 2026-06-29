// Tests UNITAIRES du modèle Mouvement.
// Cible : fromJson, en particulier le parsing de la date (DateTime.parse).

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/mouvement.dart';

void main() {
  group('Mouvement.fromJson', () {
    test('mappe les champs et parse la date ISO', () {
      final json = {
        'id': 7,
        'type': 'ENTREE',
        'quantite': 50,
        'date': '2026-06-29T14:30:00',
        'motif': 'Réception fournisseur',
      };

      final m = Mouvement.fromJson(json);

      expect(m.id, 7);
      expect(m.type, 'ENTREE');
      expect(m.quantite, 50);
      expect(m.motif, 'Réception fournisseur');
      // La date est bien un DateTime, décomposée correctement.
      expect(m.date, isA<DateTime>());
      expect(m.date.year, 2026);
      expect(m.date.month, 6);
      expect(m.date.day, 29);
      expect(m.date.hour, 14);
    });

    test('applique les défauts pour type/quantite/motif manquants', () {
      // date reste obligatoire (DateTime.parse plante si absente) → on la fournit.
      final m = Mouvement.fromJson({'id': 1, 'date': '2026-01-01T00:00:00'});

      expect(m.type, '');
      expect(m.quantite, 0);
      expect(m.motif, '');
    });
  });
}
