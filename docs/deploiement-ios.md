# Déploiement iOS

Ce document couvre le build et la distribution de "La Voix du Regard" sur
iOS/iPadOS. Il complète `docs/validation-materielle.md` (fiabilité de
l'eye-tracking sur matériel réel), qui reste un sujet séparé : ce document
répond à "comment faire arriver l'app sur un appareil", pas "l'eye-tracking
fonctionne-t-il dessus".

**État actuel : l'application n'a jamais été buildée pour iOS.** Tout ce
document est donc écrit à partir de la configuration présente dans le dépôt
(`ios/`) et de la chaîne d'outillage standard Flutter/Xcode — pas d'un build
réel déjà validé sur ce projet. À la première tentative, prévoir du temps
pour des ajustements imprévus.

---

## 1. Limite bloquante : le développement se fait sous Windows

Le poste de développement actuel est Windows. **Un build iOS (simulateur ou
appareil) est impossible sans macOS** : Xcode, qui compile et signe l'app,
ne tourne que sur Mac. `flutter build ios` / `flutter build ipa` échoueront
immédiatement sous Windows (`flutter doctor` le confirme : la section
"Xcode" reste absente/invalide hors macOS).

Deux façons de lever ce blocage :

1. **Mac physique** (Mac mini, MacBook, iMac...), avec Xcode installé
   (App Store, gratuit). C'est l'option la plus simple pour itérer
   (debug, logs, simulateur iOS) une fois disponible.
2. **CI cloud macOS**, si aucun Mac physique n'est disponible :
   - **Codemagic** — build Flutter iOS clé en main, gère la signature via
     l'intégration App Store Connect, formule gratuite limitée puis payante.
   - **GitHub Actions, runner `macos-latest`** — plus de configuration
     manuelle (installer Flutter, CocoaPods, gérer les certificats/profils
     de provisionnement en secrets), mais gratuit dans une certaine limite
     pour les dépôts publics et inclus dans les forfaits payants pour les
     dépôts privés.
   - Autres alternatives équivalentes : Bitrise, Xcode Cloud (nécessite
     malgré tout un compte Apple Developer et, pour la configuration
     initiale des workflows, un accès à Xcode).

   Dans tous les cas, un **compte Apple Developer** (voir section 4) reste
   nécessaire pour la signature, que le build tourne sur un Mac physique ou
   dans le cloud.

Ce document part du principe qu'un Mac (physique ou cloud) devient
disponible avant la suite ; en attendant, seul le développement
Android/logique métier peut avancer (voir `README.md`, section
"Prérequis").

---

## 2. Prérequis techniques

| Élément | Détail |
|---|---|
| macOS + Xcode | Xcode le plus récent compatible avec le canal Flutter stable utilisé (voir `flutter doctor`) |
| CocoaPods | Requis par Flutter pour gérer les dépendances iOS natives (`sudo gem install cocoapods` ou `brew install cocoapods`) |
| Compte Apple Developer | Individuel/Organisation (99 $/an) ou Enterprise (299 $/an) — voir section 4 pour le choix |
| Appareil de test | iPhone/iPad physique recommandé (le simulateur iOS ne fournit **pas** de flux caméra réel — inutilisable pour tester `FaceMeshGazeDetector`, voir `docs/validation-materielle.md`) |

Aucun `ios/Podfile` n'existe encore dans le dépôt : il sera généré
automatiquement à la première commande `flutter build ios`/`flutter pub get`
lancée depuis un environnement avec Xcode installé (comportement standard
Flutter, rien à faire manuellement en amont).

`ios/Runner.xcodeproj` déclare `IPHONEOS_DEPLOYMENT_TARGET = 13.0` — à
vérifier/relever au premier build réel si `mediapipe_face_mesh` ou une autre
dépendance impose une version minimale d'iOS plus récente (`flutter pub get`
et `pod install` signaleront le cas échéant un conflit de version).

---

## 3. Vérifications de configuration avant le premier build réel

### Déjà en place

- **`NSCameraUsageDescription`** (`ios/Runner/Info.plist`) : présent depuis
  le commit `234fb4f`, obligatoire — `FaceMeshGazeDetector`
  (`lib/eyetracking/detection/face_mesh_gaze_detector.dart`) utilise la
  caméra frontale via `package:camera`. Sans cette clé, iOS tue l'app
  immédiatement à la première demande d'accès caméra (crash silencieux,
  aucun message d'erreur Flutter exploitable).
- **Orientations supportées** (`UISupportedInterfaceOrientations` /
  `~ipad`) : portrait + paysage déclarés pour iPhone, portrait + paysage +
  portrait inversé pour iPad. Cohérent avec un usage tablette fixe face au
  patient (section 3.3 des spécifications) — aucun changement attendu ici,
  mais à confirmer visuellement une fois un build réel disponible (l'app
  doit rester utilisable dans l'orientation où la tablette sera
  effectivement montée en chambre).

### À vérifier au premier build réel (non encore testé)

- **Permission caméra en usage réel** : la description française de
  `NSCameraUsageDescription` n'a jamais été vue affichée par un vrai iOS
  (le texte est correct sur le papier, mais son rendu dans la boîte de
  dialogue système iOS n'a pas été vérifié).
- **Conversion d'image caméra sur iOS** : `FaceMeshGazeDetector._toNv21`
  gère un cas spécifique iOS (flux bi-planaire Y + chroma entrelacé,
  `tryFromYAndInterleavedVuPlanes`), avec une approximation documentée dans
  le code — l'ordre de chrominance natif iOS (CbCr) est réutilisé tel quel
  comme "VU" NV21, sans inversion. Le code affirme que ça affecte la
  normalisation colorimétrique interne du modèle mais pas la géométrie des
  landmarks — **affirmation non vérifiée empiriquement sur iOS**, à
  confirmer lors du premier test caméra réel (voir
  `docs/validation-materielle.md`).
- **Rotation d'image** : `_rotationDegreesFor` retourne toujours `0` sur
  iOS (le code part du principe que `package:camera` pré-tourne déjà le
  flux pour un usage portrait fixe). À confirmer sur appareil, en
  particulier si la tablette est finalement montée dans une orientation
  différente du portrait pur.
- **Autres capacités/permissions** : aucune autre permission (micro,
  photothèque, réseau local, etc.) n'est utilisée par le code actuel — pas
  d'ajout `Info.plist` attendu au-delà de la caméra. Point de vigilance
  cependant : `mediapipe_face_mesh`, non testé sur iOS dans ce projet
  (voir `docs/adr/0003-mediapipe-face-mesh.md`), pourrait révéler une
  exigence de configuration native (framework à lier, `Info.plist`
  supplémentaire) uniquement visible à la compilation iOS — à traiter au
  cas par cas si `flutter build ios` échoue avec une erreur liée à ce
  package.

---

## 4. Build et signature

Commande standard Flutter pour produire un artefact signé et prêt à
distribuer, à exécuter depuis macOS (ou le job CI macOS) :

```bash
flutter build ipa
```

Produit un `.xcarchive` puis un `.ipa` dans
`build/ios/ipa/`. Nécessite au préalable, dans Xcode ou via
`ios/Runner.xcodeproj` :

- un identifiant d'équipe (Team) Apple Developer configuré sur la cible
  `Runner` ;
- un certificat de signature (Development ou Distribution selon la cible
  de distribution, voir section 5) ;
- un profil de provisionnement correspondant (généré automatiquement par
  Xcode en "Automatically manage signing" pour un premier essai, ou
  manuellement pour une distribution Enterprise/MDM — voir section 5.3).

Pour un premier test rapide sur un iPhone/iPad personnel de développement
(sans distribution), `flutter run` (avec l'appareil branché et déverrouillé,
Xcode configuré avec un compte Apple Developer même gratuit) suffit et évite
les étapes de signature de distribution.

---

## 5. Options de distribution — comparatif

Le choix dépend d'un facteur : ce projet vise un déploiement **institutionnel
interne** (tablettes fournies par un hôpital/service à ses patients), pas
une diffusion grand public. Les quatre options ci-dessous sont comparées sur
cette base.

### 5.1 App Store public

| | |
|---|---|
| Compte requis | Apple Developer Program, 99 $/an |
| Délai | Review Apple, 1 à 3+ jours (parfois plus en cas de rejet/allers-retours) |
| Contraintes | Nutrition labels de confidentialité (déclaration détaillée des données collectées/caméra), captures d'écran iPad obligatoires si l'app cible iPad, conformité aux App Store Review Guidelines |
| Avantage | Installation simple pour l'utilisateur final (recherche + un tap) |
| Inconvénient pour ce projet | Expose publiquement un outil à vocation médicale/institutionnelle sans contrôle sur qui l'installe ; review Apple peut interroger l'usage de la caméra pour un public patient vulnérable ; cycle de review incompatible avec des itérations rapides en contexte hospitalier |

**Non recommandé comme objectif principal** pour ce projet : la distribution
publique n'apporte rien à un outil destiné à être installé sur un parc de
tablettes contrôlé par un service hospitalier, et ajoute de la friction
(review, confidentialité) sans bénéfice.

### 5.2 TestFlight

| | |
|---|---|
| Compte requis | Le même compte Apple Developer Program (99 $/an) — pas de compte séparé |
| Délai | Build interne : quasi immédiat (jusqu'à 100 testeurs internes, membres de l'équipe Apple Developer). Build externe : review Apple allégée (plus rapide qu'une review App Store complète), jusqu'à 10 000 testeurs externes par lien public |
| Contraintes | Build expire au bout de 90 jours, nécessite de renvoyer un nouveau build régulièrement |
| Avantage | Rapide à mettre en place, bon outil pour une phase pilote (ex. un service hospitalier volontaire teste l'app avant généralisation) |
| Inconvénient | Reste pensé pour du test, pas pour une distribution permanente/à long terme sur un parc de tablettes de production |

**Recommandé pour la phase pilote/test**, avant tout déploiement plus large,
y compris avant validation matérielle complète (voir
`docs/validation-materielle.md`) — permet de mettre l'app entre les mains
d'un vrai testeur sur un vrai appareil rapidement.

### 5.3 Apple Developer Enterprise Program

| | |
|---|---|
| Compte requis | Compte Enterprise séparé, 299 $/an, **nécessite d'être une organisation reconnue** (numéro D-U-N-S, vérification d'identité renforcée par Apple) |
| Délai | Aucune review Apple — distribution "in-house" directe (fichier `.ipa` + profil de provisionnement Enterprise installés directement sur les appareils de l'organisation, hors App Store) |
| Contraintes | Réservé à un usage strictement interne à l'organisation détentrice du compte (pas de distribution au grand public, sous peine de révocation du compte par Apple) ; l'app doit rester installée uniquement sur des appareils possédés/gérés par l'organisation |
| Avantage | Pas de review, pas de délai, contrôle total sur le rythme de mise à jour — cohérent avec un outil médical déployé et maintenu par un service technique hospitalier |
| Inconvénient | Coût et lourdeur administrative de l'inscription Enterprise (vérification D-U-N-S peut prendre plusieurs semaines) ; ne convient pas si l'app doit un jour être proposée à plusieurs hôpitaux indépendants (chacun n'est pas "la même organisation" au sens Apple) |

**Généralement le choix le plus adapté pour ce type d'outil**, si le porteur
du projet (hôpital, éditeur du logiciel médical) est en mesure d'ouvrir un
compte Enterprise : déploiement sur un parc de tablettes possédées par
l'établissement, sans exposition publique, sans délai de review récurrent.
À mettre en place une fois la phase pilote (TestFlight) concluante plutôt
que dès le premier build.

### 5.4 MDM (Mobile Device Management)

Le MDM n'est **pas une alternative** aux trois options ci-dessus mais une
couche de gestion de flotte qui s'articule avec elles, pour un déploiement à
l'échelle d'un service :

- Un logiciel MDM (Jamf, Microsoft Intune, Mosyle, etc.) permet
  d'**installer/mettre à jour l'app à distance** sur toutes les tablettes
  d'un service, sans intervention manuelle par tablette.
- Il permet de **verrouiller la tablette en mode kiosque** ("Guided Access"
  / "Single App Mode" iOS), pour qu'un patient ne puisse pas sortir de
  l'application (bouton Accueil désactivé, pas d'accès aux autres apps) —
  pertinent pour un usage patient sans supervision continue.
- Combinaison typique pour ce projet : **compte Enterprise (5.3)** pour
  produire et signer le build en interne, **MDM** pour le pousser et
  verrouiller les tablettes en mode kiosque à l'échelle du service. Un
  compte Developer Program (5.1/5.2) fonctionne aussi avec un MDM, mais
  suppose alors que chaque tablette ait été enregistrée individuellement
  (TestFlight) ou que l'app soit passée par l'App Store (5.1) — plus lourd
  à l'échelle d'un parc.
- Le choix du logiciel MDM et sa configuration (profils de restriction,
  mode kiosque) sont hors périmètre technique de ce projet Flutter — décision
  à prendre avec le service informatique de l'établissement hospitalier.

### Résumé

| Objectif | Option recommandée |
|---|---|
| Premier test sur un vrai appareil, itération rapide | `flutter run` en direct (compte Developer gratuit ou payant) |
| Phase pilote avec un service hospitalier volontaire | TestFlight (5.2) |
| Déploiement permanent sur le parc de tablettes d'un ou plusieurs services | Enterprise Program (5.3) + MDM (5.4) en mode kiosque |
| Diffusion grand public | App Store (5.1) — non pertinent pour ce projet en l'état |

---

## 6. Checklist premier build iOS réel

À dérouler une fois un Mac (physique ou CI) disponible :

1. `flutter doctor` sur macOS — vérifier que la section Xcode est "installed
   and verified", CocoaPods installé.
2. `flutter pub get` (génère `ios/Podfile` s'il n'existe pas encore),
   `cd ios && pod install`.
3. Ouvrir `ios/Runner.xcworkspace` (pas `.xcodeproj`) dans Xcode, configurer
   un Team Apple Developer sur la cible `Runner`.
4. `flutter run -d <device-id>` sur un iPhone/iPad physique réel — un
   simulateur ne peut pas servir à tester l'eye-tracking (pas de caméra),
   voir `docs/validation-materielle.md`.
5. Vérifier au premier lancement : la boîte de dialogue de permission
   caméra s'affiche avec le texte attendu, l'acceptation déclenche
   effectivement un flux caméra (pas de crash).
6. Une fois le build de base validé : envisager TestFlight (5.2) pour une
   phase pilote, avant de considérer une distribution Enterprise (5.3).
