import 'package:flutter/material.dart';

/// ==========================================
/// APP TEXT FIELD - Reusable Input Component
/// ==========================================
/// A standardized text input widget used throughout the EaseInn app.
/// Supports common input patterns like:
/// - Regular text fields for names, emails, etc.
/// - Password fields with show/hide toggle
/// - Multi-line fields for descriptions/notes
/// - Validation via a validator function
/// - Prefix icons for visual context
///
/// This ensures all input fields look and behave consistently.
/// ==========================================
class AppTextField extends StatefulWidget {
  /// The label text shown above or inside the field (e.g., "Email", "Password")
  final String label;

  /// Optional controller for reading/managing the field's text value
  final TextEditingController? controller;

  /// Validation function - returns null if valid, or an error message string if invalid
  /// Called automatically when a Form is submitted
  final String? Function(String?)? validator;

  /// When true, masks the input (dots instead of characters).
  /// Automatically adds a show/hide toggle icon.
  final bool obscureText;

  /// The keyboard type to show on mobile (e.g., email, number, phone, text)
  final TextInputType keyboardType;

  /// The action button on the keyboard (e.g., next, done, search)
  final TextInputAction textInputAction;

  /// Optional icon displayed on the left side of the field
  final Widget? prefixIcon;

  /// Number of visible lines for the text field. Set > 1 for multi-line inputs
  /// (e.g., descriptions, notes, addresses)
  final int maxLines;

  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.prefixIcon,
    this.maxLines = 1,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  /// Local state to track whether the password is currently hidden or visible.
  /// Starts with the value of widget.obscureText and toggles when the eye icon is tapped.
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      maxLines: widget.maxLines,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.prefixIcon,
        // ==========================================
        // PASSWORD TOGGLE ICON
        // ==========================================
        // Only shown when obscureText is enabled (password fields).
        // Tapping toggles between visibility_off (hidden) and visibility (shown) icons.
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              )
            : null,
      ),
    );
  }
}
