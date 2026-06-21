import 'package:flutter/material.dart';



/// ==========================================
/// WEB FORM FIELD - Reusable Labeled Text Input
/// ==========================================
/// A standardized text input field used across all web forms.
/// Wraps TextFormField with consistent styling and label.
///
/// Features:
/// - Label text above the field
/// - Optional validation
/// - Configurable keyboard type and line count
/// - Suffix/prefix icons support
///
/// Usage:
///   WebFormField(
///     label: 'Property Name *',
///     controller: nameController,
///     validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
///   )
/// ==========================================
class WebFormField extends StatelessWidget {
  /// Label displayed above the field
  final String label;

  /// Controller for the text input
  final TextEditingController? controller;

  /// Validation function (returns error string or null)
  final String? Function(String?)? validator;

  /// Keyboard type (text, number, email, etc.)
  final TextInputType keyboardType;

  /// Number of visible lines (1 = single line, >1 = multiline)
  final int maxLines;

  /// Widget displayed at the end of the field
  final Widget? suffixIcon;

  /// Widget displayed at the start of the field
  final Widget? prefix;

  /// Whether the field is enabled for input
  final bool enabled;

  /// Initial value (use instead of controller for uncontrolled fields)
  final String? initialValue;

  /// When to trigger validation (onUserInteraction = validate as user types)
  final AutovalidateMode autovalidateMode;

  const WebFormField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.suffixIcon,
    this.prefix,
    this.enabled = true,
    this.initialValue,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        initialValue: initialValue,
        autovalidateMode: autovalidateMode,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: suffixIcon,
          prefix: prefix,
        ),
      ),
    );
  }
}


