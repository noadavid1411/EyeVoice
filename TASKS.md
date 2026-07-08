# Suivi des tâches — La Voix du Regard (EyeVoice)

Ce fichier suit l'avancement des tâches définies lors du brainstorm technique, phase par phase. Chaque tâche est cochée une fois validée par le chef de projet.

Décisions techniques verrouillées : Flutter, Riverpod (state management), MediaPipe (eye-tracking), flutter_tts (TTS), shared_preferences (persistance MVP).

## Phase 0 — Fondations (software-architect)

- [x] Structure de dossiers (`lib/core`, `lib/data`, `lib/domain`, `lib/eyetracking`, `lib/ui`, `lib/services`) — ajout de `lib/core/models`, `lib/core/constants`, `lib/domain/actions`, `lib/domain/models`, `lib/eyetracking/models`
- [x] Contrat `ActionResult` (résultat de résolution d'action) — `lib/domain/actions/action_result.dart`
- [x] Contrat `GazeState` (zone, progression dwell, confiance, signal dégradé) — `lib/eyetracking/models/gaze_state.dart` (+ `lib/core/models/screen_zone.dart` partagé)
- [x] `pubspec.yaml` initial (riverpod, flutter_tts, shared_preferences, dépendance MediaPipe) — ajout de `mediapipe_face_mesh` (à revalider par eye-tracking-engineer en Phase 1b)

## Phase 1a — Moteur de données (domain-logic-engineer)

- [x] Modèles Dart typés pour `menu-config.json` — `lib/domain/models/menu_config.dart`, `menu_screen.dart`, `menu_item.dart`, `menu_action.dart`, `menu_config_exception.dart`
- [x] Validateur de schéma (rejette un écran à plus de 4 choix) — `lib/domain/models/menu_config_validator.dart` (`validateMenuConfig`, `loadMenuConfig`)
- [x] `ActionResolver` (navigate/speak/back/home/openMode/settings/cancel) sur données mockées — `lib/domain/actions/action_resolver.dart` (+ fixture `lib/domain/models/sample_menu_config.dart`)
- [x] Historique de navigation (pile back/home) — `lib/domain/actions/navigation_history.dart`

## Phase 1b — Eye-tracking (eye-tracking-engineer)

- [x] Intégration MediaPipe (détection visage/iris, caméra frontale) — `mediapipe_face_mesh` revalidé (voir `pubspec.yaml`), wrapper `lib/eyetracking/detection/face_mesh_gaze_detector.dart` derrière l'interface `FaceGazeDetector`
- [x] Spike calibration (collecte points de référence, mapping regard→écran) — `lib/eyetracking/calibration/calibration_session.dart` (régression linéaire) + `lib/eyetracking/models/calibration_profile.dart`
- [x] Mapping vers zones logiques + zone morte centrale (15-25 %, réglable) — `lib/eyetracking/mapping/zone_mapper.dart` + `lib/eyetracking/models/eyetracking_settings.dart`
- [x] State machine dwell time (défaut 1300 ms, annulation sortie zone/perte visage/instabilité) — `lib/eyetracking/dwell/dwell_time_controller.dart`
- [x] Exposition `GazeState` + signal de dégradation (mode tactile de secours) — `lib/eyetracking/gaze_tracking_pipeline.dart` (orchestrateur) + `lib/eyetracking/signal/signal_quality_monitor.dart`

## Phase 1c — Interface (flutter-ui-engineer)

- [x] Thème sombre haut contraste — `lib/ui/theme/app_colors.dart`, `app_text_styles.dart`, `app_theme.dart` (branché dans `lib/main.dart`)
- [x] Widget `Grid4Screen` générique (données mockées) — `lib/ui/screens/grid4_screen.dart`, données mockées via `lib/domain/models/sample_menu_config.dart` dans `lib/ui/demo/demo_home_screen.dart`
- [x] Indicateur de progression de sélection (consomme `GazeState`) — `lib/ui/widgets/dwell_progress_border.dart` + `lib/ui/widgets/zone_button.dart` (consomment `GazeState.dwellProgress`)
- [x] Écran Oui/Non (2 zones, vert/rouge) — `lib/ui/screens/yes_no_screen.dart`

## Phase 2 — Intégration

- [x] UI branchée sur `ActionResolver` réel (navigation effective) — `lib/ui/providers/menu_navigation_controller.dart` (`MenuNavigationController`/`menuNavigationProvider`), consommé par `lib/ui/demo/demo_home_screen.dart` ; l'aiguillage d'actions local et provisoire a été retiré, tout passe par le vrai `ActionResolver`/`NavigationHistory` du domaine
- [x] UI branchée sur `GazeState` réel (dwell effectif) — `lib/ui/providers/gaze_tracking_providers.dart` (`gazeTrackingPipelineProvider`, `gazeStateProvider`, `screenLayoutModeProvider`) câble le vrai `GazeTrackingPipeline` ; en l'absence de caméra dans cet environnement, `faceGazeDetectorProvider` utilise par défaut `lib/ui/gaze/fake_face_gaze_detector.dart` (`FakeFaceGazeDetector`, simulation sans accès caméra qui alimente le pipeline réel), remplaçable par le vrai `FaceMeshGazeDetector` via `lib/main.dart` (`EYEVOICE_USE_REAL_GAZE_DETECTOR`)
- [x] Service TTS (flutter_tts) branché sur action `speak` — `lib/services/tts_service.dart` (`TtsService`, `TtsEngine`/`FlutterTtsEngine`, `ttsServiceProvider`) + `lib/services/tts_settings.dart` (`TtsSettings`)

## Phase 3 — Complétude MVP

- [x] Confirmation des actions sensibles (quitter, reset, suppression phrase)
      — `MenuItem.requiresConfirmation` (domaine, `lib/domain/models/menu_item.dart`) lu par
      `MenuNavigationController.activate` (`lib/ui/providers/menu_navigation_controller.dart`)
      avant tout appel à `ActionResolver.resolve` : bascule sur `UiMode.confirmation`
      (`pendingConfirmation`), résolu réellement seulement via `confirmPending()` ("Oui") ;
      `cancelPending()` ("Non") n'appelle jamais `resolve`. Dialogue générique
      `ConfirmationDialog` (`lib/ui/widgets/confirmation_dialog.dart`, réutilise
      `YesNoScreen` avec un message en rouge d'alerte), affiché par `DemoHomeScreen`.
      Démonstration concrète : `sample_menu_config.dart` marque l'item "Changer de
      position" (écran `physical`) `requiresConfirmation: true` (ajustement mineur
      documenté sur place — aucun écran n'a de marge pour un 5ᵉ item dédié, règle des 4
      choix déjà atteinte partout) ; `SettingsScreen` câble aussi un bouton "Réinitialiser
      les réglages" dédié derrière la même confirmation (poussée via `Navigator`).
- [x] Mode dégradé tactile/manuel — `DegradedSignalBanner`
      (`lib/ui/widgets/degraded_signal_banner.dart`) affiche une bannière (icône + texte)
      dès que `GazeState.signalStatus` vaut `degraded`/`lost`, intégrée à `Grid4Screen` et
      `YesNoScreen` ; purement visuelle, la sélection tactile (`ZoneButton.onTap`)
      fonctionnait déjà nativement en secours.
- [x] Réglages configurables (dwell time, sensibilité, contraste, voix) — écran
      `SettingsScreen` (`lib/ui/screens/settings_screen.dart`), accessible depuis
      "Options → Réglages"/`UiMode.settings`, consomme `settingsProvider`/
      `SettingsController` (`lib/data/settings_repository.dart`). Câblage à effet réel :
      dwell time/sensibilité/zone morte → `GazeTrackingPipeline.updateSettings` via
      `gazeTrackingPipelineProvider` (`lib/ui/providers/gaze_tracking_providers.dart`) ;
      synthèse vocale (activée/débit) → `TtsService.updateSettings` via
      `MenuNavigationController` ; taille de police/contraste → `AppTheme.themeFor` +
      `MediaQuery.textScaler`, câblés dans `EyeVoiceApp` (`lib/main.dart`). `main()` est
      désormais asynchrone et surcharge `sharedPreferencesProvider` avec une vraie instance
      `SharedPreferences`.

## Phase 4 — Qualité & documentation

- [x] Tests unitaires : parsing/validation JSON, `ActionResolver`, state machine dwell time, mapping zone
      — audit QA (qa-accessibility-engineer) : couverture déjà quasi complète (109 tests hérités des
      Phases 0-3, relus en détail : `ActionResolver`, `menu_config_validator`, `dwell_time_controller`
      couvrent déjà les edge cases sortie de zone/perte de visage/zone morte/navigation back-home
      imbriquée). Une lacune réelle identifiée et comblée : `SignalQualityMonitor`
      (`lib/eyetracking/signal/signal_quality_monitor.dart`, section 17.1 instabilité de zone + section
      17.3 seuil de perte de visage) n'avait aucun test malgré son rôle direct dans la bascule vers le
      mode dégradé. 11 tests ajoutés — `test/eyetracking/signal_quality_monitor_test.dart` (perte de
      visage immédiate/progressive, retour à `ok`, instabilité au-delà du seuil, purge de la fenêtre
      glissante, `reset()`, `updateSettings()` à chaud).
- [x] Tests widget : `Grid4Screen`, écran Oui/Non — couverture existante relue et jugée suffisante (4
      choix max, zone morte non interactive, dwell 1.0 → activation unique, bannière mode dégradé,
      appui tactile de secours) : `test/ui/grid4_screen_test.dart`, `test/ui/yes_no_screen_test.dart`.
      109 tests hérités + 11 nouveaux = 120 tests, tous verts (`flutter test`) ; `flutter analyze` propre
      (mêmes 4 infos préexistantes hors périmètre, cf. `docs/adr` pour contexte).
- [x] Checklist critères d'acceptation (section 19 des spécifications) — `ACCEPTANCE_CHECKLIST.md`
      (racine du projet, qa-accessibility-engineer). Verdict global MVP : conforme avec 2 réserves à
      traiter avant clôture formelle : (a) critère 8 — le chargement runtime d'un vrai `menu-config.json`
      depuis un fichier/asset n'est pas branché (l'app utilise `sampleMenuConfig`, un fixture Dart en
      mémoire ; le moteur de parsing/validation JSON, lui, est complet et testé) — à signaler à
      software-architect/domain-logic-engineer ; (b) critère 12 — fiabilité de détection de visage sur
      matériel réel non encore validée (seul un test émulateur/webcam passthrough peu concluant a été
      fait, cf. contexte Phase 3 et `docs/adr/0003-mediapipe-face-mesh.md`). Réserve mineure
      additionnelle (critère 3) : aucune règle automatisée n'impose que le quadrant bas-droite soit
      toujours une action de navigation — conforme en pratique sur `sampleMenuConfig`, mais non garanti
      par `validateMenuConfig`.
- [x] ADRs des décisions structurantes (Riverpod, structure dossiers, MediaPipe)
      — `docs/adr/0001-riverpod.md`, `docs/adr/0002-structure-dossiers.md`,
      `docs/adr/0003-mediapipe-face-mesh.md` (index : `docs/adr/README.md`) ;
      cette dernière documente aussi le rejet de `face_detection_tflite` et
      la limitation de fiabilité de détection constatée sur émulateur (score
      de confiance ~0.03, à revalider sur appareil réel).
- [x] Documentation des contrats `ActionResult` / `GazeState` / schéma JSON
      — `docs/contracts.md`
- [x] Guide de personnalisation aidant/soignant — `docs/guide-aidant-soignant.md`
      (README.md racine également mis à jour : présentation, prérequis,
      lancement de l'app/des tests, structure du dépôt)

## Backlog (versions suivantes / avancées)

- [ ] Mode expert par balayage temporel + prédiction de mots
- [ ] Personnalisation des phrases/menus dans l'application
- [ ] Profils patients, export/import de configuration, calibration personnalisée
- [ ] Build iOS réel + validation eye-tracking sur appareil physique — guides
      prêts (`docs/deploiement-ios.md`, `docs/validation-materielle.md`),
      exécution bloquée en l'état par l'absence de Mac/appareil physique
