import 'package:flutter/material.dart';

/// Accessibility wrapper ensuring TalkBack / VoiceOver receive explicit labels, hints, and roles.
class AccessibleSemanticWrapper extends StatelessWidget {
  final Widget child;
  final String label;
  final String? hint;
  final String? value;
  final bool isButton;
  final bool isHeader;
  final bool? isSelected;
  final VoidCallback? onTap;

  const AccessibleSemanticWrapper({
    super.key,
    required this.child,
    required this.label,
    this.hint,
    this.value,
    this.isButton = false,
    this.isHeader = false,
    this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: isButton,
      header: isHeader,
      selected: isSelected,
      onTap: onTap,
      excludeSemantics: true, // Prevents reading child decorative elements separately
      child: child,
    );
  }
}
