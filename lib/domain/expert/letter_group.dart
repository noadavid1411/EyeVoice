import 'package:eyevoice/core/constants/app_defaults.dart';
import 'package:eyevoice/core/models/screen_zone.dart';

/// Groupes de lettres de l'étape 1 du mode expert
/// (SPECIFICATIONS_FONCTIONNELLES.md section 8.3).
///
/// L'écran d'entrée du mode expert affiche 4 zones (grille 4 zones
/// habituelle) : chacune correspond à un groupe de lettres contigu. La
/// couche `ui` met successivement chaque zone en surbrillance (balayage
/// temporel) ; ce modèle ne fait qu'exposer la donnée statique (quelles
/// lettres, quelle zone), pas la temporisation ni le rendu.
///
/// | Zone | Groupe |
/// |---|---|
/// | Haut gauche | A-F |
/// | Haut droite | G-L |
/// | Bas gauche | M-R |
/// | Bas droite | S-Z |
enum LetterGroup {
  aToF(ScreenZone.topLeft, ['A', 'B', 'C', 'D', 'E', 'F']),
  gToL(ScreenZone.topRight, ['G', 'H', 'I', 'J', 'K', 'L']),
  mToR(ScreenZone.bottomLeft, ['M', 'N', 'O', 'P', 'Q', 'R']),
  sToZ(ScreenZone.bottomRight, ['S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z']);

  const LetterGroup(this.zone, this.letters);

  /// Zone de la grille 4 zones associée à ce groupe pour l'écran de choix
  /// de groupe (étape 1, section 8.3).
  ///
  /// La spec note que la zone bas-droite peut afficher "Retour selon
  /// contexte" à la place du groupe [sToZ] sur certains écrans dérivés
  /// (ex. lorsqu'un item "Retour au menu principal" doit rester accessible
  /// — section 8.6). Ce choix d'affichage contextuel revient à la couche
  /// `ui` qui compose l'écran, pas à ce modèle de données : ce champ
  /// donne uniquement le placement par défaut.
  final ScreenZone zone;

  /// Lettres appartenant à ce groupe, en majuscule et par ordre
  /// alphabétique.
  final List<String> letters;

  /// Découpe [letters] en pages d'au plus [pageSize] éléments, pour
  /// respecter la règle des 4 choix par écran lors de l'étape 2 de choix
  /// de la lettre (section 8.4, qui autorise explicitement "sous-groupes
  /// ou pages successives").
  ///
  /// Par défaut, [pageSize] vaut [AppDefaults.maxChoicesPerScreen] (4).
  /// Chaque groupe contient 6 ou 8 lettres, donc avec la taille par défaut
  /// : [aToF]/[gToL]/[mToR] produisent 2 pages de 4 puis 2 lettres, et
  /// [sToZ] produit 2 pages égales de 4 lettres. Une UI qui veut réserver
  /// un emplacement de page pour un item de navigation ("page
  /// suivante"/"retour") peut passer un [pageSize] plus petit (ex. 3).
  List<List<String>> lettersPaged({
    int pageSize = AppDefaults.maxChoicesPerScreen,
  }) {
    if (pageSize <= 0) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'doit être strictement positif',
      );
    }
    final pages = <List<String>>[];
    for (var i = 0; i < letters.length; i += pageSize) {
      final end = (i + pageSize > letters.length) ? letters.length : i + pageSize;
      pages.add(letters.sublist(i, end));
    }
    return pages;
  }

  /// Trouve le groupe contenant [letter] (une seule lettre, insensible à
  /// la casse), ou `null` si [letter] n'est pas une lettre A-Z simple.
  static LetterGroup? groupOf(String letter) {
    if (letter.length != 1) return null;
    final upper = letter.toUpperCase();
    for (final group in LetterGroup.values) {
      if (group.letters.contains(upper)) return group;
    }
    return null;
  }
}
