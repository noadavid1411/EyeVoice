# Architecture Decision Records — La Voix du Regard (EyeVoice)

Ce dossier consigne les décisions techniques structurantes du projet, au fur
et à mesure qu'elles sont prises et verrouillées (voir aussi `TASKS.md` à la
racine, qui liste les décisions verrouillées phase par phase).

Format court : contexte, décision, conséquences. Une ADR n'est jamais
réécrite après coup pour "corriger l'histoire" — si une décision change, on
ajoute une nouvelle ADR qui la remplace et on met à jour le statut de
l'ancienne.

| # | Titre | Statut |
|---|---|---|
| [0001](0001-riverpod.md) | Riverpod comme solution de state management | Accepté |
| [0002](0002-structure-dossiers.md) | Structure de dossiers en couches (`core`/`domain`/`eyetracking`/`services`/`data`/`ui`) | Accepté |
| [0003](0003-mediapipe-face-mesh.md) | `mediapipe_face_mesh` pour la détection visage/iris | Accepté (fiabilité à revalider sur appareil réel) |
