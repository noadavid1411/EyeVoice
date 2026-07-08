# 0003 — `mediapipe_face_mesh` pour la détection visage/iris

**Statut** : Accepté, fiabilité en environnement d'émulation **non
concluante** — à revalider sur appareil réel avant mise en production.

## Contexte

Les spécifications imposent l'eye-tracking par caméra frontale uniquement,
sans matériel externe (section 3.2), via détection visage/iris (section
13.2). Il fallait un package Flutter fournissant cette détection, testable
en CI/local sans dépendance de compilation native fragile — contrainte
explicite : détection/mapping/dwell doivent rester testables séparément
(section 13.1).

## Candidats évalués

### `face_detection_tflite` (écarté)

Utilise les mêmes modèles MediaPipe via LiteRT, mais sa dépendance
`opencv_dart`/`dartcv4` s'appuie sur le système expérimental de "native
assets" de Dart (hooks + `native_toolchain_cmake`), qui tente de compiler
une lib native **pour la plateforme hôte** dès `flutter test` — pas
seulement au build mobile.

Impact vérifié sur ce projet : `flutter test` échoue immédiatement pour
**toute la codebase** (pas seulement `eyetracking`) sur toute machine sans
CMake + toolchain C++ installés — confirmé par échec sur le poste de dev
utilisé pour la Phase 1b, faute de CMake/Visual Studio.

Ce risque viole frontalement la contrainte de testabilité indépendante des
couches (section 13.1) : un développeur qui touche uniquement `lib/domain`
ou `lib/ui` se retrouverait bloqué par une dépendance de compilation qu'il
n'utilise pas. Package écarté malgré sa maturité perçue plus grande.

### `mediapipe_face_mesh` (retenu)

Plugin FFI classique : binaires natifs précompilés par plateforme, chargés
via `dart:ffi`/`dlopen` au runtime sur l'appareil, résolution de dépendances
légère (`ffi` + Flutter/test uniquement, pas de hook de compilation côté
hôte — vérifié via `flutter pub get` sur un projet de sondage isolé).
Fournit 468 points de mesh + jusqu'à 478 avec landmarks d'iris
(`enableIris: true`), Android + iOS.

Point d'attention accepté au moment du choix (Phase 1b) : package très
récent au moment de l'audit (publié < 24 h, 9 likes), mais éditeur vérifié
("verified publisher"). Un risque de fraîcheur de package a été jugé
préférable à un risque de dépendance non testable.

## Décision

Utiliser `mediapipe_face_mesh` (voir `pubspec.yaml`, section "Eye-tracking",
pour le raisonnement complet au moment de la décision), derrière
l'interface `FaceGazeDetector` (`lib/eyetracking/detection/face_gaze_detector.dart`)
implémentée par `FaceMeshGazeDetector`
(`lib/eyetracking/detection/face_mesh_gaze_detector.dart`), pour permettre
un remplacement futur sans impact sur le reste du pipeline (mapping, dwell,
qualité de signal) si le choix se révèle intenable.

Le flux caméra est fourni par le package `camera` (fédéré, sans hook de
compilation côté hôte), converti en image NV21 (`FaceMeshNv21Image`) avant
inférence. `AndroidManifest.xml` déclare la permission `CAMERA` (ajoutée
après coup, voir "Limitation connue" ci-dessous).

## Limitation connue (à revalider avant mise en production)

Un test manuel du pipeline réel de bout en bout (webcam PC relayée via le
passthrough caméra de l'émulateur Android) a confirmé que l'architecture
fonctionne : caméra → conversion NV21 → inférence MediaPipe via FFI, sans
exception. En revanche, le score de confiance de détection de visage
(`FaceMeshResult.score`, reporté dans `RawGazeSample.confidence`) est resté
très bas dans ce canal — jamais au-dessus de ~0,03 — quelle que soit la
rotation d'image testée parmi 0°/90°/180°/270° (voir
`_rotationDegreesFor` dans `face_mesh_gaze_detector.dart`).

Aucune détection fiable n'a donc pu être obtenue via ce canal d'émulation.
Hypothèse retenue : limite de qualité/format d'image du passthrough webcam
QEMU (résolution, compression, format de couleur), pas un bug du code
applicatif — l'ensemble de la chaîne de conversion/inférence s'exécute sans
erreur, et le score bas plutôt que nul suggère que le modèle reçoit une
image structurellement valide mais dégradée.

À l'occasion de ce test, une permission `CAMERA` manquante dans
`AndroidManifest.xml` a également été trouvée et corrigée (commit
`7a88a73`) — `FaceMeshGazeDetector` dépend de `package:camera` mais aucune
permission n'avait été déclarée.

**Conséquence pour la suite du projet** : ne pas considérer la fiabilité de
détection comme validée avant un test sur un vrai appareil Android avec
caméra native (pas de passthrough d'émulateur). Le développement UI/domaine
peut continuer en s'appuyant sur `FakeFaceGazeDetector`
(`lib/ui/gaze/fake_face_gaze_detector.dart`, branché par défaut — voir
`lib/main.dart`), qui simule un flux de regard sans dépendre de la caméra.

## Conséquences

- `lib/eyetracking/detection` reste le seul point de couplage à
  `mediapipe_face_mesh`/`camera` dans toute la codebase (section 13.1).
- Avant toute démonstration ou mise en production, un test sur appareil réel
  est un prérequis bloquant, pas une simple vérification de confort.
- Si la fiabilité reste insuffisante même sur appareil réel, le remplacement
  passe uniquement par une nouvelle implémentation de `FaceGazeDetector` —
  aucun autre fichier de `eyetracking`, `domain` ou `ui` n'a à changer.
