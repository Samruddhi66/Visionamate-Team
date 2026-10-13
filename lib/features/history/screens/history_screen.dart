import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../app/theme/accessibility_tokens.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/haptics/haptic_patterns.dart';
import '../../../core/widgets/accessible_confirmation_dialog.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(unifiedVoiceControllerProvider);
    final haptics = ref.watch(hapticServiceProvider);
    final historyRepo = ref.watch(historyRepositoryProvider);
    final historyItems = historyRepo.getHistory();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: const Text('Activity History', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.emergencyRed),
            tooltip: 'Clear history list',
            onPressed: () async {
              final confirmed = await AccessibleConfirmationDialog.show(
                context,
                title: 'Clear Activity History?',
                message: 'This will remove all saved scans and navigation records.',
                confirmLabel: 'Clear All',
                isDestructive: true,
                hapticService: haptics,
              );
              if (confirmed == true) {
                await historyRepo.clearHistory();
                voice.speak('History cleared.');
              }
            },
          ),
        ],
      ),
      body: historyItems.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history_toggle_off_rounded, color: AppColors.primaryCyan, size: 36),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No Activity History Yet',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Scanned scenes, detected objects, recognized banknotes, and read text will be recorded here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: historyItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: AccessibilityTokens.spaceM),
              itemBuilder: (context, index) {
                final item = historyItems[index];
                return Card(
                  color: AppColors.cardDark,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: AppColors.primaryCyan, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(item.content, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 14)),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryCyan),
                      tooltip: 'Read item aloud',
                      onPressed: () {
                        haptics.trigger(HapticPattern.lightTap);
                        voice.speak('${item.title}. ${item.content}');
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
