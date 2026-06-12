import 'package:flutter/material.dart';

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
      title: 'Gestion de stock',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4F46E5),
        useMaterial3: true,
      ),
      home: const PageArticles(),
    );
  }
}
