# La Voix du Regard (EyeVoice)

Application Flutter de communication par eye-tracking, destinée à un
patient hospitalisé (réanimation, intubé/trachéotomisé) conscient mais
incapable de parler. Le patient sélectionne des besoins, phrases et
réponses en fixant du regard des zones de l'écran, via la caméra frontale
de l'appareil — aucun matériel externe, souris ou clavier requis.

Référence fonctionnelle complète : [`SPECIFICATIONS_FONCTIONNELLES.md`](SPECIFICATIONS_FONCTIONNELLES.md).
Suivi d'avancement par phase : [`TASKS.md`](TASKS.md).

## Documentation

- [`docs/adr/`](docs/adr/README.md) — décisions d'architecture (state
  management, structure de dossiers, choix d'eye-tracking).
- [`docs/contracts.md`](docs/contracts.md) — contrats d'interface entre
  couches (`ActionResult`, `GazeState`, schéma `menu-config.json`).
- [`docs/guide-aidant-soignant.md`](docs/guide-aidant-soignant.md) — guide
  de personnalisation non technique pour l'aidant/le soignant (réglages :
  dwell time, sensibilité, contraste, voix...).
- [`docs/deploiement-ios.md`](docs/deploiement-ios.md) — build et options de
  distribution iOS (App Store, TestFlight, Enterprise, MDM) ; l'app n'a
  jamais encore été buildée pour iOS (développement sous Windows).
- [`docs/validation-materielle.md`](docs/validation-materielle.md) — plan
  de validation de l'eye-tracking sur appareil physique réel (Android/iOS),
  à dérouler dès qu'un appareil est disponible.

## Prérequis

- [Flutter SDK](https://docs.flutter.dev/get-started/install), canal
  stable (Dart SDK `^3.12.2` — voir `pubspec.yaml`).
- Pour un build/déploiement Android : Android SDK + un appareil ou
  émulateur Android.
- Pour un build/déploiement iOS : Xcode (macOS uniquement).

Vérifier l'installation :

```bash
flutter doctor
```

## Installation

```bash
flutter pub get
```

## Lancer l'application

```bash
flutter run
```

Par défaut, l'application utilise un détecteur de regard **factice**
(`FakeFaceGazeDetector`) qui simule un flux de regard sans utiliser la
caméra — utile pour développer l'UI/la logique métier sans dépendre du
matériel. Pour activer le vrai pipeline caméra + MediaPipe
(`FaceMeshGazeDetector`) sur un appareil réel :

```bash
flutter run --dart-define=EYEVOICE_USE_REAL_GAZE_DETECTOR=true
```

**Limitation connue** : la fiabilité de la détection réelle n'a été
validée qu'en environnement d'émulation (webcam PC relayée via
passthrough), avec un score de confiance de détection resté très bas — voir
[`docs/adr/0003-mediapipe-face-mesh.md`](docs/adr/0003-mediapipe-face-mesh.md).
Un test sur appareil Android réel avec caméra native est nécessaire avant
toute mise en production.

## Lancer les tests

```bash
flutter test
```

## Structure du dépôt

```text
lib/
  core/          Contrats partagés (ScreenZone, AppDefaults)
  domain/        Moteur de menus, ActionResolver, réglages (AppSettings)
  eyetracking/   Détection regard → GazeState (MediaPipe, dwell time, zones)
  services/      Synthèse vocale (flutter_tts)
  data/          Persistance des réglages (shared_preferences)
  ui/            Écrans, widgets, thème, câblage Riverpod
test/            Tests unitaires et widget, organisés en miroir de lib/
docs/            ADRs, contrats d'interface, guide aidant/soignant
```

Détail des règles de dépendance entre couches :
[`docs/adr/0002-structure-dossiers.md`](docs/adr/0002-structure-dossiers.md).

## Décisions techniques verrouillées

Flutter, Riverpod (state management), MediaPipe via `mediapipe_face_mesh`
(eye-tracking), `flutter_tts` (synthèse vocale), `shared_preferences`
(persistance MVP). Détail et justification dans [`docs/adr/`](docs/adr/README.md).
