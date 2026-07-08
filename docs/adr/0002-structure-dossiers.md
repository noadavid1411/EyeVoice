# 0002 — Structure de dossiers en couches

**Statut** : Accepté (Phase 0, verrouillé dans `TASKS.md`)

## Contexte

Les spécifications fonctionnelles imposent une séparation stricte entre
trois préoccupations (section 13.1) : la détection brute du regard, la
logique de menus/actions, et l'interface. Le projet est développé par
plusieurs agents spécialisés en parallèle (eye-tracking, logique métier, UI),
chacun devant pouvoir travailler et tester sa couche sans dépendre de
l'implémentation des autres.

## Décision

Structure de dossiers sous `lib/` :

| Dossier | Rôle | Dépend de |
|---|---|---|
| `lib/core` | Contrats partagés entre couches (`ScreenZone`, `AppDefaults`) | rien |
| `lib/domain` | Moteur de menus : modèles `menu-config.json`, validateur, `ActionResolver`, `NavigationHistory`, `AppSettings` | `core` |
| `lib/eyetracking` | Détection regard → `GazeState` : détection MediaPipe, calibration, mapping zones/zone morte, dwell time, qualité de signal | `core` |
| `lib/services` | Intégrations de moteurs externes autres que le stockage (TTS via `flutter_tts`) | `core`, `domain` (types) |
| `lib/data` | Persistance locale (`SettingsRepository` sur `shared_preferences`) | `domain` (modèles) |
| `lib/ui` | Écrans, widgets, thème, câblage Riverpod | toutes les couches ci-dessus |

Règle de dépendance : les flèches ne remontent jamais. `domain` et
`eyetracking` ne s'importent jamais l'un l'autre — leur seul point de
contact est `core/models/screen_zone.dart` (`ScreenZone`), volontairement
placé dans `core` pour cette raison (voir sa documentation). `ui` est la
seule couche autorisée à connaître toutes les autres.

Sous-dossiers `models`/`actions` (`domain`), `models`/`detection`/`mapping`/
`dwell`/`signal`/`calibration` (`eyetracking`), `screens`/`widgets`/`theme`/
`providers`/`demo`/`gaze` (`ui`) : introduits au fil des phases pour garder
chaque dossier de premier niveau lisible (moins d'une quinzaine de fichiers),
pas figés à l'avance.

## Conséquences

- Un test de `domain` ou `eyetracking` ne nécessite jamais Flutter/`camera`/
  `mediapipe_face_mesh` — évite la panne constatée avec le candidat
  `face_detection_tflite` (voir ADR 0003), où une dépendance native cassait
  `flutter test` pour toute la codebase.
- Le remplacement du framework d'eye-tracking (ex. si `mediapipe_face_mesh`
  devient un problème de maintenance) reste isolé à
  `lib/eyetracking/detection/` (interface `FaceGazeDetector`) sans toucher
  au reste de `eyetracking`, `domain`, ou `ui`.
- `lib/services` a été distingué de `lib/data` bien que les deux fassent de
  l'I/O : `data` est réservé au stockage de données (`shared_preferences`),
  `services` aux moteurs externes qui ne stockent rien (TTS). Distinction
  documentée sur `SettingsRepository` pour éviter qu'un futur ajout ne les
  confonde.
