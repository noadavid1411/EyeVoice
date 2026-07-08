# Contrats d'interface entre agents/couches

Ce document décrit les trois contrats qui traversent les couches de "La Voix
du Regard" (EyeVoice) et que plusieurs agents/développeurs doivent consommer
sans relire tout le code source :

1. `ActionResult` — sortie de la couche `domain` (résolution d'action).
2. `GazeState` — sortie de la couche `eyetracking` (flux d'état du regard).
3. Le schéma `menu-config.json` — format de données consommé par `domain`.

Si le comportement réel du code diverge de ce qui est décrit ici, c'est un
bug de documentation ou de code à signaler en priorité — ce document doit
rester le reflet fidèle de l'implémentation, pas une intention.

---

## 1. `ActionResult` — résolution d'action

**Source de vérité** : `lib/domain/actions/action_result.dart` (types),
`lib/domain/actions/action_resolver.dart` (résolution).

### Rôle

`ActionResolver.resolve(MenuItem item) -> ActionResult` transforme un item
sélectionné de `menu-config.json` (les chaînes d'action brutes `navigate`,
`speak`, `back`, `home`, `openMode`, `settings`, `cancel` — section 12 des
spécifications) en une valeur **déjà résolue**, prête à être exécutée telle
quelle par `ui`. La couche `ui` n'interprète jamais les chaînes JSON
d'action ni ne manipule la pile de navigation elle-même.

`back` et `home` sont résolus en `NavigateAction` pointant vers l'écran cible
déterminé via `NavigationHistory` (`lib/domain/actions/navigation_history.dart`)
: l'UI n'a donc qu'un seul cas à gérer pour tout changement d'écran, qu'il
s'agisse d'une navigation avant ou arrière.

### Forme du type

`ActionResult` est un `sealed class` Dart (exhaustivité vérifiée
statiquement par un `switch` côté `ui`) avec cinq variantes :

| Variante | Champ(s) | Correspond à l'action JSON | Sémantique |
|---|---|---|---|
| `NavigateAction` | `screenId: String` | `navigate`, `back`, `home` | Afficher l'écran `screenId` (doit exister dans `menu-config.json`) |
| `SpeakAction` | `text: String` | `speak` | Faire prononcer `text` par le TTS |
| `OpenModeAction` | `mode: AppMode` | `openMode` | Ouvrir un mode dédié : `AppMode.yesNo`, `AppMode.expert`, `AppMode.settings` |
| `SettingsAction` | — | `settings` | Ouvrir l'écran de réglages (distinct de `OpenModeAction(AppMode.settings)` — les deux formulations JSON existent en parallèle, section 12) |
| `CancelAction` | — | `cancel` | Aucun effet de navigation ; sert aussi de socle conceptuel à l'annulation d'une confirmation (voir ci-dessous) |

### Contrat de confirmation (`MenuItem.requiresConfirmation`)

Champ booléen (`lib/domain/models/menu_item.dart`, défaut `false`,
optionnel dans le JSON — absent ⇒ `false`) pour les actions sensibles
(section 17.2 : quitter, réinitialiser les réglages, supprimer une phrase).

**`ActionResolver` ne lit jamais ce champ** — il reste une fonction pure
(item + état de navigation → résultat). C'est un contrat entre `domain` et
`ui` : la couche `ui` doit lire `item.requiresConfirmation` **avant**
d'appeler `resolve(item)` et, si `true`, afficher un dialogue de
confirmation. `resolve(item)` n'est appelé qu'après validation explicite
("Oui"). Si l'utilisateur annule ("Non"), `resolve` n'est simplement jamais
appelé — il n'y a pas de `CancelAction` dédié à ce cas particulier.

Implémentation actuelle côté `ui` : `MenuNavigationController.activate`
(`lib/ui/providers/menu_navigation_controller.dart`).

### Historique de navigation (`NavigationHistory`)

Pile de `screenId`, l'accueil (`homeScreenId`) restant toujours au fond et
jamais dépilé par `pop()` — un "retour" depuis l'accueil reste sur l'accueil
plutôt que de lever une erreur.

---

## 2. `GazeState` — flux d'état du regard

**Source de vérité** : `lib/eyetracking/models/gaze_state.dart` (contrat),
`lib/eyetracking/gaze_tracking_pipeline.dart` (production du flux).

### Rôle

`GazeTrackingPipeline.states` (`Stream<GazeState>`) est le **point de
jonction unique** entre la détection brute du regard (caméra, MediaPipe,
mapping en coordonnées écran) et le reste de l'application. Aucune couche
en dehors de `eyetracking` ne doit connaître les coordonnées brutes, le
framework de détection utilisé, ni les seuils de stabilité internes (section
13.1).

Flux fonctionnel produisant chaque `GazeState` (section 13.2) :

```text
Caméra frontale → Détection visage/iris (FaceMeshGazeDetector)
  → Coordonnées du regard (GazeToScreenMapper, calibré)
  → Mapping vers zone écran + zone morte (ZoneMapper)
  → State machine dwell time (DwellTimeController)
  → Qualité de signal (SignalQualityMonitor)
  → GazeState
```

### Champs

| Champ | Type | Sémantique |
|---|---|---|
| `zone` | `ScreenZone?` | Zone actuellement fixée, ou `null` si aucune zone n'est exploitable (visage non détecté, transition, signal trop instable). Peut valoir `ScreenZone.centerDeadZone`. |
| `dwellProgress` | `double` (0.0–1.0) | Progression du dwell time pour `zone`. **Invariant garanti par `eyetracking`** : vaut `0.0` si `zone` est `null` ou `centerDeadZone` — les couches consommatrices peuvent s'y fier sans le revérifier (garanti par `DwellTimeController.update`). |
| `confidence` | `double` (0.0–1.0) | Confiance de la détection courante (qualité caméra/modèle), indépendante de la simple présence/absence d'un visage. |
| `signalStatus` | `GazeSignalStatus` | Statut de dégradation — voir ci-dessous. |

`GazeState.idle()` : état de repos (`zone: null`, `dwellProgress: 0.0`,
`confidence: 0.0`, `signalStatus: lost`), utilisé notamment quand
`GazeTrackingPipeline.start()` échoue (caméra indisponible, permission
refusée) — le pipeline ne lève jamais d'exception vers `ui`.

### `GazeSignalStatus` (section 17.3 — mode dégradé)

| Valeur | Sémantique | Effet attendu côté `ui` |
|---|---|---|
| `ok` | Visage détecté, signal stable | Fonctionnement normal |
| `degraded` | Visage détecté mais signal instable (alternance de zones, confiance fluctuante) | Sélections en cours annulées (déjà géré en amont par `DwellTimeController`) ; eye-tracking reste actif, pas de bascule automatique vers le mode tactile |
| `lost` | Visage non détecté (ou signal indisponible) depuis un délai significatif | `ui` doit proposer/activer le mode dégradé tactile — voir `DegradedSignalBanner` (`lib/ui/widgets/degraded_signal_banner.dart`), qui affiche une bannière dès `degraded`/`lost` |

`degraded` vs `lost` : distinction volontaire pour éviter de basculer en
mode tactile sur une simple instabilité passagère — seul un `lost` prolongé
déclenche la bascule visuelle.

### Entrée du pipeline : `setLayoutMode` / `updateSettings`

`eyetracking` ne connaît pas le contenu de `menu-config.json`. La couche
appelante doit annoncer la disposition de zones actuellement affichée via
`GazeTrackingPipeline.setLayoutMode(ScreenLayoutMode.quadrant | yesNo)` à
chaque changement d'écran, et propager les réglages utilisateur (dwell time,
sensibilité, zone morte) via `updateSettings(EyeTrackingSettings)` — câblé
depuis `SettingsScreen` via `gazeTrackingPipelineProvider`
(`lib/ui/providers/gaze_tracking_providers.dart`).

---

## 3. Schéma `menu-config.json`

**Source de vérité** : `lib/domain/models/menu_config.dart`,
`menu_screen.dart`, `menu_item.dart`, `menu_action.dart`,
`menu_config_validator.dart`. Référence fonctionnelle : section 11.2 des
spécifications.

### Chargement en deux temps

`loadMenuConfig(json)` = `MenuConfig.fromJson(json)` (parsing de forme,
écran par écran) puis `validateMenuConfig(config)` (règles métier globales,
sur l'ensemble de la config). Volontairement séparés : le parsing pur reste
testable indépendamment des règles de cohérence.

- `MenuConfig.fromJson` lève `MenuConfigParseException` si un champ requis
  manque, a le mauvais type, ou une chaîne (`action`, `zone`) ne correspond
  à aucune valeur connue.
- `validateMenuConfig` lève `MenuConfigValidationException` (liste
  d'erreurs, collectées toutes avant de lever — pas d'arrêt à la première)
  si la structure est valide mais incohérente.

### Racine (`MenuConfig`)

```json
{
  "appName": "La Voix du Regard",
  "defaultDwellTimeMs": 1300,
  "homeScreenId": "home",
  "screens": [ /* MenuScreen[] */ ]
}
```

| Champ | Type | Contrainte |
|---|---|---|
| `appName` | `String` | non vide |
| `defaultDwellTimeMs` | `int` | strictement positif |
| `homeScreenId` | `String` | doit correspondre à un `id` d'écran existant (vérifié par `validateMenuConfig`) |
| `screens` | `MenuScreen[]` | non vide |

### `MenuScreen`

| Champ | Type | Contrainte |
|---|---|---|
| `id` | `String` | non vide, unique dans toute la config |
| `type` | `String` | non vide (seul `"grid-4"` utilisé par le MVP ; conservé en `String` libre pour permettre un futur type d'écran sans repasser par ce module) |
| `title` | `String` | peut être vide |
| `items` | `MenuItem[]` | **maximum `AppDefaults.maxChoicesPerScreen` (4)** — règle du carré magique, section 4.1/10.1 |

Règles supplémentaires vérifiées par `validateMenuConfig` au niveau écran :
une même `zone` ne peut pas être utilisée deux fois sur le même écran.

### `MenuItem`

```json
{
  "zone": "top-left",
  "label": "🩺 PHYSIQUE",
  "action": "navigate",
  "target": "physical",
  "requiresConfirmation": false
}
```

| Champ | Type | Requis pour | Contrainte |
|---|---|---|---|
| `zone` | `String` | toujours | une des 7 valeurs de la section 13.3 : `top-left`, `top-right`, `bottom-left`, `bottom-right`, `left`, `right`, `center-dead-zone` (`left`/`right` réservés au mode Oui/Non ; `center-dead-zone` accepté par symétrie mais un item qui y serait placé serait inatteignable au regard — non bloqué par le validateur) |
| `label` | `String` | toujours | non vide |
| `action` | `String` | toujours | une des 7 valeurs de la section 12 : `navigate`, `speak`, `back`, `home`, `openMode`, `settings`, `cancel` |
| `target` | `String?` | `action: "navigate"` | doit référencer un `id` d'écran existant (validé) |
| `target` | `String?` | `action: "openMode"` | doit être `"yes-no"`, `"expert"` ou `"settings"` (mappé vers `AppMode` via `appModeFromTarget`) |
| `text` | `String?` | `action: "speak"` | non vide (validé) |
| `requiresConfirmation` | `bool` | optionnel, toutes actions | défaut `false` si absent — rétrocompatible avec des configs existantes qui ne le déclarent pas |

Zones logiques (`ScreenZone`, partagé avec `eyetracking` via `lib/core`) :
voir section 13.3. `top-left`/`top-right`/`bottom-left`/`bottom-right` pour
la grille 4 zones, `left`/`right` pour le mode Oui/Non, `center-dead-zone`
jamais déclenchable.

### Exemple minimal valide

Voir `lib/domain/models/sample_menu_config.dart` pour une configuration
complète construite directement en Dart (sans JSON), reprenant toute
l'arborescence des sections 9.1 à 9.5 — sert de fixture de référence pour
les tests et le développement UI tant qu'un vrai fichier
`menu-config.json` n'est pas chargé depuis les assets.

Un exemple JSON complet figure aussi en section 11.2 des spécifications
fonctionnelles (`SPECIFICATIONS_FONCTIONNELLES.md`).
