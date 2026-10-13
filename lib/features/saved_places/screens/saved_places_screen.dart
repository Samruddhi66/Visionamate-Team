import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../app/theme/accessibility_tokens.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/widgets/accessible_action_button.dart';

class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(unifiedVoiceControllerProvider);
    final haptics = ref.watch(hapticServiceProvider);
    final savedRepo = ref.watch(savedPlacesRepositoryProvider);
    final savedPlaces = savedRepo.getSavedPlaces();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: const Text('Saved Places', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: savedPlaces.length,
        separatorBuilder: (_, _) => const SizedBox(height: AccessibilityTokens.spaceM),
        itemBuilder: (context, index) {
          final place = savedPlaces[index];
          return Card(
            color: AppColors.cardDark,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: AppColors.surfaceDark,
                child: Icon(Icons.place_rounded, color: AppColors.primaryCyan),
              ),
              title: Text(
                place.name,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16),
              ),
              subtitle: Text(
                place.address,
                style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13.5),
              ),
              trailing: AccessibleActionButton(
                label: 'Go',
                icon: Icons.directions_walk_rounded,
                backgroundColor: AppColors.accentViolet,
                foregroundColor: Colors.white,
                minHeight: 44,
                onPressed: () {
                  haptics.trigger(HapticPattern.lightTap);
                  context.push('/navigation', extra: place.name);
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryCyan,
        foregroundColor: AppColors.backgroundDark,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Current Place', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          haptics.trigger(HapticPattern.actionSuccess);
          voice.speak('GPS location acquired. Place saved.');
        },
      ),
    );
  }
}
