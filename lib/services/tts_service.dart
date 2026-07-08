import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_settings.dart';

/// Seam d'abstraction autour de `package:flutter_tts`.
///
/// `FlutterTts` (la classe du plugin) n'est pas une interface : l'exposer
/// directement à [TtsService] forcerait tout test unitaire à passer par le
/// vrai `MethodChannel` de la plateforme. [TtsEngine] isole la poignée
/// d'appels réellement utilisés (section 14.3 : voix, vitesse, volume,
/// lecture, arrêt) pour permettre une fausse implémentation en test — voir
/// `test/services/tts_service_test.dart`.
abstract class TtsEngine {
  Future<void> setLanguage(String language);
  Future<void> setSpeechRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> setPitch(double pitch);
  Future<void> setVoice(String name, String locale);
  Future<void> speak(String text);
  Future<void> stop();
}

/// Implémentation réelle de [TtsEngine], adossée à `package:flutter_tts`.
class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine([FlutterTts? flutterTts]) : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;

  @override
  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume);
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  @override
  Future<void> setVoice(String name, String locale) async {
    await _flutterTts.setVoice({'name': name, 'locale': locale});
  }

  @override
  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}

/// Service de synthèse vocale (section 14 des spécifications).
///
/// Consommé par la couche `ui` pour exécuter un [SpeakAction] résolu par
/// l'`ActionResolver` (`lib/domain/actions/action_result.dart`) :
/// `ttsService.speak(action.text)`. `TtsService` ne connaît rien du moteur
/// de menus ni de la pile de navigation — il ne fait que prononcer du texte
/// et appliquer les réglages de voix (14.3).
///
/// Toute phrase transmise à [speak] est mémorisée comme dernière phrase
/// prononcée ([lastSpokenText]), même si le son est temporairement coupé
/// ([TtsSettings.muted]) : cela permet à [repeatLast] de fonctionner dès que
/// le son est réactivé, conformément à "répétition de la dernière phrase"
/// (14.3).
class TtsService {
  TtsService({TtsEngine? engine, TtsSettings initialSettings = const TtsSettings()})
      : _engine = engine ?? FlutterTtsEngine(),
        _settings = initialSettings;

  final TtsEngine _engine;
  TtsSettings _settings;
  String? _lastSpokenText;
  bool _engineConfigured = false;

  /// Réglages de voix actuellement appliqués.
  TtsSettings get settings => _settings;

  /// Dernière phrase transmise à [speak] ou [repeatLast], `null` si aucune
  /// phrase n'a encore été prononcée depuis la création du service.
  String? get lastSpokenText => _lastSpokenText;

  Future<void> _applyEngineSettings() async {
    await _engine.setLanguage(_settings.language);
    await _engine.setSpeechRate(_settings.speechRate);
    await _engine.setVolume(_settings.volume);
    await _engine.setPitch(_settings.pitch);
    final voiceName = _settings.voiceName;
    if (voiceName != null) {
      await _engine.setVoice(voiceName, _settings.language);
    }
    _engineConfigured = true;
  }

  /// Remplace les réglages de voix (langue, vitesse, volume, hauteur, voix,
  /// coupure temporaire du son) et les applique immédiatement au moteur TTS.
  ///
  /// Ne persiste rien : la persistance (`shared_preferences`) et l'écran de
  /// réglages associé sont prévus en Phase 3.
  Future<void> updateSettings(TtsSettings settings) async {
    _settings = settings;
    _engineConfigured = false;
    await _applyEngineSettings();
  }

  /// Bascule uniquement la désactivation temporaire du son (14.3), sans
  /// toucher aux autres réglages ni réappliquer voix/vitesse/volume au
  /// moteur (pas nécessaire : [speak] vérifie [TtsSettings.muted] avant
  /// d'émettre du son).
  void setMuted(bool muted) {
    _settings = _settings.copyWith(muted: muted);
  }

  /// Prononce [text] (action `speak`, section 14.2). Toute phrase finale
  /// validée doit passer par cette méthode (14.1), sauf si le son est
  /// temporairement désactivé — dans ce cas la phrase est tout de même
  /// mémorisée comme [lastSpokenText] mais aucun son n'est émis.
  ///
  /// Ignore silencieusement un texte vide (rien à prononcer).
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!_engineConfigured) {
      await _applyEngineSettings();
    }
    _lastSpokenText = text;
    if (_settings.muted) return;
    await _engine.stop();
    await _engine.speak(text);
  }

  /// Reprononce [lastSpokenText] (14.3 : "répétition de la dernière
  /// phrase"). Ne fait rien si aucune phrase n'a encore été prononcée.
  Future<void> repeatLast() async {
    final text = _lastSpokenText;
    if (text == null) return;
    if (!_engineConfigured) {
      await _applyEngineSettings();
    }
    if (_settings.muted) return;
    await _engine.stop();
    await _engine.speak(text);
  }

  /// Interrompt immédiatement la lecture en cours.
  Future<void> stop() => _engine.stop();
}

/// Instance partagée de [TtsService] pour toute l'application.
///
/// Un `Provider` simple (pas `autoDispose`) : le service doit survivre pour
/// toute la durée de vie de l'app, au même titre que le pipeline
/// eye-tracking. La couche `ui` résout un [SpeakAction] en appelant
/// `ref.read(ttsServiceProvider).speak(action.text)`.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.stop);
  return service;
});
