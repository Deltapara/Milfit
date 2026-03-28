enum SportType {
  running,
  cycling,
  walking,
  swimming;

  String get label {
    switch (this) {
      case SportType.running: return 'Course à pied';
      case SportType.cycling: return 'Vélo';
      case SportType.walking: return 'Marche / Rando';
      case SportType.swimming: return 'Natation';
    }
  }

  String get emoji {
    switch (this) {
      case SportType.running: return '🏃';
      case SportType.cycling: return '🚴';
      case SportType.walking: return '🥾';
      case SportType.swimming: return '🏊';
    }
  }

  // Vitesse typique en m/s pour estimer l'allure si GPS indisponible
  double get typicalSpeedMs {
    switch (this) {
      case SportType.running: return 3.0;
      case SportType.cycling: return 7.0;
      case SportType.walking: return 1.4;
      case SportType.swimming: return 1.2;
    }
  }
}