# 0001 — Riverpod comme solution de state management

**Statut** : Accepté (Phase 0, verrouillé dans `TASKS.md`)

## Contexte

L'application a besoin de partager plusieurs flux d'état entre couches
indépendantes qui ne doivent pas se connaître directement (section 13.1 des
spécifications fonctionnelles — séparation stricte eye-tracking / logique
métier / UI) :

- le flux `GazeState` produit par `GazeTrackingPipeline` (`lib/eyetracking`),
  consommé par plusieurs écrans (`Grid4Screen`, `YesNoScreen`) ;
- l'écran courant / historique de navigation, résolu par `ActionResolver`
  (`lib/domain`), consommé par la même UI ;
- les réglages utilisateur (`AppSettings`, `lib/data/settings_repository.dart`),
  qui doivent se propager en temps réel vers le pipeline eye-tracking, le
  service TTS et le thème, sans que ces couches ne s'observent entre elles.

Il fallait une solution testable sans `BuildContext` (les couches `domain`
et `eyetracking` n'ont aucune dépendance Flutter UI), avec un mécanisme de
surcharge propre pour l'injection de dépendances asynchrones à
l'initialisation (`SharedPreferences`, choix du détecteur de regard réel vs.
factice).

## Décision

Utiliser `flutter_riverpod` comme unique solution de state management,
partout où un état doit être partagé au-delà d'un seul widget.

Pattern retenu dans le code : un `Notifier<T>` par domaine d'état
(`SettingsController`, `MenuNavigationController`), exposé via un
`NotifierProvider`/`Provider` top-level, lu en écriture via
`ref.read(...notifier)` et en lecture réactive via `ref.watch(...)`. Les
dépendances asynchrones à l'initialisation (`SharedPreferences`, détecteur
de regard réel `FaceMeshGazeDetector` vs. factice
`FakeFaceGazeDetector`) sont modélisées comme des providers qui lèvent une
erreur explicite tant qu'ils n'ont pas été surchargés via
`overrideWithValue` dans `main()`, plutôt que de retourner une valeur
factice qui masquerait un oubli de câblage — voir
`lib/data/settings_repository.dart` (`sharedPreferencesProvider`) et
`lib/ui/providers/gaze_tracking_providers.dart` (`faceGazeDetectorProvider`).

`ProviderScope` est câblé dès la racine (`lib/main.dart`) même avant que
plusieurs providers réels n'existent, pour éviter un refactor de structure
plus tard.

## Conséquences

- Les couches `domain` et `eyetracking` restent des modules Dart purs, sans
  import Flutter ni Riverpod : seuls les providers dans `lib/ui/providers/`
  et `lib/data/settings_repository.dart` font le pont vers Riverpod. Cela
  garde la logique métier/eye-tracking testable sans `WidgetTester`.
- Toute nouvelle dépendance init-time asynchrone doit suivre le même patron
  (`Provider` qui lève tant qu'il n'est pas surchargé + surcharge dans
  `main()` après `WidgetsFlutterBinding.ensureInitialized()`).
- Alternative non retenue : `Provider`/`ChangeNotifier` seul (package
  `provider`) — écarté car moins adapté à l'injection de dépendances
  asynchrones propre nécessaire ici (détecteur de regard swappable,
  `SharedPreferences`), et à la testabilité indépendante de `BuildContext`
  recherchée pour `domain`/`eyetracking`.
