class ActivityRecord {
  final String id;
  final DateTime timestamp;
  final List<(double, double)> coordinates; // Latitude, Longitude
  final bool isFuzzed;

  ActivityRecord({
    required this.id,
    required this.timestamp,
    required this.coordinates,
    this.isFuzzed = true,
  });

  // Pour transformer en JSON avant chiffrement
  Map<String, dynamic> toJson() => {
    'id': id,
    'time': timestamp.toIso8601String(),
    'points': coordinates.map((p) => [p.$1, p.$2]).toList(),
  };
}