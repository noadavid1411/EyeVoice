# Checklist des critères d'acceptation — section 19

Vérification QA de la conformité de "La Voix du Regard" (EyeVoice) aux critères
d'acceptation fonctionnels de `SPECIFICATIONS_FONCTIONNELLES.md`, section 19.
Établie à l'issue des Phases 0 à 3 (commit `7a88a73`), avant la clôture de la
Phase 4 (Qualité & documentation).

Priorité : critères MVP (section 20.1) d'abord ; les critères couvrant des
fonctionnalités explicitement Backlog (section 20.2/20.3, voir `TASKS.md`) sont
étiquetés 🔜 hors périmètre MVP plutôt que ❌.

Légende : ✅ validé · ⚠️ partiel · ❌ non couvert · 🔜 hors périmètre MVP

---

## 1. L'accueil contient exactement 4 zones principales

**✅ Validé.**

`sampleMenuConfig` (`lib/domain/models/sample_menu_config.dart`, écran `home`)
définit exactement 4 items, un par quadrant (`topLeft`/`topRight`/
`bottomLeft`/`bottomRight`), conformes à la table de la section 6.2
(PHYSIQUE/CONVERSATION/ÉMOTIONS/OPTIONS). Vérifié par
`test/widget_test.dart` ("EyeVoiceApp démarre sur l'accueil en 4 quadrants")
et `test/ui/grid4_screen_test.dart` ("affiche les 4 libellés de la grille").

## 2. Aucun écran standard ne dépasse 4 choix

**✅ Validé**, à deux niveaux indépendants :

- Domaine : `validateMenuConfig` (`lib/domain/models/menu_config_validator.dart`)
  rejette tout écran de plus de `AppDefaults.maxChoicesPerScreen` items — testé
  dans `test/domain/menu_config_validator_test.dart` ("rejette un écran de
  plus de 4 choix").
- UI : `Grid4Screen` porte un `assert` équivalent côté widget — testé dans
  `test/ui/grid4_screen_test.dart` ("refuse plus de 4 choix").

Les 7 écrans de `sampleMenuConfig` respectent tous la limite (revue manuelle
du fixture).

## 3. Le bas droite sert toujours à la navigation ou aux options

**⚠️ Partiel.**

Constaté correct par revue manuelle de `sampleMenuConfig` : `home.bottomRight`
→ Options, et les 6 autres écrans ont tous `bottomRight` = `back` ("Retour").
`Grid4Item` distingue bien la zone bas-droite comme zone de navigation dans
son usage courant (voir aussi `test/ui/grid4_screen_test.dart`, fixture
`fourItems` avec `bottomRight` = "Retour").

Cependant, **aucune règle automatisée** n'impose cette contrainte au niveau du
moteur de données : `validateMenuConfig` ne vérifie pas que `bottomRight` est
toujours une action de navigation (`back`/`home`/`settings`/`navigate` vers un
menu de niveau supérieur). Rien n'empêche aujourd'hui un futur
`menu-config.json` de placer une phrase finale en bas-droite, en violation de
la section 4.6. Recommandation transmise à domain-logic-engineer : envisager
une règle de validation dédiée (ou au minimum une convention documentée avec
avertissement, si l'aidant peut personnaliser les menus — section 10.4,
Backlog).

## 4. La zone centrale ne déclenche aucune action

**✅ Validé.**

Trois couches indépendantes garantissent l'invariant :

- `ZoneMapper._mapQuadrant` retourne `ScreenZone.centerDeadZone` pour tout
  point dans le ratio configuré — testé dans `test/eyetracking/zone_mapper_test.dart`.
- `DwellTimeController.update` retourne systématiquement `progress: 0.0` pour
  `ScreenZone.centerDeadZone` — testé dans `test/eyetracking/dwell_time_controller_test.dart`
  ("never progresses while gazing at the center dead zone").
- `DeadZoneMarker` (UI) est un repère purement visuel, non interactif — testé
  dans `test/ui/grid4_screen_test.dart` ("affiche un repère visuel de zone
  morte non interactif par défaut").

## 5. Le dwell time est paramétrable

**✅ Validé.**

- `DwellTimeController.updateDwellTime` change la durée effective à chaud —
  testé (`test/eyetracking/dwell_time_controller_test.dart`).
- `EyeTrackingSettings.dwellTime` est exposé et modifiable via
  `SettingsScreen` (slider 800–2000 ms, `lib/ui/screens/settings_screen.dart`),
  persisté via `SettingsRepository`/`shared_preferences`, et propagé en temps
  réel au `GazeTrackingPipeline` (`gazeTrackingPipelineProvider`). Couverture
  widget : `test/ui/settings_screen_test.dart`.

## 6. Une progression visuelle apparaît pendant une sélection

**✅ Validé.**

`DwellProgressBorder` (bordure lumineuse progressive, `lib/ui/widgets/dwell_progress_border.dart`)
consomme `GazeState.dwellProgress` via `ZoneButton`, utilisé par `Grid4Screen`
et `YesNoScreen`. Le déclenchement de l'action sur front montant à
`progress == 1.0` est testé (`test/ui/grid4_screen_test.dart`,
`test/ui/yes_no_screen_test.dart`). Le rendu visuel intermédiaire
(`CustomPainter`) n'est pas testé pixel par pixel — attendu pour un widget
purement graphique, la logique de progression sous-jacente (`DwellTimeController`)
est elle testée numériquement de façon exhaustive.

## 7. Une phrase validée est prononcée à voix haute

**✅ Validé.**

`MenuNavigationController._resolveAndApply` appelle `TtsService.speak` pour
toute `SpeakAction`, ainsi que pour les réponses fixes `answerYes`/`answerNo`
du mode Oui/Non. Testé de bout en bout (JSON → `ActionResolver` → TTS) dans
`test/ui/menu_navigation_controller_test.dart` (groupe "TTS réel branché sur
l'action speak") et unitairement dans `test/services/tts_service_test.dart`.

## 8. Les menus sont chargés depuis un fichier de données

**⚠️ Partiel — lacune réelle à signaler à software-architect / domain-logic-engineer.**

Le moteur de parsing/validation JSON est complet et testé
(`MenuConfig.fromJson`, `validateMenuConfig`, `loadMenuConfig` —
`test/domain/menu_config_validator_test.dart`) : la structure JSON de la
section 11.2 est correctement interprétée et validée.

**Mais l'application ne charge aujourd'hui aucun fichier `menu-config.json`
réel au runtime.** `MenuNavigationController.build()`
(`lib/ui/providers/menu_navigation_controller.dart`) instancie directement
`sampleMenuConfig`, un fixture Dart en mémoire (`lib/domain/models/sample_menu_config.dart`).
Aucun asset JSON n'existe dans le dépôt, `pubspec.yaml` ne déclare aucune
section `assets:`, et aucun code de chargement (`rootBundle.loadString` ou
équivalent) n'a été trouvé dans `lib/`. Le contenu des menus reste donc, en
pratique, codé dans les composants Dart plutôt que chargé depuis un fichier
séparé (contrairement à la section 11.1). Ce point était déjà noté comme hors
périmètre par domain-logic-engineer dans le code (commentaire explicite sur
`MenuNavigationController.build`) mais n'a pas de tâche dédiée dans
`TASKS.md` Phase 4 — à ajouter/clarifier avant de considérer le MVP complet,
car c'est un critère d'acceptation explicite (section 19) et une exigence
d'architecture (section 11.1).

## 9. Le mode Oui/Non fonctionne avec 2 zones simples

**✅ Validé.**

`YesNoScreen` (`lib/ui/screens/yes_no_screen.dart`) : 2 zones (`left`/`right`),
OUI vert/NON rouge, texte très grand (`AppTextStyles.yesNoLabel`, 56px),
accessible tactilement et par dwell time. Couvert par
`test/ui/yes_no_screen_test.dart` (affichage, tap, dwell 1.0, absence
d'éléments distrayants sans `onExit`) et `test/eyetracking/zone_mapper_test.dart`
(mapping gauche/droite, absence de zone morte en mode Oui/Non — cohérent avec
la section 5.2 qui ne prévoit pas de zone morte pour ce mode).

## 10. Le mode expert permet une saisie libre minimale

**🔜 Hors périmètre MVP.**

Le mode expert (saisie par balayage temporel + prédiction de mots, section 8)
est explicitement listé en Backlog dans `TASKS.md` ("Mode expert par balayage
temporel + prédiction de mots") et absent de la liste MVP obligatoire
(section 20.1, qui ne mentionne que le mode Oui/Non parmi les modes de
sélection). L'état actuel du code reflète cela honnêtement : l'item "Mode
expert" déclenche un `ComingSoonEvent` ("bientôt disponible") plutôt qu'un
écran fonctionnel — testé dans `test/ui/menu_navigation_controller_test.dart`
("openMode(expert) reste sur l'écran courant et signale 'bientôt
disponible'"). Aucune action requise côté QA avant la Phase Backlog.

## 11. L'interface reste lisible en environnement sombre ou hospitalier

**✅ Validé** (avec réserve mineure).

- Thème : fond noir/gris très foncé (`AppColors.background`/`backgroundStandard`),
  texte blanc (`textPrimary`) ou jaune clair (`textAccent`), couleurs
  sémantiques vert/rouge pour Oui/Non, bleu-gris pour la navigation — conforme
  point par point à la section 15.3 (`lib/ui/theme/app_colors.dart`).
- Typographie : tailles bien au-dessus des standards Material (34px libellés
  de zone, 56px OUI/NON, 40px phrase prononcée — `lib/ui/theme/app_text_styles.dart`),
  cohérent avec "police très grande" (section 15.1) et "visible à distance"
  (section 15.2).
- Réglage utilisateur du contraste et de la taille de police via
  `SettingsScreen`, câblé sur `AppTheme.themeFor` et `MediaQuery.textScaler`
  (`lib/main.dart`).
- Validation manuelle sur émulateur Android réelle confirmée par le contexte
  projet (navigation, TTS, confirmation, mode dégradé, réglages fonctionnels).

Réserve : aucun test automatisé ne calcule un ratio de contraste WCAG
(vérification purement visuelle/déclarative sur les valeurs de couleur) — un
test de ce type serait un ajout possible mais à faible valeur ajoutée vu que
les couleurs sont contrôlées de façon centralisée dans `AppColors`.

## 12. L'application peut être utilisée sans clavier, souris ou matériel externe

**✅ Validé pour l'interaction** ; **⚠️ partiel pour la fiabilité eye-tracking réelle.**

- Aucune dépendance à un clavier, une souris ou un périphérique externe dans
  le code : sélection par regard (caméra frontale, `mediapipe_face_mesh`) ou
  par appui tactile (mode dégradé, `ZoneButton.onTap`), les deux chemins
  étant testés indépendamment (`test/eyetracking/*`, `test/ui/grid4_screen_test.dart`
  "un appui tactile sur une zone déclenche onActivated (mode dégradé)").
- Le pipeline eye-tracking bout-en-bout a été testé manuellement (caméra →
  conversion NV21 → inférence MediaPipe) sans exception, ce qui valide
  l'architecture. **Mais la détection de visage reste peu fiable sur
  l'environnement de test disponible** (passthrough webcam QEMU sous
  émulateur Android — score de confiance très bas quelle que soit la
  rotation testée). Le contexte projet indique que cette limite est
  probablement propre à l'émulation et non au code (`FaceMeshGazeDetector`,
  `GazeTrackingPipeline`), mais **aucun test n'a encore été fait sur un
  appareil physique réel** avec une vraie caméra. Ce point doit rester ouvert
  tant qu'un test sur matériel réel n'a pas été effectué — c'est le risque
  patient le plus élevé de ce projet (une détection peu fiable peut produire
  des non-détections répétées, ce qui est cependant couvert côté sécurité par
  `SignalQualityMonitor`/mode dégradé, voir section sécurité ci-dessous).

---

## Points de sécurité d'usage complémentaires (section 17, transverse aux critères ci-dessus)

- **17.1 (validations accidentelles) — ✅ validé.** `DwellTimeController`
  réinitialise la progression sur tout changement de zone, perte de zone
  (`null`) ou entrée en zone morte — testé de façon exhaustive
  (`test/eyetracking/dwell_time_controller_test.dart`). L'instabilité
  (alternance rapide de zones) est gérée par `SignalQualityMonitor`
  (`lib/eyetracking/signal/signal_quality_monitor.dart`), qui **n'avait
  aucun test avant cet audit QA** — lacune comblée par
  `test/eyetracking/signal_quality_monitor_test.dart` (11 nouveaux tests :
  perte de visage immédiate/progressive, retour à `ok`, instabilité de zone
  au-delà du seuil configuré, purge de la fenêtre glissante, `reset()`,
  `updateSettings()` à chaud).
- **17.2 (confirmation des actions sensibles) — ✅ validé** pour le seul cas
  actuellement implémenté ("Changer de position", "Réinitialiser les
  réglages") : `MenuItem.requiresConfirmation` empêche tout appel à
  `ActionResolver.resolve` avant confirmation explicite, testé de bout en
  bout dans `test/ui/menu_navigation_controller_test.dart` (groupe
  "confirmation des actions sensibles") et `test/ui/settings_screen_test.dart`.
  Note : "quitter l'application" (exemple cité section 17.2) n'a pas
  d'action `cancel`/`quit` implémentée avec confirmation dans
  `sampleMenuConfig` à ce stade — à surveiller si une action de sortie est
  ajoutée plus tard.
- **17.3 (mode dégradé) — ✅ validé.** `DegradedSignalBanner` s'affiche dès
  que `GazeState.signalStatus` vaut `degraded`/`lost` ; la sélection tactile
  fonctionne nativement et indépendamment de l'état du signal (testé dans
  `test/ui/grid4_screen_test.dart` et `test/ui/yes_no_screen_test.dart`).

---

## Résumé

| # | Critère | Statut |
|---|---|---|
| 1 | Accueil = 4 zones | ✅ |
| 2 | Max 4 choix par écran | ✅ |
| 3 | Bas-droite = navigation | ⚠️ (pas de règle automatisée, conforme en pratique) |
| 4 | Zone morte inerte | ✅ |
| 5 | Dwell time paramétrable | ✅ |
| 6 | Progression visuelle | ✅ |
| 7 | Synthèse vocale | ✅ |
| 8 | Menus depuis un fichier de données | ⚠️ (moteur JSON testé, mais chargement runtime non branché — fixture Dart utilisée à la place) |
| 9 | Mode Oui/Non | ✅ |
| 10 | Mode expert | 🔜 Backlog (comportement "bientôt disponible" conforme à l'état attendu) |
| 11 | Lisibilité hospitalière | ✅ |
| 12 | Sans clavier/souris/matériel externe | ✅ interaction / ⚠️ fiabilité eye-tracking sur matériel réel non testée |

**Verdict global MVP (section 20.1) : globalement conforme**, avec deux
réserves à traiter avant de clore formellement la Phase 4/MVP : (a) le
chargement effectif de `menu-config.json` depuis un fichier (critère 8), et
(b) une validation sur appareil physique réel de la fiabilité de détection du
regard (critère 12), le test sur émulateur ayant révélé une limite
probablement liée au passthrough webcam plutôt qu'au code. Aucun de ces deux
points n'est un problème de sécurité active (le mode dégradé couvre le cas
d'échec de l'eye-tracking), mais tous deux conditionnent la complétude
réelle du MVP tel que défini section 20.1 point 8 ("configuration JSON
simple").
