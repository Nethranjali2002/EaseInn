import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

/// ==========================================
/// CHANGE PASSWORD SCREEN - Update Password
/// ==========================================
/// Allows authenticated users to change their password.
/// Requires the current password for verification before
/// accepting the new password.
///
/// After successful change, shows a success message and
/// navigates back to the previous screen.
/// ==========================================
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// ==========================================
  /// SUBMIT - Change Password
  /// ==========================================
  /// Validates the form, then calls the auth provider's changePassword method.
  /// On success, shows a SnackBar and pops back to the previous screen.
  /// ==========================================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authProvider.notifier).changePassword(
      _currentController.text,
      _newController.text,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // Listen for errors from the auth provider
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // ==========================================
                // PASSWORD FIELDS
                // ==========================================
                AppTextField(
                  label: 'Current Password',
                  controller: _currentController,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Current password is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'New Password',
                  controller: _newController,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'New password is required';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    if (v == _currentController.text) return 'New password must be different';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Confirm New Password',
                  controller: _confirmController,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if (v != _newController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ==========================================
                // SUBMIT BUTTON
                // ==========================================
                AppButton(
                  label: 'Change Password',
                  isLoading: auth.isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
