import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

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
                const Icon(Icons.password, size: 64, color: Color(0xFF1B5E20)),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Current Password',
                  controller: _currentController,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'New Password',
                  controller: _newController,
                  validator: (v) {
                    if (v == null || v.length < 8) return 'Must be at least 8 characters';
                    return null;
                  },
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_reset),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Confirm New Password',
                  controller: _confirmController,
                  validator: (v) {
                    if (v != _newController.text) return 'Passwords do not match';
                    return null;
                  },
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Change Password',
                  onPressed: _submit,
                  isLoading: auth.isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
