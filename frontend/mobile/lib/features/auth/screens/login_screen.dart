import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

/// ==========================================
/// LOGIN SCREEN - Staff Authentication
/// ==========================================
/// The login screen for the mobile staff app.
/// Handles email/password authentication with:
/// - Form validation (email format, password length)
/// - Loading state during API calls
/// - Error display via SnackBar
/// - Role enforcement (staff only)
///
/// After successful login:
/// - Staff users -> redirected to /tasks
/// - Non-staff users -> logged out with error message
/// ==========================================
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// Form key for validating input fields
  final _formKey = GlobalKey<FormState>();

  /// Controllers for the text input fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// ==========================================
  /// VALIDATORS - Input Validation Rules
  /// ==========================================
  /// Email must be in valid format (name@domain.com).
  /// Password must be at least 6 characters.
  /// ==========================================
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  /// ==========================================
  /// LOGIN - Submit Credentials
  /// ==========================================
  /// Validates the form, then calls the auth provider's login method.
  /// The listener on authProvider handles navigation and error display.
  /// ==========================================
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // ==========================================
    // AUTH STATE LISTENER - Handle Login Results
    // ==========================================
    // Listens for auth state changes and reacts accordingly:
    // - Successful login: navigate to tasks or show role error
    // - Error: display error message in SnackBar
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.isAuthenticated) {
        // ==========================================
        // ROLE ENFORCEMENT - Staff Only
        // ==========================================
        if (next.user?.role != 'staff') {
          ref.read(authProvider.notifier).logout();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access denied. Only Staff roles are permitted on the mobile application.'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          context.go('/tasks');
        }
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ==========================================
                  // BRANDING - Logo and Title
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hotel,
                      size: 48,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'EaseInn Staff',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to your account',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),

                  // ==========================================
                  // FORM FIELDS - Email and Password
                  // ==========================================
                  AppTextField(
                    label: 'Email',
                    controller: _emailController,
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Password',
                    controller: _passwordController,
                    validator: _validatePassword,
                    obscureText: true,
                    prefixIcon: const Icon(Icons.lock_outlined),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 8),

                  // ==========================================
                  // FORGOT PASSWORD LINK
                  // ==========================================
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/forgot-password'),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ==========================================
                  // LOGIN BUTTON
                  // ==========================================
                  AppButton(
                    label: 'Sign In',
                    isLoading: auth.isLoading,
                    onPressed: _login,
                  ),
                  const SizedBox(height: 16),

                  // ==========================================
                  // REGISTER LINK
                  // ==========================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Register'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
