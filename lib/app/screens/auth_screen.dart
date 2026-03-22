import 'package:flutter/material.dart';

import 'home_screen.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/onboarding_shell.dart';
import 'style_preference_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  late final AuthViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AuthViewModel();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final result = await _viewModel.submit(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      username: _usernameController.text.trim(),
      fullName: _fullNameController.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );

    if (!result.success) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => result.shouldShowStylePreference
            ? const StylePreferenceScreen()
            : const HomeScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return Scaffold(
          body: AppViewport(
            child: AppPanel(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              borderRadius: 0,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      'Stylex',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0A7A76),
                        letterSpacing: -1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'THE DIGITAL ATELIER',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 3.2,
                        color: const Color(0xFF758284),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          SegmentedToggle(
                            leftLabel: 'Login',
                            rightLabel: 'Sign Up',
                            isLeftSelected: _viewModel.isLogin,
                            onChanged: (value) {
                              _viewModel.setAuthMode(
                                value ? AuthMode.login : AuthMode.signUp,
                              );
                            },
                          ),
                          const SizedBox(height: 22),
                          const FieldLabel('Email Address'),
                          const SizedBox(height: 8),
                          StyledInput(
                            controller: _emailController,
                            hintText: 'curator@stylex.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return 'Enter your email address.';
                              final emailPattern =
                                  RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                              if (!emailPattern.hasMatch(email)) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(child: FieldLabel('Password')),
                              Text(
                                'FORGOT?',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: const Color(0xFF0A7A76),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          StyledInput(
                            controller: _passwordController,
                            hintText: '********',
                            icon: Icons.lock_outline,
                            trailing: Icons.visibility_outlined,
                            obscureText: true,
                            validator: (value) {
                              final password = value ?? '';
                              if (password.isEmpty) return 'Enter your password.';
                              if (!_viewModel.isLogin && password.length < 6) {
                                return 'Use at least 6 characters.';
                              }
                              return null;
                            },
                          ),
                          if (!_viewModel.isLogin) ...[
                            const SizedBox(height: 16),
                            const FieldLabel('Full Name'),
                            const SizedBox(height: 8),
                            StyledInput(
                              controller: _fullNameController,
                              hintText: 'Style Curator',
                              icon: Icons.badge_outlined,
                              validator: (value) {
                                final fullName = value?.trim() ?? '';
                                if (fullName.isEmpty) {
                                  return 'Enter your full name.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            const FieldLabel('Create Your Username'),
                            const SizedBox(height: 8),
                            StyledInput(
                              controller: _usernameController,
                              hintText: 'style.curator',
                              icon: Icons.person_outline,
                              validator: (value) {
                                final username = value?.trim() ?? '';
                                if (username.isEmpty) {
                                  return 'Choose a username.';
                                }
                                if (username.length < 3) {
                                  return 'Username must be at least 3 characters.';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed:
                                  _viewModel.isSubmitting ? null : _handleSubmit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0A7A76),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: _viewModel.isSubmitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _viewModel.isLogin
                                          ? 'Login to Stylex'
                                          : 'Create Stylex Account',
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _viewModel.isSubmitting
                                  ? null
                                  : _viewModel.toggleAuthMode,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0A7A76),
                                side: const BorderSide(
                                  color: Color(0xFFD6E6E3),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                _viewModel.isLogin
                                    ? 'Create New Account'
                                    : 'Back to Login',
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(color: Color(0xFFD7E4E1)),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR CONTINUE WITH',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF93A2A2),
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(color: Color(0xFFD7E4E1)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Row(
                            children: [
                              Expanded(
                                child: SocialButton(
                                  icon: Icons.circle_outlined,
                                  label: 'Google',
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: SocialButton(
                                  icon: Icons.facebook_outlined,
                                  label: 'Facebook',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text.rich(
                      TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF81908F),
                          height: 1.5,
                        ),
                        children: const [
                          TextSpan(text: 'By continuing, you agree to our '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: Color(0xFF0A7A76),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: Color(0xFF0A7A76),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: '.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
