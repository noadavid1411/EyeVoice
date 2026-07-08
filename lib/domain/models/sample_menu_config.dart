import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/domain/actions/action_result.dart';
import 'package:eyevoice/domain/models/menu_action.dart';
import 'package:eyevoice/domain/models/menu_config.dart';
import 'package:eyevoice/domain/models/menu_item.dart';
import 'package:eyevoice/domain/models/menu_screen.dart';

/// Configuration de menus mockée en mémoire, construite directement (sans
/// passer par du JSON), reprenant l'arborescence de référence des sections
/// 9.1 à 9.5 de SPECIFICATIONS_FONCTIONNELLES.md (accueil, physique/douleur/
/// position, conversation, émotions, options).
///
/// Objectif de cette Phase 1a : fournir à l'`ActionResolver` (et à ses
/// tests) des données représentatives sans dépendre d'un chargement de
/// fichier réel — le vrai `menu-config.json` et son chargement (assets,
/// `lib/data`) sont hors périmètre de cette phase. Ce fixture peut aussi
/// servir de données mockées pour le `Grid4Screen` de flutter-ui-engineer
/// (Phase 1c) en attendant l'intégration réelle (Phase 2).
final MenuConfig sampleMenuConfig = MenuConfig(
  appName: 'La Voix du Regard',
  defaultDwellTimeMs: 1300,
  homeScreenId: 'home',
  screens: [
    const MenuScreen(
      id: 'home',
      type: 'grid-4',
      title: 'Accueil',
      items: [
        MenuItem(
          zone: ScreenZone.topLeft,
          label: '🩺 PHYSIQUE',
          action: MenuAction.navigate,
          target: 'physical',
        ),
        MenuItem(
          zone: ScreenZone.topRight,
          label: '💬 CONVERSATION',
          action: MenuAction.navigate,
          target: 'conversation',
        ),
        MenuItem(
          zone: ScreenZone.bottomLeft,
          label: '❤️ ÉMOTIONS / ÉTAT',
          action: MenuAction.navigate,
          target: 'emotions',
        ),
        MenuItem(
          zone: ScreenZone.bottomRight,
          label: '⚙️ OPTIONS',
          action: MenuAction.navigate,
          target: 'options',
        ),
      ],
    ),
    const MenuScreen(
      id: 'physical',
      type: 'grid-4',
      title: 'Physique',
      items: [
        MenuItem(
          zone: ScreenZone.topLeft,
          label: 'J’ai soif / faim',
          action: MenuAction.speak,
          text: 'J’ai soif ou faim.',
        ),
        MenuItem(
          zone: ScreenZone.topRight,
          label: 'J’ai mal',
          action: MenuAction.navigate,
          target: 'pain',
        ),
        MenuItem(
          zone: ScreenZone.bottomLeft,
          label: 'Changer de position',
          action: MenuAction.navigate,
          target: 'position',
        ),
        MenuItem(
          zone: ScreenZone.bottomRight,
          label: 'Retour',
          action: MenuAction.back,
        ),
      ],
    ),
    const MenuScreen(
      id: 'pain',
      type: 'grid-4',
      title: 'J’ai mal',
      items: [
        MenuItem(
          zone: ScreenZone.topLeft,
          label: 'Tête',
          action: MenuAction.speak,
          text: 'J’ai mal à la tête.',
        ),
        MenuItem(
          zone: ScreenZone.topRight,
          label: 'Ventre / corps',
          action: MenuAction.speak,
          text: 'J’ai mal au ventre ou au corps.',
        ),
        MenuItem(
          zone: ScreenZone.bottomLeft,
          label: 'Gorge / respiration',
          action: MenuAction.speak,
          text: 'J’ai mal à la gorge ou pour respirer.',
        ),
        MenuItem(
          zone: ScreenZone.bottomRight,
          label: 'Retour',
          action: MenuAction.back,
        ),
      ],
    ),
    const MenuScreen(
      id: 'position',
      type: 'grid-4',
      title: 'Position / inconfort',
      items: [
        MenuItem(
          zone: ScreenZone.topLeft,
          label: 'Me redresser',
          action: MenuAction.speak,
          text: 'Je veux me redresser.',
        ),
        MenuItem(
          zone: ScreenZone.topRight,
          label: 'Me tourner',
          action: MenuAction.speak,
          text: 'Je veux me tourner.',
        ),
        MenuItem(
          zone: ScreenZone.bottomLeft,
          label: 'Je suis mal installé',
          action: MenuAction.speak,
          text: 'Je suis mal installé.',
        ),
        MenuItem(
          zone: ScreenZone.bottomRight,
          label: 'Retour',
          action: MenuAction.back,
        ),
      ],
    ),
    const MenuScreen(
      id: 'conversation',
      type: 'grid-4',
      title: 'Conversation',
      items: [
        MenuItem(
          zone: ScreenZone.topLeft,
          label: 'Je veux savoir...',
          action: MenuAction.speak,
          text: 'Je veux savoir quelque chose.',
        ),
        MenuItem(
          zone: ScreenZone.topRight,
          label: 'Dis-moi...',
          action: MenuAction.speak,
          text: 'Dis-moi quelque chose.',
        ),
        MenuItem(
          zone: ScreenZone.bottomLeft,
          label: 'Mode expert',
          action: MenuAction.openMode,
          target: 'expert',
          mode: AppMode.expert,
        ),
        MenuItem(
          zone: ScreenZone.bottomRight,
          label: 'Retour',
          action: MenuAction.back,
        ),
      ],
    ),
    const MenuScreen(
      id: 'emotions',
      type: 'grid-4',
      title: 'Émotions / État',
      items: [
        MenuItem(
          zone: ScreenZone.topLeft,
          label: 'Merci / Je t’aime',
          action: MenuAction.speak,
          text: 'Merci, je t’aime.',
        ),
        MenuItem(
          zone: ScreenZone.topRight,
          label: 'Fatigué / envie de dormir',
          action: MenuAction.speak,
          text: 'Je suis fatigué, j’ai envie de dormir.',
        ),
        MenuItem(
          zone: ScreenZone.bottomLeft,
          label: 'Reste avec moi',
          action: MenuAction.speak,
          text: 'Reste avec moi, ne t’en va pas.',
        ),
        MenuItem(
          zone: ScreenZone.bottomRight,
          label: 'Retour',
          action: MenuAction.back,
        ),
      ],
    ),
    const MenuScreen(
      id: 'options',
      type: 'grid-4',
      title: 'Options',
      items: [
        MenuItem(
          zone: ScreenZone.topLeft,
          label: 'Mode Oui / Non',
          action: MenuAction.openMode,
          target: 'yes-no',
          mode: AppMode.yesNo,
        ),
        MenuItem(
          zone: ScreenZone.topRight,
          label: 'Mode expert',
          action: MenuAction.openMode,
          target: 'expert',
          mode: AppMode.expert,
        ),
        MenuItem(
          zone: ScreenZone.bottomLeft,
          label: 'Réglages',
          action: MenuAction.settings,
        ),
        MenuItem(
          zone: ScreenZone.bottomRight,
          label: 'Retour',
          action: MenuAction.back,
        ),
      ],
    ),
  ],
);
