# Plan de validation matérielle — eye-tracking

Ce document définit comment valider la fiabilité réelle de l'eye-tracking
(`FaceMeshGazeDetector`, `lib/eyetracking/detection/face_mesh_gaze_detector.dart`)
dès qu'un appareil physique (tablette Android ou iPad) est disponible. Il
complète `docs/adr/0003-mediapipe-face-mesh.md` (contexte technique du choix
`mediapipe_face_mesh`) et le critère 12 de `ACCEPTANCE_CHECKLIST.md`
(risque patient identifié comme le plus élevé du projet).

**Ce document ne couvre pas** la distribution/le build iOS — voir
`docs/deploiement-ios.md` pour ce sujet.

## Pourquoi ce test est encore à faire

Le seul test de bout en bout effectué à ce jour utilise une webcam PC
relayée via le passthrough caméra d'un émulateur Android (QEMU). Résultat :
l'architecture fonctionne sans exception (caméra → conversion NV21 →
inférence MediaPipe), mais le score de confiance de détection de visage
(`FaceMeshResult.score`, reporté dans `RawGazeSample.confidence`) est resté
très bas — jamais au-dessus de ~0,03 — quelle que soit la rotation d'image
testée (0°/90°/180°/270°). Hypothèse retenue par `eye-tracking-engineer` :
limite de qualité/format d'image du passthrough webcam QEMU, pas un bug du
code applicatif (le score bas plutôt que nul suggère une image
structurellement valide mais dégradée).

Cette hypothèse **n'a jamais été vérifiée sur une vraie caméra embarquée**
(Android ou iOS). Tant qu'un test sur appareil physique réel n'a pas été
fait, la fiabilité de détection reste une inconnue, pas une confirmation.

---

## Étape 0 — Prérequis avant de commencer

1. **Appareil physique avec caméra frontale fonctionnelle** — tablette
   Android ou iPad. Un simulateur/émulateur ne convient pas ici : ni le
   simulateur iOS (aucun flux caméra réel) ni un émulateur Android sans
   passthrough correctement configuré ne permettent de tester la vraie
   chaîne caméra → MediaPipe.
2. **Activer le vrai détecteur**, désactivé par défaut au profit du
   détecteur factice (`FakeFaceGazeDetector`) :

   ```bash
   flutter run --dart-define=EYEVOICE_USE_REAL_GAZE_DETECTOR=true
   ```

   Voir `lib/main.dart` (`_useRealGazeDetector`) — sans ce flag, l'app
   tourne avec un flux de regard simulé et ne dit rien sur la caméra réelle.
3. **Accorder la permission caméra** au premier lancement (Android :
   `AndroidManifest.xml` déclare déjà `CAMERA` ; iOS :
   `NSCameraUsageDescription` déjà présent dans `Info.plist`, voir
   `docs/deploiement-ios.md` section 3).
4. **Aucun outil de mesure du score de confiance n'existe aujourd'hui dans
   l'UI** (pas d'overlay de debug affichant `confidence`/`zone` en direct).
   Deux options pour l'observer concrètement :
   - Ajout temporaire d'un `debugPrint` dans
     `GazeTrackingPipeline`/`FaceMeshGazeDetector` (ou tout autre point du
     pipeline) pour journaliser `RawGazeSample.confidence` et `faceDetected`
     à chaque frame, retiré après le test — solution la plus rapide.
   - Observation indirecte via `DegradedSignalBanner`
     (`lib/ui/widgets/degraded_signal_banner.dart`) : la bannière
     apparaît dès que `GazeSignalStatus` passe à `degraded`/`lost`, ce qui
     donne un signal qualitatif (mais pas le score chiffré) sans toucher au
     code.
   Recommandation : privilégier la première option pour l'étape 1
   ci-dessous, qui a besoin d'un chiffre, pas juste d'un état binaire.

---

## Étape 1 — Le détecteur retrouve-t-il un visage avec un score exploitable ?

**Première question à trancher, avant tout réglage applicatif.** Sans
réponse positive à cette étape, ajuster la sensibilité ou la zone morte est
prématuré — le problème serait en amont (détection brute), pas dans le
mapping regard → écran.

Protocole :

1. Lancer l'app avec le vrai détecteur (étape 0), face à l'appareil, dans
   des conditions d'éclairage normales (pièce éclairée, pas de contre-jour
   fort).
2. Observer `RawGazeSample.confidence` sur plusieurs dizaines de frames
   consécutives, visage immobile puis en mouvement léger.
3. Comparer au score obtenu sur le canal d'émulation (~0,03, jamais
   exploitable) :
   - **Score nettement supérieur** (ordre de grandeur à définir
     empiriquement, mais significativement différent de 0,03 — ex. un
     score qui varie de façon cohérente avec la présence/absence du visage
     plutôt que de rester plat) → confirme l'hypothèse "limite du
     passthrough QEMU" : la détection brute fonctionne, on peut passer à
     l'étape 2.
   - **Score toujours proche de 0** → l'hypothèse ADR 0003 ne tient pas.
     Le problème est plus profond que l'environnement de test (ex. bug
     dans `_toNv21`/`_rotationDegreesFor`, incompatibilité de format
     d'image sur l'appareil testé, ou limite du modèle MediaPipe
     lui-même). Remonter le résultat à `eye-tracking-engineer` avant toute
     autre étape — ne pas essayer de compenser un score de détection nul
     par des réglages de sensibilité/dwell, ils n'agissent qu'en aval
     d'une détection déjà correcte.
4. Sur iOS spécifiquement, vérifier en plus le point signalé dans
   `docs/deploiement-ios.md` section 3 : l'approximation de conversion
   couleur (`_toNv21`, ordre CbCr réutilisé tel quel comme "VU") pourrait
   affecter la qualité de détection sans que ce soit visible sur Android —
   comparer les deux plateformes si les deux sont disponibles plutôt que
   de généraliser un résultat obtenu sur une seule d'entre elles.

---

## Étape 2 — Ajuster les réglages si la détection est peu fiable

Une fois un score de détection exploitable confirmé (étape 1), mais si le
comportement en usage reste peu fiable (sélections manquées, déclenchements
non voulus, dwell qui n'arrive jamais à progresser), ajuster dans cet ordre
— du réglage le plus direct au plus global :

1. **Sensibilité eye-tracking** (`GazeSensitivity`,
   `lib/eyetracking/models/gaze_sensitivity.dart`, réglable dans
   `SettingsScreen`, section "Regard" du guide aidant/soignant) — gain
   appliqué au vecteur de regard brut avant projection écran (0.7 / 1.0 /
   1.35). Si le patient/testeur a du mal à atteindre les coins de l'écran,
   augmenter (`high`) ; si la sélection "saute" entre zones de façon
   erratique, réduire (`low`).
2. **Zone morte centrale** (`centerDeadZoneRatio`,
   `EyeTrackingSettings`, 15 à 25 % — `AppDefaults.centerDeadZoneMinRatio`/
   `MaxRatio`) — élargir si le regard déclenche des zones par erreur en
   passant par le centre ; réduire si l'espace utile des 4 cases devient
   trop petit.
3. **Temps de fixation (dwell time)** (`EyeTrackingSettings.dwellTime`,
   800–2000 ms, défaut 1300 ms) — augmenter en dernier recours si les deux
   réglages précédents ne suffisent pas à éviter les validations
   accidentelles ; c'est le réglage le plus "coûteux" en confort d'usage
   (rallonge chaque sélection), à ajuster après les deux premiers plutôt
   qu'en premier réflexe.
4. **Seuils de dégradation de signal**
   (`faceLostThreshold`, `instabilityWindow`,
   `instabilityZoneChangeThreshold` — `EyeTrackingSettings`,
   `lib/eyetracking/signal/signal_quality_monitor.dart`) — ne sont **pas**
   exposés dans `SettingsScreen` aujourd'hui (réglages internes, valeurs
   par défaut codées). Si la bannière de mode dégradé apparaît trop
   souvent/trop rarement par rapport au ressenti terrain, le signaler à
   `eye-tracking-engineer` plutôt que de les considérer comme un réglage
   utilisateur — leur exposition éventuelle dans les Réglages serait un
   changement de contrat (`docs/contracts.md`) à documenter séparément.

Chaque changement de réglage doit être testé isolément (un seul paramètre à
la fois) pour rester capable d'attribuer une amélioration/dégradation à la
bonne cause.

---

## Étape 3 — Critères pour considérer l'eye-tracking "validé" pour un usage patient réel

Aucun de ces critères n'est actuellement mesuré automatiquement — ils sont à
vérifier manuellement, en conditions représentatives (appareil monté comme
prévu en chambre, distance et angle réalistes), avant d'envisager un usage
avec un vrai patient :

| Critère | Seuil proposé | Pourquoi |
|---|---|---|
| Score de confiance en conditions normales | Stable et significativement au-dessus du plancher observé en émulation (~0,03) sur au moins plusieurs dizaines de frames consécutives, visage immobile | Condition de base : sans ça, rien en aval n'est fiable (voir étape 1) |
| Stabilité du dwell sur plusieurs essais | Sur 10 tentatives de sélection d'une même zone (regard volontaire, dwell time par défaut 1300 ms), au moins 8 déclenchements réussis sans redémarrage de la progression en cours de route | Mesure directement l'expérience patient : un dwell qui se réinitialise sans raison est plus frustrant qu'un simple délai |
| Taux de faux déclenchements | Sur 2 minutes d'observation du visage en mouvement naturel (regard qui parcourt l'écran sans intention de sélection, clignements normaux), aucune activation accidentelle d'une zone | Directement lié à la section 17.1 des spécifications ("éviter les validations accidentelles") — un faux déclenchement en usage réel peut déclencher une phrase ou une action non voulue |
| Comportement en perte de signal | La bannière de mode dégradé (`DegradedSignalBanner`) apparaît en cas de perte réelle du visage (patient qui détourne la tête, éclairage qui change) et la sélection tactile de secours reste utilisable sans redémarrer l'app | Déjà couvert côté code (`SignalQualityMonitor`, testé unitairement) — ce critère vérifie que le comportement observé correspond au comportement codé, sur du vrai matériel |
| Reproductibilité entre sessions | Les résultats ci-dessus tiennent sur au moins deux sessions de test à des moments différents (pas seulement un essai ponctuel qui a bien tourné) | Écarte un résultat qui serait dû à des conditions d'éclairage/position favorables non représentatives |

**Tant que ces critères ne sont pas tous vérifiés sur au moins un appareil
physique réel (Android et, séparément, iOS si les deux plateformes sont
visées), l'eye-tracking doit être considéré comme non validé pour un usage
avec un patient réel** — cohérent avec la réserve du critère 12 de
`ACCEPTANCE_CHECKLIST.md`. Le mode dégradé tactile reste le filet de
sécurité fonctionnel en attendant cette validation, pas un remplacement à
celle-ci.

## Après validation

Une fois les critères de l'étape 3 atteints sur un appareil donné :

- Mettre à jour le statut de `docs/adr/0003-mediapipe-face-mesh.md`
  (actuellement "fiabilité en environnement d'émulation non concluante — à
  revalider sur appareil réel") pour refléter le résultat obtenu.
- Mettre à jour le critère 12 de `ACCEPTANCE_CHECKLIST.md`.
- Si la validation ne porte que sur une plateforme (ex. Android validé,
  iOS pas encore testé), le documenter explicitement plutôt que de
  généraliser un résultat plateforme à l'autre — les deux détecteurs
  partagent le même code Dart mais pas le même chemin de conversion
  d'image caméra (`_toNv21`, voir `docs/deploiement-ios.md` section 3).
