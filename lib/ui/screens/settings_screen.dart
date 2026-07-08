import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_defaults.dart';
import '../../data/settings_repository.dart';
import '../../domain/models/app_settings.dart';
import '../../eyetracking/models/gaze_sensitivity.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/confirmation_dialog.dart';

/// Écran de réglages configurables (SPECIFICATIONS_FONCTIONNELLES.md
/// section 16), ouvert depuis "Options → Réglages" (`sampleMenuConfig`,
/// action `settings`) — voir `MenuNavigationController.exitSettings` et
/// `UiMode.settings`.
///
/// Contrairement à `Grid4Screen`/`YesNoScreen`, cet écran n'est **pas**
/// piloté par le regard (pas de dwell time) : c'est un écran de
/// personnalisation à liste défilante, pensé pour être opéré au toucher par
/// l'aidant/le soignant (section 10.4), pas par le patient alité. Il reste
/// néanmoins construit sur le même thème sombre haut contraste que le reste
/// de l'application.
///
/// Chaque contrôle appelle immédiatement [SettingsController.update] : la
/// valeur est donc persistée sans délai (`SettingsRepository`,
/// `shared_preferences`) et propagée en temps réel au reste de
/// l'application — voir `gazeTrackingPipelineProvider`
/// (`lib/ui/providers/gaze_tracking_providers.dart`) pour dwell time/
/// sensibilité/zone morte, `MenuNavigationController`
/// (`lib/ui/providers/menu_navigation_controller.dart`) pour la synthèse
/// vocale, et `EyeVoiceApp` (`lib/main.dart`) pour la taille de police et le
/// contraste.
class SettingsScreen extends ConsumerWidget {
  /// Appelé pour quitter l'écran de réglages (retour à l'écran grid-4
  /// courant). `null` = aucune affordance de sortie affichée.
  final VoidCallback? onClose;

  const SettingsScreen({super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: onClose,
        ),
        title: const Text('Réglages'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _SectionTitle('Regard'),
          _SliderSetting(
            label: 'Temps de fixation',
            valueLabel: '${settings.eyeTracking.dwellTime.inMilliseconds} ms',
            value: settings.eyeTracking.dwellTime.inMilliseconds.toDouble(),
            min: 800,
            max: 2000,
            divisions: 12,
            onChanged: (v) => controller.update(
              (s) => s.copyWith(
                eyeTracking: s.eyeTracking.copyWith(
                  dwellTime: Duration(milliseconds: v.round()),
                ),
              ),
            ),
          ),
          _SegmentedSetting<GazeSensitivity>(
            label: 'Sensibilité eye-tracking',
            value: settings.eyeTracking.sensitivity,
            options: const {
              GazeSensitivity.low: 'Faible',
              GazeSensitivity.medium: 'Moyenne',
              GazeSensitivity.high: 'Élevée',
            },
            onChanged: (v) => controller.update(
              (s) => s.copyWith(eyeTracking: s.eyeTracking.copyWith(sensitivity: v)),
            ),
          ),
          _SliderSetting(
            label: 'Zone morte centrale',
            valueLabel: '${(settings.eyeTracking.centerDeadZoneRatio * 100).round()} %',
            value: settings.eyeTracking.centerDeadZoneRatio,
            min: AppDefaults.centerDeadZoneMinRatio,
            max: AppDefaults.centerDeadZoneMaxRatio,
            divisions: 10,
            onChanged: (v) => controller.update(
              (s) => s.copyWith(eyeTracking: s.eyeTracking.copyWith(centerDeadZoneRatio: v)),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Affichage'),
          _SegmentedSetting<AppFontSize>(
            label: 'Taille de police',
            value: settings.fontSize,
            options: const {
              AppFontSize.standard: 'Standard',
              AppFontSize.large: 'Grande',
              AppFontSize.extraLarge: 'Très grande',
            },
            onChanged: (v) => controller.update((s) => s.copyWith(fontSize: v)),
          ),
          _SegmentedSetting<AppContrastLevel>(
            label: 'Contraste',
            value: settings.contrastLevel,
            options: const {
              AppContrastLevel.standard: 'Standard',
              AppContrastLevel.high: 'Élevé',
            },
            onChanged: (v) => controller.update((s) => s.copyWith(contrastLevel: v)),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Voix'),
          _SwitchSetting(
            label: 'Synthèse vocale activée',
            value: !settings.tts.muted,
            onChanged: (v) => controller.update(
              (s) => s.copyWith(tts: s.tts.copyWith(muted: !v)),
            ),
          ),
          _SliderSetting(
            label: 'Débit de la voix',
            valueLabel: settings.tts.speechRate.toStringAsFixed(2),
            value: settings.tts.speechRate,
            min: 0.2,
            max: 0.8,
            divisions: 12,
            onChanged: (v) => controller.update(
              (s) => s.copyWith(tts: s.tts.copyWith(speechRate: v)),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Mode d’accueil'),
          _SegmentedSetting<HomeMode>(
            label: 'Mode d’accueil',
            value: settings.defaultHomeMode,
            options: const {
              HomeMode.quickNeeds: 'Besoins rapides',
              HomeMode.expert: 'Expert (bientôt)',
            },
            onChanged: (v) => controller.update((s) => s.copyWith(defaultHomeMode: v)),
          ),
          const SizedBox(height: 32),
          Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt, color: AppColors.danger),
              label: const Text(
                'Réinitialiser les réglages',
                style: TextStyle(color: AppColors.danger),
              ),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
              onPressed: () => _confirmReset(context, controller),
            ),
          ),
        ],
      ),
    );
  }

  /// Action sensible (section 17.2 : "réinitialiser les réglages") : passe
  /// par [ConfirmationDialog], poussé via `Navigator` puisque cette action
  /// est locale à cet écran (pas un `MenuItem` de `menu-config.json` — voir
  /// la doc de [ConfirmationDialog]). [SettingsController.resetToDefaults]
  /// n'est appelé qu'après confirmation explicite.
  Future<void> _confirmReset(BuildContext context, SettingsController controller) async {
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (dialogContext) => ConfirmationDialog(
          message: 'Réinitialiser tous les réglages ?',
          onConfirm: () => Navigator.of(dialogContext).pop(true),
          onCancel: () => Navigator.of(dialogContext).pop(false),
        ),
      ),
    );
    if (confirmed == true) {
      await controller.resetToDefaults();
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: AppTextStyles.screenTitle),
      );
}

class _SliderSetting extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label : $valueLabel',
            style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontSize: 20),
          ),
          Slider(
            // Défensif : une valeur persistée hors bornes (ex. réglage
            // stocké par une version antérieure) ne doit jamais faire
            // planter cet écran (voir la tolérance similaire de
            // `AppSettings.fromJson`) — seul l'affichage du curseur est
            // borné, `onChanged` continue de transmettre la vraie valeur
            // choisie par l'utilisateur.
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppColors.selectionGlow,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SegmentedSetting<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  const _SegmentedSetting({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontSize: 20),
          ),
          const SizedBox(height: 8),
          SegmentedButton<T>(
            segments: [
              for (final entry in options.entries)
                ButtonSegment<T>(value: entry.key, label: Text(entry.value)),
            ],
            selected: {value},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchSetting({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontSize: 20),
      ),
      value: value,
      activeThumbColor: AppColors.selectionGlow,
      onChanged: onChanged,
    );
  }
}
