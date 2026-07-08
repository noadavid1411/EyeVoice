import 'package:eyevoice/domain/models/menu_config_exception.dart';
import 'package:eyevoice/domain/models/menu_item.dart';

/// Un écran de `menu-config.json` (section 11.2) : un `id` unique, un
/// `title` affiché, et jusqu'à [MenuItem.length] items (la limite stricte
/// de 4 choix, section 4.1/10.1, est vérifiée par `validateMenuConfig`,
/// pas ici — voir `menu_config_validator.dart`).
class MenuScreen {
  /// Identifiant unique de l'écran, référencé par `homeScreenId` et par les
  /// items `navigate`/`target` d'autres écrans.
  final String id;

  /// Type de mise en page de l'écran. Seul `grid-4` est utilisé par le MVP
  /// (section 20.1) ; conservé en `String` plutôt qu'en enum fermé pour ne
  /// pas bloquer l'ajout futur d'un type d'écran (ex. Oui/Non, section 5)
  /// sans repasser par ce module.
  final String type;

  /// Titre affiché en tête de l'écran.
  final String title;

  /// Items sélectionnables de l'écran (max 4 — voir `validateMenuConfig`).
  final List<MenuItem> items;

  const MenuScreen({
    required this.id,
    required this.type,
    required this.title,
    required this.items,
  });

  factory MenuScreen.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final typeRaw = json['type'];
    final titleRaw = json['title'];
    final itemsRaw = json['items'];

    if (idRaw is! String || idRaw.isEmpty) {
      throw const MenuConfigParseException(
        "Écran invalide : champ 'id' manquant ou vide",
      );
    }
    if (typeRaw is! String || typeRaw.isEmpty) {
      throw MenuConfigParseException(
        "Écran '$idRaw' invalide : champ 'type' manquant ou vide",
      );
    }
    if (titleRaw is! String) {
      throw MenuConfigParseException(
        "Écran '$idRaw' invalide : champ 'title' manquant ou non textuel",
      );
    }
    if (itemsRaw is! List) {
      throw MenuConfigParseException(
        "Écran '$idRaw' invalide : champ 'items' manquant ou non tabulaire",
      );
    }

    final items = itemsRaw
        .map(
          (raw) => MenuItem.fromJson(raw as Map<String, dynamic>),
        )
        .toList(growable: false);

    return MenuScreen(id: idRaw, type: typeRaw, title: titleRaw, items: items);
  }

  @override
  String toString() =>
      'MenuScreen(id: $id, type: $type, title: $title, items: $items)';
}
