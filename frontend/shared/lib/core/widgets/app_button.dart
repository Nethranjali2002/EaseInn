import 'package:flutter/material.dart';

/// ==========================================
/// APP BUTTON - Reusable Button Component
/// ==========================================
/// A standardized button widget used throughout the EaseInn app.
/// Instead of creating buttons from scratch in every screen, we use this
/// consistent component that supports:
///
/// - Normal state: Clickable with a label
/// - Loading state: Shows a spinner and disables taps
/// - Outlined variant: For secondary/ghost actions
///
/// This ensures all buttons look and behave the same across the app.
/// ==========================================
class AppButton extends StatelessWidget {
  /// The text displayed on the button (e.g., "Login", "Save", "Delete")
  final String label;

  /// Callback function when the button is tapped. Null means the button is disabled.
  final VoidCallback? onPressed;

  /// When true, shows a loading spinner and prevents taps.
  /// Used during API calls to prevent duplicate submissions.
  final bool isLoading;

  /// When true, renders as an outlined button instead of filled.
  /// Used for secondary actions (e.g., "Cancel" alongside a primary "Save" button).
  final bool isOutlined;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    // ==========================================
    // OUTLINED BUTTON VARIANT
    // ==========================================
    // Used for secondary actions - transparent background with a border
    if (isOutlined) {
      return OutlinedButton(
        // Disable button while loading to prevent duplicate API calls
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48), // Full width, 48px height
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? // Show a compact spinner while loading
            const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      );
    }

    // ==========================================
    // PRIMARY (FILLED) BUTTON VARIANT
    // ==========================================
    // The default button - solid green background with white text
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? // White spinner for contrast against the green background
          const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}
