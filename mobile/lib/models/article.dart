/// Modèle Article — miroir de l'entité Quarkus du même nom.
///
/// Ne contient QUE la donnée et sa (dé)sérialisation JSON.
/// Aucun appel réseau ici : c'est le rôle de ArticleService.
class Article {
  final int? id;
  final String reference;
  final String designation;
  final String description;
  final String unite;
  final int quantiteStock;
  final int seuilAlerte;
  final double prixUnitaire;

  Article({
    this.id,
    required this.reference,
    required this.designation,
    required this.description,
    required this.unite,
    required this.quantiteStock,
    required this.seuilAlerte,
    required this.prixUnitaire,
  });

  /// Vrai si le stock est au niveau d'alerte ou en dessous (rupture imminente).
  bool get enAlerte => quantiteStock <= seuilAlerte;

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id'],
        reference: json['reference'] ?? '',
        designation: json['designation'] ?? '',
        description: json['description'] ?? '',
        unite: json['unite'] ?? 'piece',
        quantiteStock: (json['quantiteStock'] ?? 0) as int,
        seuilAlerte: (json['seuilAlerte'] ?? 0) as int,
        prixUnitaire: (json['prixUnitaire'] ?? 0).toDouble(),
      );

  /// On n'envoie pas l'id : le backend le génère à la création.
  Map<String, dynamic> toJson() => {
        'reference': reference,
        'designation': designation,
        'description': description,
        'unite': unite,
        'quantiteStock': quantiteStock,
        'seuilAlerte': seuilAlerte,
        'prixUnitaire': prixUnitaire,
      };
}
