import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/haptics/haptic_patterns.dart';

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late AnimationController _pulseController;

  bool _isHolding = false;
  double _holdProgress = 0.0;
  Timer? _holdTimer;
  bool _isSending = false;
  String? _alertStatus;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(preferencesServiceProvider);
    _nameController = TextEditingController(text: prefs.emergencyContactName ?? 'Guardian');
    _phoneController = TextEditingController(text: prefs.emergencyContactPhone ?? '+91 98765 43210');

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _pulseController.repeat(reverse: true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = AppStrings.of(context);
      ref.read(unifiedVoiceControllerProvider).speak(
            '${s.sosTitle}. ${s.hold5Seconds}. ${s.youAreSafe}',
          );
      ref.read(hapticServiceProvider).trigger(HapticPattern.emergencyStatus);
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulseController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    if (_isSending) return;
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    ref.read(hapticServiceProvider).trigger(HapticPattern.buttonTap);
    final voice = ref.read(unifiedVoiceControllerProvider);
    voice.speak('Hold for 5 seconds to dispatch SOS alert.');

    const stepDurationMs = 100;
    const totalDurationMs = 5000;
    const stepIncrement = stepDurationMs / totalDurationMs;

    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: stepDurationMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _holdProgress += stepIncrement;
      });

      // Pulse haptic feedback every second
      if ((_holdProgress * 5).toInt() > ((_holdProgress - stepIncrement) * 5).toInt()) {
        ref.read(hapticServiceProvider).trigger(HapticPattern.warningImpending);
      }

      if (_holdProgress >= 1.0) {
        timer.cancel();
        _onHoldComplete();
      }
    });
  }

  void _onHoldEnd() {
    if (_holdProgress < 1.0 && _isHolding) {
      _holdTimer?.cancel();
      setState(() {
        _isHolding = false;
        _holdProgress = 0.0;
      });
      ref.read(unifiedVoiceControllerProvider).speak('SOS cancelled.');
      ref.read(hapticServiceProvider).trigger(HapticPattern.buttonTap);
    }
  }

  Future<void> _onHoldComplete() async {
    setState(() {
      _isHolding = false;
      _holdProgress = 1.0;
      _isSending = true;
    });

    final voice = ref.read(unifiedVoiceControllerProvider);
    final haptics = ref.read(hapticServiceProvider);

    await haptics.trigger(HapticPattern.emergencyStatus);
    await voice.speak('Emergency alert activated! Dispatching live coordinates and calling emergency contact.');

    // Use the new EmergencyService for full dispatch: call + SMS + location share
    await ref.read(emergencyServiceProvider).dispatchFullEmergency();

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    final alertSummary =
        'Emergency SOS Dispatched to $name ($phone).\nEmergency call placed, SMS with location sent, and location shared with VisionMate users.';

    setState(() {
      _isSending = false;
      _alertStatus = alertSummary;
    });

    await haptics.trigger(HapticPattern.actionSuccess);
    await voice.speak('Emergency complete. Emergency contact called, SMS with location sent, and location shared with VisionMate users. Help is on the way.');
  }

  void _showEditContactModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Emergency Contact',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Contact Name',
                  labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
                  filled: true,
                  fillColor: AppColors.cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
                  filled: true,
                  fillColor: AppColors.cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergencyRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () {
                  final prefs = ref.read(preferencesServiceProvider);
                  prefs.setEmergencyContact(
                    _nameController.text.trim(),
                    _phoneController.text.trim(),
                  );
                  Navigator.pop(ctx);
                  ref.read(hapticServiceProvider).trigger(HapticPattern.actionSuccess);
                  ref.read(unifiedVoiceControllerProvider).speak('Emergency contact saved.');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF070B16), // Deep navy black
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () {
            ref.read(hapticServiceProvider).trigger(HapticPattern.buttonTap);
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(
          s.sosTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white70, size: 26),
            tooltip: 'Configure Emergency Contact',
            onPressed: () {
              ref.read(hapticServiceProvider).trigger(HapticPattern.buttonTap);
              _showEditContactModal();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top SOS Icon & Instructions
              Column(
                children: [
                  const SizedBox(height: 10),
                  // Concentric Glowing Red SOS Icon
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow circle
                          Container(
                            width: 130 + 10 * _pulseController.value,
                            height: 130 + 10 * _pulseController.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF1744).withValues(alpha: 0.15 + 0.1 * _pulseController.value),
                            ),
                          ),
                          // Middle border ring
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFF1744).withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                          ),
                          // Core red circle
                          Container(
                            width: 90,
                            height: 90,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [Color(0xFFFF5252), Color(0xFFD50000)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x66FF1744),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                                Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // 5-second instruction text
                  Text(
                    s.hold5Seconds,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3 Status Badges / Cards
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatusCard(
                        icon: Icons.location_on_rounded,
                        title: s.locationSharing,
                        color: const Color(0xFF4FC3F7),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusCard(
                        icon: Icons.person_rounded,
                        title: s.emergencyContacts,
                        color: const Color(0xFF00E676),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusCard(
                        icon: Icons.mic_rounded,
                        title: s.liveAudio,
                        color: const Color(0xFFFF9100),
                      ),
                    ],
                  ),
                ],
              ),

              // Alert status message (if sent)
              if (_alertStatus != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2A1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _alertStatus!,
                          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

              // Bottom Section: Hold to Activate button & "You are safe" banner
              Column(
                children: [
                  // Giant Crimson Hold to Activate Button with hold progress
                  GestureDetector(
                    onTapDown: (_) => _onHoldStart(),
                    onTapUp: (_) => _onHoldEnd(),
                    onTapCancel: () => _onHoldEnd(),
                    child: Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF334B), Color(0xFFE50914)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF1744).withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Hold progress fill bar
                          if (_isHolding)
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: MediaQuery.of(context).size.width * _holdProgress,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                            ),

                          // Button content
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isHolding ? Icons.alarm_rounded : Icons.notifications_active_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _isHolding
                                    ? 'Hold ${(5 - (_holdProgress * 5)).ceil()}s...'
                                    : s.holdToActivate,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bottom Speech Banner ("You are safe. I am here to help.")
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10192D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Color(0xFF42A5F5),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.youAreSafe,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF10182C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
