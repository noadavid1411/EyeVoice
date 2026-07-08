# Spécifications Fonctionnelles — Application **La Voix du Regard**

## 1. Objectif du document

Ce document sert de référence fonctionnelle principale pour le développement de l’application **La Voix du Regard**.

Il doit être placé à la racine du projet afin que Claude, un autre assistant IA ou un développeur puisse comprendre rapidement :

- le contexte d’utilisation ;
- les besoins du patient ;
- les règles d’ergonomie ;
- l’architecture fonctionnelle ;
- les modes de communication attendus ;
- les contraintes techniques principales ;
- la structure de données attendue pour les menus et les phrases.

---

## 2. Contexte général

### 2.1 Utilisateur cible

L’application est destinée à un patient :

- hospitalisé en réanimation ;
- intubé ou trachéotomisé ;
- conscient ;
- incapable de parler ;
- potentiellement très fatigué ;
- pouvant encore orienter son regard ;
- ayant besoin de communiquer rapidement avec ses proches ou le personnel soignant.

### 2.2 Problème à résoudre

Le patient ne peut pas s’exprimer oralement. Il doit pouvoir communiquer avec un minimum d’effort physique et cognitif, uniquement grâce à son regard.

L’application doit donc permettre :

- de répondre rapidement à des questions simples ;
- d’exprimer des besoins essentiels ;
- d’exprimer une douleur, une émotion ou une gêne ;
- de communiquer avec ses proches ;
- d’écrire librement dans un mode avancé, si son état le permet.

### 2.3 Objectif principal

Fournir un moyen de communication autonome, simple, lisible et rapide, basé sur l’eye-tracking via la caméra frontale d’une tablette ou d’un téléphone.

L’application doit limiter au maximum :

- la fatigue visuelle ;
- la charge cognitive ;
- les erreurs de sélection ;
- les mouvements inutiles ;
- les interfaces complexes.

---

## 3. Contraintes matérielles

### 3.1 Support cible

L’application doit être utilisable sur :

- tablette Android ;
- tablette iOS ;
- éventuellement smartphone en mode paysage ;
- éventuellement navigateur web si une version HTML/JS est développée.

### 3.2 Caméra

L’application doit utiliser uniquement :

- la caméra frontale de l’appareil ;
- aucun matériel externe d’eye-tracking ;
- aucune souris ;
- aucun clavier physique ;
- aucun bouton physique obligatoire.

### 3.3 Positionnement

L’appareil est placé face au patient, idéalement :

- à hauteur du visage ;
- stable ;
- suffisamment proche pour lire de grands boutons ;
- avec une luminosité adaptée à un environnement hospitalier.

---

## 4. Principes fondamentaux d’ergonomie

## 4.1 Règle du carré magique

Sauf exception spécifique, l’interface principale repose sur une grille fixe de **4 zones**.

L’écran est divisé en quatre quadrants :

1. haut gauche ;
2. haut droite ;
3. bas gauche ;
4. bas droite.

Chaque écran fonctionnel ne doit jamais proposer plus de **4 choix visibles**.

### Objectif

Cette règle permet :

- une lecture rapide ;
- une mémorisation spatiale ;
- une réduction des erreurs ;
- une fatigue visuelle réduite ;
- une meilleure accessibilité pour un patient faible ou épuisé.

---

## 4.2 Stabilité spatiale

Les zones principales doivent rester stables.

La position des grandes catégories ne doit pas changer entre les écrans principaux.

Le patient doit pouvoir apprendre naturellement que :

- le haut gauche correspond généralement aux besoins physiques ;
- le haut droite correspond généralement à la conversation ;
- le bas gauche correspond généralement aux émotions ou à l’état général ;
- le bas droite correspond toujours à la navigation, aux options ou au retour.

---

## 4.3 Zone morte centrale

Le centre de l’écran doit être une zone neutre.

Aucune action ne doit être validée lorsque le regard est détecté dans cette zone.

### Objectif

La zone morte permet au patient de :

- reposer son regard ;
- éviter les validations involontaires ;
- récupérer visuellement ;
- interrompre naturellement une sélection.

---

## 4.4 Sélection par fixation du regard

La sélection d’un bouton se fait par **dwell time**.

Cela signifie qu’un choix est validé lorsque le patient fixe une zone pendant une durée continue déterminée.

### Valeur attendue par défaut

Durée recommandée : entre **1,2 et 1,5 seconde**.

Cette durée doit être paramétrable.

### Comportement attendu

Lorsqu’un patient fixe une zone :

1. l’application détecte la zone regardée ;
2. un indicateur visuel démarre ;
3. si le regard reste dans la même zone jusqu’à la fin du délai, l’action est validée ;
4. si le regard sort de la zone, la progression est annulée.

---

## 4.5 Retour visuel obligatoire

Toute sélection en cours doit afficher un retour visuel clair.

Exemples possibles :

- cercle de progression ;
- barre de progression ;
- bordure lumineuse ;
- remplissage progressif du bouton.

### Objectif

Le patient doit comprendre que son regard est bien détecté et qu’une action est en train d’être sélectionnée.

---

## 4.6 Bouton de retour universel

Le quadrant **bas droite** est réservé à la navigation.

Il doit contenir selon le contexte :

- retour ;
- annuler ;
- menu principal ;
- options ;
- quitter.

Aucune action critique ou phrase finale ne doit être placée durablement dans ce quadrant si elle peut entrer en conflit avec la navigation.

---

## 5. Architecture fonctionnelle générale

L’application est organisée en plusieurs niveaux de complexité.

Chaque niveau correspond à un état d’énergie ou de capacité du patient.

---

# Niveau 1 — Mode Sécurité

## 5.1 Objectif

Permettre au patient de répondre immédiatement à une question fermée.

Exemples :

- « Est-ce que tu as mal ? »
- « Tu veux qu’on appelle l’infirmière ? »
- « Tu veux dormir ? »
- « Tu veux qu’on reste ? »

## 5.2 Interface

L’écran est divisé en **2 zones verticales**.

- gauche : OUI ;
- droite : NON.

## 5.3 Règles visuelles

- OUI doit être affiché en vert ;
- NON doit être affiché en rouge ;
- le texte doit être très grand ;
- l’interface doit être extrêmement simple ;
- aucun élément secondaire ne doit distraire le patient.

## 5.4 Comportement attendu

Lorsque le patient fixe OUI ou NON pendant le dwell time configuré :

- la réponse est validée ;
- la synthèse vocale peut prononcer « Oui » ou « Non » ;
- un retour visuel confirme la validation.

---

# Niveau 2 — Mode Besoins Rapides

## 6.1 Objectif

Permettre au patient d’exprimer rapidement un besoin courant sans écrire.

Ce mode correspond à l’écran d’accueil standard de l’application.

## 6.2 Interface d’accueil

L’écran est divisé en 4 quadrants fixes.

| Zone | Libellé | Rôle |
|---|---|---|
| Haut gauche | 🩺 PHYSIQUE | Besoins vitaux, douleur, inconfort |
| Haut droite | 💬 CONVERSATION | Dialogue, questions, phrases préparées |
| Bas gauche | ❤️ ÉMOTIONS / ÉTAT | Humeur, fatigue, besoin de présence |
| Bas droite | ⚙️ OPTIONS | Changer de mode, réglages, quitter |

## 6.3 Règle de navigation

Chaque quadrant ouvre un sous-menu contenant au maximum 4 choix.

Le quatrième choix doit généralement être réservé à :

- retour ;
- menu principal ;
- annuler.

---

# Niveau 3 — Mode Conversation

## 7.1 Objectif

Permettre au patient de communiquer rapidement avec des phrases complètes pré-enregistrées.

Ce mode doit éviter au patient d’avoir à épeler des phrases fréquentes.

## 7.2 Exemples de phrases

- « Quelle heure est-il ? »
- « Qui vient me voir aujourd’hui ? »
- « Explique-moi ce qui se passe. »
- « J’ai peur. »
- « Je veux voir quelqu’un. »
- « Reste avec moi. »
- « Je suis fatigué. »
- « Merci. »
- « Je t’aime. »

## 7.3 Comportement attendu

Lorsqu’une phrase finale est sélectionnée :

1. la phrase est affichée en grand ;
2. la synthèse vocale prononce la phrase ;
3. l’application propose un retour au menu précédent ou au menu principal.

---

# Niveau 4 — Mode Expert

## 8.1 Objectif

Permettre au patient d’écrire un mot ou une phrase libre lorsque les menus préparés ne suffisent pas.

Ce mode est destiné à un patient plus disponible cognitivement, car il demande plus d’attention.

## 8.2 Principe général

Le mode expert utilise une saisie par balayage temporel.

Le patient n’a pas besoin de clavier classique.

## 8.3 Première étape : choix du groupe de lettres

L’écran affiche 4 groupes de lettres :

| Zone | Groupe |
|---|---|
| Haut gauche | A-F |
| Haut droite | G-L |
| Bas gauche | M-R |
| Bas droite | S-Z / Retour selon contexte |

Le système met successivement chaque groupe en surbrillance.

Le patient valide le groupe souhaité en fixant la zone correspondante pendant la période de surbrillance.

## 8.4 Deuxième étape : choix de la lettre

Après validation d’un groupe, l’écran affiche les lettres du groupe sélectionné.

Exemple pour le groupe A-F :

- A ;
- B ;
- C ;
- D ;
- E ;
- F.

Comme l’interface doit rester limitée à 4 choix, les lettres peuvent être présentées :

- par sous-groupes ;
- ou via un balayage automatique ;
- ou via pages successives.

## 8.5 Prédiction de mots

Une zone supérieure peut afficher des suggestions de mots.

Objectif : réduire le nombre de sélections nécessaires.

Exemples :

- après « do », proposer « douleur », « dormir », « docteur » ;
- après « inf », proposer « infirmière ».

## 8.6 Fonctions minimales du mode expert

Le mode expert doit permettre :

- ajouter une lettre ;
- effacer la dernière lettre ;
- insérer un espace ;
- valider le mot ou la phrase ;
- revenir au menu principal.

---

## 9. Arborescence fonctionnelle recommandée

L’arborescence ci-dessous est une base de configuration.

Elle doit être modifiable facilement dans un fichier de données séparé, idéalement au format JSON.

---

## 9.1 Écran d’accueil

```text
ACCUEIL
├── PHYSIQUE
├── CONVERSATION
├── ÉMOTIONS / ÉTAT
└── OPTIONS
```

---

## 9.2 Menu PHYSIQUE

```text
PHYSIQUE
├── J’ai soif / faim
├── J’ai mal
├── Changer de position / inconfort
└── Retour
```

### Sous-menu J’AI MAL

```text
J’AI MAL
├── Tête
├── Ventre / corps
├── Gorge / respiration
└── Retour
```

### Sous-menu POSITION / INCONFORT

```text
POSITION / INCONFORT
├── Me redresser
├── Me tourner
├── Je suis mal installé
└── Retour
```

---

## 9.3 Menu CONVERSATION

```text
CONVERSATION
├── Je veux savoir...
├── Dis-moi...
├── Mode expert
└── Retour
```

### Sous-menu JE VEUX SAVOIR

```text
JE VEUX SAVOIR
├── Quelle heure est-il ?
├── Qui vient me voir ?
├── Que disent les médecins ?
└── Retour
```

### Sous-menu DIS-MOI

```text
DIS-MOI
├── Parle-moi
├── Raconte-moi quelque chose
├── Explique-moi ce qui se passe
└── Retour
```

---

## 9.4 Menu ÉMOTIONS / ÉTAT

```text
ÉMOTIONS / ÉTAT
├── Merci / Je t’aime
├── Fatigué / envie de dormir
├── Reste avec moi / ne t’en va pas
└── Retour
```

### Sous-menu FATIGUE

```text
FATIGUE
├── Je suis fatigué
├── Je veux dormir
├── Je veux du calme
└── Retour
```

---

## 9.5 Menu OPTIONS

```text
OPTIONS
├── Mode Oui / Non
├── Mode expert
├── Réglages
└── Retour
```

---

## 10. Règles de contenu

## 10.1 Limite stricte

Chaque écran doit contenir au maximum 4 choix.

## 10.2 Phrases courtes

Les phrases doivent être :

- courtes ;
- explicites ;
- faciles à comprendre ;
- lisibles rapidement ;
- adaptées au contexte hospitalier.

## 10.3 Pas de surcharge visuelle

Il ne faut pas afficher :

- trop de texte ;
- des sous-titres inutiles ;
- des animations agressives ;
- des icônes trop petites ;
- des listes longues ;
- du scroll obligatoire.

## 10.4 Personnalisation

L’aidant doit pouvoir personnaliser :

- les phrases ;
- les menus ;
- les libellés ;
- les durées de dwell time ;
- la voix utilisée ;
- le niveau de contraste ;
- les phrases prioritaires.

---

## 11. Spécifications techniques fonctionnelles

## 11.1 Séparation données / interface

Le contenu des menus ne doit pas être codé directement dans les composants UI.

Il doit être chargé depuis un fichier de configuration, idéalement :

```text
/app-content/menu-config.json
```

ou :

```text
/src/config/menu-config.json
```

## 11.2 Structure attendue du fichier JSON

Exemple recommandé :

```json
{
  "appName": "La Voix du Regard",
  "defaultDwellTimeMs": 1300,
  "homeScreenId": "home",
  "screens": [
    {
      "id": "home",
      "type": "grid-4",
      "title": "Accueil",
      "items": [
        {
          "zone": "top-left",
          "label": "🩺 PHYSIQUE",
          "action": "navigate",
          "target": "physical"
        },
        {
          "zone": "top-right",
          "label": "💬 CONVERSATION",
          "action": "navigate",
          "target": "conversation"
        },
        {
          "zone": "bottom-left",
          "label": "❤️ ÉMOTIONS / ÉTAT",
          "action": "navigate",
          "target": "emotions"
        },
        {
          "zone": "bottom-right",
          "label": "⚙️ OPTIONS",
          "action": "navigate",
          "target": "options"
        }
      ]
    },
    {
      "id": "physical",
      "type": "grid-4",
      "title": "Physique",
      "items": [
        {
          "zone": "top-left",
          "label": "J’ai soif / faim",
          "action": "speak",
          "text": "J’ai soif ou faim."
        },
        {
          "zone": "top-right",
          "label": "J’ai mal",
          "action": "navigate",
          "target": "pain"
        },
        {
          "zone": "bottom-left",
          "label": "Changer de position",
          "action": "navigate",
          "target": "position"
        },
        {
          "zone": "bottom-right",
          "label": "Retour",
          "action": "back"
        }
      ]
    }
  ]
}
```

---

## 12. Actions fonctionnelles disponibles

Chaque item de menu doit pouvoir déclencher une action.

Actions minimales attendues :

| Action | Description |
|---|---|
| `navigate` | Ouvre un autre écran |
| `speak` | Prononce une phrase via synthèse vocale |
| `back` | Retourne à l’écran précédent |
| `home` | Retourne à l’accueil |
| `openMode` | Ouvre un mode spécifique : oui/non, expert, réglages |
| `settings` | Ouvre les réglages |
| `cancel` | Annule l’action en cours |

---

## 13. Eye-tracking et sélection

## 13.1 Abstraction obligatoire

La logique d’eye-tracking doit être séparée de la logique d’interface.

Le code doit distinguer :

1. la détection brute du regard ;
2. la conversion en coordonnées écran ;
3. l’identification de la zone regardée ;
4. la gestion du dwell time ;
5. le déclenchement de l’action.

## 13.2 Exemple de flux fonctionnel

```text
Caméra frontale
→ Détection visage / iris
→ Coordonnées estimées du regard
→ Mapping vers zone écran
→ Vérification zone morte centrale
→ Démarrage dwell time
→ Validation action
→ Feedback visuel + synthèse vocale si nécessaire
```

## 13.3 Zones attendues

Les zones logiques principales sont :

```text
top-left
top-right
bottom-left
bottom-right
center-dead-zone
leftight
```

Les zones `left` et `right` sont utilisées pour le mode Oui / Non.

---

## 14. Synthèse vocale

## 14.1 Principe

Toute phrase finale validée doit être prononcée à voix haute par l’appareil.

## 14.2 Déclenchement

La synthèse vocale est déclenchée lorsque l’action est de type :

```text
speak
```

ou lorsqu’un mot ou une phrase est validé dans le mode expert.

## 14.3 Réglages souhaités

L’application doit prévoir, si possible :

- choix de la voix ;
- vitesse de lecture ;
- volume ;
- répétition de la dernière phrase ;
- activation / désactivation temporaire du son.

---

## 15. Design visuel

## 15.1 Contraste

L’interface doit être conçue pour un environnement hospitalier.

Recommandations :

- fond sombre : noir ou gris très foncé ;
- texte blanc ou jaune clair ;
- boutons très contrastés ;
- bordures visibles ;
- police très grande ;
- icônes simples.

## 15.2 Taille des textes

Les textes doivent être visibles à distance.

Les libellés courts doivent être privilégiés.

## 15.3 Couleurs recommandées

| Élément | Couleur recommandée |
|---|---|
| Fond | Noir / gris foncé |
| Texte principal | Blanc |
| Texte important | Jaune clair |
| Oui | Vert |
| Non | Rouge |
| Retour / Options | Bleu ou gris contrasté |
| Sélection en cours | Bordure lumineuse ou progression visible |

---

## 16. Paramètres configurables

L’application doit permettre de configurer :

| Paramètre | Valeur recommandée par défaut |
|---|---|
| Dwell time | 1300 ms |
| Zone morte centrale | 15 à 25 % du centre écran |
| Taille de police | Très grande |
| Thème | Sombre haut contraste |
| Synthèse vocale | Activée |
| Mode d’accueil | Besoins rapides |
| Sensibilité eye-tracking | Moyenne |

---

## 17. Comportements de sécurité

## 17.1 Éviter les validations accidentelles

L’application doit annuler la sélection si :

- le regard quitte la zone ;
- le visage n’est plus détecté ;
- le regard passe dans la zone morte ;
- plusieurs zones sont détectées de manière instable.

## 17.2 Confirmation des actions sensibles

Les actions sensibles doivent demander confirmation.

Exemples :

- quitter l’application ;
- réinitialiser les réglages ;
- supprimer une phrase personnalisée.

## 17.3 Mode dégradé

Si l’eye-tracking ne fonctionne pas correctement, l’application doit pouvoir fonctionner temporairement :

- au toucher ;
- avec l’aide d’un proche ;
- avec une sélection manuelle.

---

## 18. Parcours utilisateur principal

```text
1. Le patient ouvre les yeux devant la tablette.
2. L’application affiche l’accueil avec 4 grands choix.
3. Le patient regarde une zone.
4. La progression visuelle démarre.
5. Après validation, le sous-menu s’ouvre.
6. Le patient sélectionne une phrase ou un besoin.
7. L’application affiche et prononce la phrase.
8. Le patient peut revenir au menu précédent ou à l’accueil.
```

---

## 19. Critères d’acceptation fonctionnels

L’application est considérée conforme si :

- l’accueil contient exactement 4 zones principales ;
- aucun écran standard ne dépasse 4 choix ;
- le bas droite sert toujours à la navigation ou aux options ;
- la zone centrale ne déclenche aucune action ;
- le dwell time est paramétrable ;
- une progression visuelle apparaît pendant une sélection ;
- une phrase validée est prononcée à voix haute ;
- les menus sont chargés depuis un fichier de données ;
- le mode Oui / Non fonctionne avec 2 zones simples ;
- le mode expert permet une saisie libre minimale ;
- l’interface reste lisible en environnement sombre ou hospitalier ;
- l’application peut être utilisée sans clavier, souris ou matériel externe.

---

## 20. Priorisation MVP

## 20.1 Version MVP obligatoire

La première version doit contenir :

1. accueil en 4 quadrants ;
2. navigation entre menus ;
3. phrases préconfigurées ;
4. sélection par dwell time ;
5. feedback visuel ;
6. synthèse vocale ;
7. mode Oui / Non ;
8. configuration JSON simple.

## 20.2 Version suivante

La deuxième version peut ajouter :

- personnalisation des phrases dans l’application ;
- réglages avancés du dwell time ;
- meilleur calibrage eye-tracking ;
- répétition de la dernière phrase ;
- mode expert par balayage ;
- prédiction de mots.

## 20.3 Version avancée

La version avancée peut ajouter :

- profils patients ;
- export / import de configuration ;
- statistiques d’utilisation ;
- calibration personnalisée ;
- adaptation automatique à la fatigue ;
- suggestions contextuelles ;
- sauvegarde locale sécurisée.

---

## 21. Prompt recommandé pour Claude

```text
Bonjour Claude.

Voici le fichier de spécifications fonctionnelles de mon application de communication par le regard destinée à un proche hospitalisé.

L’application s’appelle "La Voix du Regard".

Je souhaite coder cette application en [TECHNOLOGIE À PRÉCISER : Flutter / React Native / HTML-CSS-JS / autre].

Prends connaissance de ce document comme référence fonctionnelle principale.

Pour commencer, propose-moi :
1. l’architecture technique globale du projet ;
2. la structure des dossiers ;
3. les composants principaux ;
4. le modèle JSON complet pour gérer les menus ;
5. une première implémentation de l’écran d’accueil en 4 quadrants.

Respecte strictement les contraintes suivantes :
- 4 choix maximum par écran ;
- zone morte au centre ;
- sélection par dwell time ;
- bouton retour en bas à droite ;
- synthèse vocale à chaque phrase finale ;
- séparation entre données, interface et logique d’eye-tracking.
```

---

## 22. Note de développement

Ce document est volontairement fonctionnel.

Il ne doit pas être considéré comme une architecture technique figée.

Le développeur ou l’assistant IA doit s’en servir comme source de vérité pour conserver la cohérence du produit, en particulier sur :

- l’ergonomie ;
- la simplicité ;
- la sécurité d’usage ;
- la hiérarchie des menus ;
- la limitation stricte à 4 choix ;
- la priorité donnée à la fatigue et au confort du patient.
