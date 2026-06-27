import 'dart:convert';
import 'package:http/http.dart' as http;

import '../main.dart' show apiBaseUrl;

/// Service d'accès à l'API /mouvements du backend Quarkus.
///
/// Même rôle que ArticleService : parler au backend (HTTP), zéro logique d'UI.
/// Un mouvement modifie le stock de l'article côté serveur (ENTREE/SORTIE/AJUSTEMENT).
class MouvementService {
  final String baseUrl;
  MouvementService({this.baseUrl = apiBaseUrl});

  /// POST /mouvements?articleId=X  avec  { type, quantite, motif }.
  ///
  /// Renvoie le code HTTP pour que l'UI affiche le bon message :
  ///   201 = créé (stock mis à jour)
  ///   400 = quantité invalide
  ///   404 = article introuvable
  ///   409 = stock insuffisant (SORTIE)
  ///   501 = TRANSFERT pas encore dispo
  Future<int> creer({
    required int articleId,
    required String type,
    required int quantite,
    String motif = '',
  }) async {
    // L'articleId va en paramètre d'URL (comme le backend l'attend) ;
    // le reste (type/quantite/motif) va dans le corps JSON.
    final uri = Uri.parse('$baseUrl/mouvements?articleId=$articleId');
    final reponse = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'type': type, 'quantite': quantite, 'motif': motif}),
    );
    return reponse.statusCode;
  }
}
