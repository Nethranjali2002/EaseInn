import 'package:flutter/material.dart';

/// ==========================================
/// WEB FORM DIALOG - Reusable Modal Form Container
/// ==========================================
/// A standardized modal dialog for forms throughout the web admin portal.
/// Provides a consistent layout with:
/// - Title bar with close button
/// - Scrollable content area (for long forms)
/// - Cancel/Save buttons at the bottom
/// - Loading state support (disables buttons during API calls)
///
/// Usage:
///   await WebFormDialog.show(
///     context: context,
///     title: 'Create Property',
///     onSubmit: () => _saveProperty(),
///     child: MyPropertyForm(),
///   );
/// ==========================================
class WebFormDialog extends StatelessWidget {
  /// The title displayed at the top of the dialog
  final String title;

  /// The form content widget (usually a Column of TextFormFields)
  final Widget child;

  /// Callback when the Save button is tapped
  final VoidCallback? onSubmit;

  /// When true, shows a loading spinner on the Save button and disables it
  final bool isLoading;

  /// Maximum width of the dialog (default 520px)
  final double width;

  const WebFormDialog({
    super.key,
    required this.title,
    required this.child,
    this.onSubmit,
    this.isLoading = false,
    this.width = 520,
  });

  /// ==========================================
  /// show() - Static Helper to Display the Dialog
  /// ==========================================
  /// Convenience method to show the dialog without creating the widget manually.
  /// Returns true if Save was tapped, false if Cancel was tapped.
  ///
  /// Example:
  ///   final saved = await WebFormDialog.show(
  ///     context: context,
  ///     title: 'Edit Room',
  ///     onSubmit: () => saveRoom(),
  ///     child: RoomForm(),
  ///   );
  ///   if (saved) Navigator.pop(context);
  /// ==========================================
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required Widget child,
    VoidCallback? onSubmit,
    bool isLoading = false,
    double width = 520,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => WebFormDialog(
        title: title,
        onSubmit: onSubmit,
        isLoading: isLoading,
        width: width,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // TITLE BAR - Title + Close Button
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const Divider(),

              // ==========================================
              // SCROLLABLE CONTENT AREA
              // ==========================================
              // Flexible + SingleChildScrollView allows the form to scroll
              // when it's taller than the available dialog space.
              Flexible(child: SingleChildScrollView(child: child)),
              const SizedBox(height: 24),

              // ==========================================
              // ACTION BUTTONS - Cancel + Save
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: isLoading
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: isLoading ? null : onSubmit,
                    child: isLoading
                        ? // Show spinner while API call is in progress
                        const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

/// ==========================================
/// WEB FORM DROPDOWN - Reusable Labeled Dropdown
/// ==========================================
/// A standardized dropdown select used across all web forms.
/// Wraps DropdownButtonFormField with consistent styling and label.
///
/// Usage:
///   WebFormDropdown<RoomType>(
///     label: 'Room Type',
///     value: selectedType,
///     items: roomTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
///     onChanged: (v) => setState(() => selectedType = v),
///   )
/// ==========================================
class WebFormDropdown<T> extends StatelessWidget {
  /// Label displayed above the dropdown
  final String label;

  /// Currently selected value
  final T? value;

  /// List of dropdown items
  final List<DropdownMenuItem<T>> items;

  /// Callback when selection changes
  final void Function(T?) onChanged;

  /// Validation function
  final String? Function(T?)? validator;

  const WebFormDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
