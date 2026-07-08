# Guide de personnalisation — aidant / soignant

Ce guide s'adresse à la personne (proche ou soignant) qui configure "La Voix
du Regard" pour un patient, avant ou pendant son utilisation. Il ne demande
aucune connaissance technique.

## Comment ouvrir les réglages

Depuis l'écran d'accueil (les 4 cases : Physique, Conversation, Émotions,
Options) :

1. Ouvrir **⚙️ OPTIONS** (case en bas à droite).
2. Ouvrir **Réglages**.

L'écran de réglages se pilote au **toucher** (pas avec les yeux) : il est
prévu pour être manipulé par vous, pas par le patient alité. Chaque
modification est appliquée et enregistrée immédiatement — il n'y a pas de
bouton "valider" à chercher.

Pour revenir à l'écran précédent, utiliser la flèche retour en haut à
gauche de l'écran de réglages.

---

## Réglages disponibles

### 1. Regard

Ces réglages contrôlent la façon dont l'application interprète le regard du
patient.

- **Temps de fixation** : durée pendant laquelle le patient doit fixer une
  case avant qu'elle ne soit validée. Réglable entre 800 ms (très rapide,
  plus de risque de sélection accidentelle) et 2000 ms (plus lent, plus
  sûr). Valeur de départ recommandée : autour de 1300 ms. Si le patient
  valide des cases par erreur en regardant simplement autour de lui,
  augmenter cette durée. S'il semble frustré d'attendre trop longtemps, la
  réduire.

- **Sensibilité eye-tracking** : Faible / Moyenne / Élevée. Ajuste la
  réactivité de la détection du regard aux petits mouvements des yeux. Si le
  patient a du mal à atteindre les coins de l'écran, essayer "Élevée". Si
  la sélection semble instable ou "saute" entre les cases, essayer
  "Faible".

- **Zone morte centrale** : taille (en %) de la zone neutre au centre de
  l'écran, où regarder ne déclenche jamais rien. Elle sert de "point de
  repos" pour les yeux du patient entre deux sélections. Une zone plus
  grande laisse plus de marge de repos mais réduit l'espace utile des
  cases ; une zone plus petite fait l'inverse.

### 2. Affichage

- **Taille de police** : Standard / Grande / Très grande. À augmenter si le
  patient est éloigné de l'écran ou a une vue fatiguée. "Très grande" est
  la valeur de départ recommandée en réanimation.

- **Contraste** : Standard / Élevé. Le contraste élevé (fond très sombre,
  texte très lumineux) est recommandé en environnement hospitalier, en
  particulier si la chambre est peu éclairée ou si le patient est
  photosensible.

### 3. Voix

- **Synthèse vocale activée** : active ou coupe la voix qui prononce les
  phrases et réponses sélectionnées par le patient. À couper temporairement
  si un soin est en cours et que le silence est préférable, sans perdre les
  autres réglages.

- **Débit de la voix** : vitesse à laquelle les phrases sont prononcées.
  Réduire si la voix semble trop rapide pour être bien comprise par les
  personnes présentes dans la chambre.

### 4. Mode d'accueil

- **Mode d'accueil** : écran affiché au démarrage de l'application. "Besoins
  rapides" (les 4 grandes catégories : Physique, Conversation, Émotions,
  Options) est le mode à utiliser aujourd'hui. "Expert" (saisie de mots
  lettre par lettre) est indiqué comme "bientôt" : il n'est pas encore
  disponible dans cette version de l'application.

### Réinitialiser les réglages

Un bouton **"Réinitialiser les réglages"** en bas de l'écran ramène tous les
réglages ci-dessus à leurs valeurs par défaut (recommandées pour un usage
hospitalier standard). Une confirmation est demandée avant d'appliquer la
réinitialisation, pour éviter un geste accidentel.

---

## Ce qui n'est pas encore personnalisable

À ce stade du projet, les éléments suivants **ne peuvent pas** être modifiés
depuis l'application elle-même (ils feront l'objet d'une prochaine version) :

- le texte des phrases proposées au patient (ex. "J'ai mal", "Je suis
  fatigué") ;
- l'organisation des menus (quelles catégories, quels sous-menus) ;
- l'ajout de phrases personnalisées propres au patient ;
- le choix d'une voix de synthèse vocale parmi plusieurs voix disponibles
  (seuls le débit et l'activation/désactivation sont réglables aujourd'hui).

## Conseils pratiques

- Faire un premier réglage avec le patient présent et conscient si
  possible, en observant sa réaction aux premières sélections (délai trop
  long/court, cases trop petites à lire).
- Revoir les réglages "Regard" si l'état du patient change (fatigue,
  amélioration, changement de position de l'appareil) : ces réglages ne
  sont pas figés, ils peuvent être ajustés à tout moment sans perdre les
  autres préférences.
- En cas de doute, "Réinitialiser les réglages" permet de repartir sur une
  base connue et testée plutôt que d'accumuler des ajustements peu clairs.
