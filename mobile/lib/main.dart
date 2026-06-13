import 'package:flutter/material.dart';

import 'articles_page.dart';

void main() => runApp(const MonApp());

/// Adresse de l'API Quarkus — configurable selon l'ENVIRONNEMENT.
///
/// L'URL est lue à la COMPILATION via `--dart-define=API_URL=...`.
/// Si rien n'est fourni, on prend la valeur de DEV par défaut (ci-dessous).
///
///   DEV (émulateur Android) : flutter run
///       -> utilise la valeur par défaut http://10.0.2.2:8080
///       (10.0.2.2 = "localhost" du PC hôte, vu depuis l'émulateur)
///
///   PROD : flutter build apk --dart-define=API_URL=https://api.mon-domaine.com
///       -> remplace l'URL par celle du vrai serveur déployé
///
/// Autres cibles de DEV (à passer en --dart-define si besoin) :
///   - Simulateur iOS : http://localhost:8080
///   - Téléphone réel : http://<IP_LOCALE_DU_PC>:8080
const String apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

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
