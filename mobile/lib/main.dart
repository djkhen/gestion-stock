import 'package:flutter/material.dart';

import 'articles_page.dart';

void main() => runApp(const MonApp());

/// Configuration par ENVIRONNEMENT, lue à la COMPILATION.
///
/// Les valeurs viennent d'un fichier JSON (un par environnement) :
///   DEV  : flutter run        --dart-define-from-file=dart_defines/dev.json
///   PROD : flutter build apk  --dart-define-from-file=dart_defines/prod.json
///
/// Si rien n'est passé, les valeurs par défaut ci-dessous (DEV) s'appliquent.
/// (10.0.2.2 = "localhost" du PC hôte, vu depuis l'émulateur Android.)

/// Nom de l'environnement courant ("dev" ou "prod").
const String appEnv = String.fromEnvironment('ENV', defaultValue: 'dev');

/// URL de base de l'API Quarkus.
const String apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

class MonApp extends StatelessWidget {
  const MonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // ← retire le bandeau DEBUG
      // En prod, titre propre ; en dev, on affiche l'environnement pour
      // repérer d'un coup d'œil qu'on n'est PAS en production.
      title: appEnv == 'prod'
          ? 'Gestion de stock'
          : 'Gestion de stock [${appEnv.toUpperCase()}]',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4F46E5),
        useMaterial3: true,
      ),
      home: const PageArticles(),
    );
  }
}
