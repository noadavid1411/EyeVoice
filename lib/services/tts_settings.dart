/// Réglages de synthèse vocale (section 14.3 des spécifications
/// fonctionnelles) : voix (langue/locale), vitesse, volume, et
/// désactivation temporaire du son.
///
/// Volontairement minimal pour la Phase 2 : cette classe ne fait que
/// transporter des valeurs de réglage jusqu'à [TtsService]. La persistance
/// via `shared_preferences` et l'écran de réglages associé sont hors
/// périmètre ici — prévus en Phase 3 ("Réglages configurables : dwell time,
/// sensibilité, contraste, voix"). Le champ [muted] couvre déjà
/// l'"activation / désactivation temporaire du son" listée en 14.3, car
/// c'est le seul réglage dont [TtsService] a besoin en interne dès le MVP
/// (action `speak`, section 14.2).
///
/// [voiceName] correspond au champ `name` attendu par
/// `FlutterTts.setVoice({"name": ..., "locale": ...})` ; laissé à `null`
/// tant qu'aucune voix spécifique n'est sélectionnée (l'engin TTS utilise
/// alors la voix par défaut de la plateforme pour [language]).
final class TtsSettings {
  /// Langue/locale IETF (ex. `fr-FR`), transmise à `FlutterTts.setLanguage`.
  final String language;

  /// Vitesse de lecture, échelle `flutter_tts` (0.0 très lent — 1.0 très
  /// rapide selon la plateforme). Défaut choisi volontairement modéré pour
  /// rester intelligible en contexte hospitalier.
  final double speechRate;

  /// Volume, de 0.0 (muet) à 1.0 (maximum).
  final double volume;

  /// Hauteur de la voix, de 0.5 à 2.0 (1.0 = hauteur naturelle).
  final double pitch;

  /// Nom de la voix optionnel (`FlutterTts.setVoice`). `null` = voix par
  /// défaut de la plateforme pour [language].
  final String? voiceName;

  /// Désactivation temporaire du son (section 14.3). Quand `true`,
  /// [TtsService.speak] n'émet aucun son mais mémorise tout de même la
  /// dernière phrase pour une éventuelle répétition ultérieure.
  final bool muted;

  const TtsSettings({
    this.language = 'fr-FR',
    this.speechRate = 0.45,
    this.volume = 1.0,
    this.pitch = 1.0,
    this.voiceName,
    this.muted = false,
  });

  TtsSettings copyWith({
    String? language,
    double? speechRate,
    double? volume,
    double? pitch,
    String? voiceName,
    bool clearVoiceName = false,
    bool? muted,
  }) {
    return TtsSettings(
      language: language ?? this.language,
      speechRate: speechRate ?? this.speechRate,
      volume: volume ?? this.volume,
      pitch: pitch ?? this.pitch,
      voiceName: clearVoiceName ? null : (voiceName ?? this.voiceName),
      muted: muted ?? this.muted,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TtsSettings &&
      other.language == language &&
      other.speechRate == speechRate &&
      other.volume == volume &&
      other.pitch == pitch &&
      other.voiceName == voiceName &&
      other.muted == muted;

  @override
  int get hashCode =>
      Object.hash(language, speechRate, volume, pitch, voiceName, muted);

  @override
  String toString() =>
      'TtsSettings(language: $language, speechRate: $speechRate, '
      'volume: $volume, pitch: $pitch, voiceName: $voiceName, '
      'muted: $muted)';
}
