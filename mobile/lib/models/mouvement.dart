class Mouvement {
  final int id;

  final String type;

  final int quantite;

  final DateTime date;

  final String motif;

  Mouvement(
      {required this.id,
      required this.type,
      required this.quantite,
      required this.date,
      required this.motif});

  factory Mouvement.fromJson(json) => Mouvement(
        id: json['id'],
        type: json['type'] ?? '',
        quantite: json['quantite'] ?? 0,
        date: DateTime.parse(json['date']),
        motif: json['motif'] ?? '',
      );
}
