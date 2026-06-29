import 'dart:convert';

import 'package:http/http.dart' as http;

import '../main.dart' show apiBaseUrl;
import '../models/article.dart';

/// Service d'accès à l'API /articles du backend Quarkus.
///
/// Rôle UNIQUE : parler au backend (HTTP) et renvoyer des données Dart propres.
/// Il ne contient AUCUNE logique d'interface (pas de setState, pas de dialogue).
/// Avantages : l'UI ne dépend pas de "comment" on appelle l'API, c'est testable,
/// et le jour où on passe de http à dio (ou on change l'URL), on ne touche qu'ICI.
class ArticleService {
  /// URL de base de l'API (par défaut celle de main.dart).
  final String baseUrl;

  ArticleService({this.baseUrl = apiBaseUrl});

  /// GET /articles (avec ?q= si une recherche est fournie).
  /// Renvoie la liste des articles, ou lève une exception en cas d'échec.
  Future<List<Article>> getArticles({String recherche = ''}) async {
    final uri = Uri.parse('$baseUrl/articles').replace(
      queryParameters:
          recherche.trim().isEmpty ? null : {'q': recherche.trim()},
    );
    final reponse = await http.get(uri);
    if (reponse.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(reponse.bodyBytes));
      return data.map((e) => Article.fromJson(e)).toList();
    }
    throw Exception('Erreur serveur : ${reponse.statusCode}');
  }

  /// Crée (POST) ou met à jour (PUT) un article selon qu'il a déjà un id.
  /// Renvoie le code HTTP (201 créé, 200 modifié, 409 référence en double...)
  /// pour que l'UI affiche le bon message.
  Future<int> enregistrer(Article article) async {
    final estModification =
        article.id != null; //résultat est toujours un booléen (true ou false).
    final uri = estModification
        ? Uri.parse('$baseUrl/articles/${article.id}')
        : Uri.parse('$baseUrl/articles');
    final headers = {'Content-Type': 'application/json'};
    final corps = jsonEncode(article.toJson());
    final reponse = estModification
        ? await http.put(uri, headers: headers, body: corps)
        : await http.post(uri, headers: headers, body: corps);
    return reponse.statusCode;
  }

  /// DELETE /articles/{id}. Renvoie le code HTTP (204 = supprimé).
  Future<int> supprimer(int id) async {
    final reponse = await http.delete(Uri.parse('$baseUrl/articles/$id'));
    return reponse.statusCode;
  }
}
