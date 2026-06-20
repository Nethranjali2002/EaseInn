import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

/// ==========================================
/// FORGOT PASSWORD SCREEN - Request Reset Email
/// ==========================================
/// Allows users to request a password reset email.
/// After submitting their email, shows a confirmation message
/// telling them to check their inbox for the reset link.
/// ==========================================
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// ==========================================
  /// SUBMIT - Request Password Reset
  /// ==========================================
  /// Sends the email to the backend, which triggers a reset email.
  /// On success, shows the confirmation view.
  /// ==========================================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authProvider.notifier).forgotPassword(_emailController.text.trim());
    if (success && mounted) {
      setState(() => _emailSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _emailSent
              ? // ==========================================
                // SUCCESS VIEW - Email Sent Confirmation
                // ==========================================
                Column(
                  children: [
                    const Icon(Icons.mark_email_read, size: 64, color: Color(0xFF4CAF50)),
                    const SizedBox(height: 16),
                    const Text('Check Your Email', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'We\'ve sent a password reset link to ${_emailController.text}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Back to Login',
                      onPressed: () => context.go('/login'),
                    ),
                  ],
                )
              : // ==========================================
                // FORM VIEW - Enter Email
                // ==========================================
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Icon(Icons.lock_outlined, size: 64, color: Color(0xFF1B5E20)),
                      const SizedBox(height: 16),
                      const Text('Forgot Password?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your email and we\'ll send you a reset link',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      AppTextField(
                        label: 'Email',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Send Reset Link',
                        isLoading: auth.isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Back to Login'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
