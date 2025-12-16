import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/biometric_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  bool _isTutor = false;
  bool _isRememberMe = false; // Default off

  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        // Save biometric preference
        if (_isRememberMe) {
          await biometricService.setBiometricEnabled(true);
        } else {
          await biometricService.setBiometricEnabled(false);
        }
      } else {
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          data: {
            'full_name': _fullNameController.text,
            'address': _addressController.text,
            'is_tutor': _isTutor,
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Check your email for the confirmation link!'),
                backgroundColor: Colors.green),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.bold),
          prefixIcon:
              Icon(icon, color: theme.primaryColor.withOpacity(0.8), size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.2),
                      blurRadius: 40,
                      spreadRadius: 10,
                    )
                  ],
                ),
                child: Icon(
                  Icons.hub_rounded,
                  size: 80,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Nerd Herd',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                  color: theme.textTheme.displayMedium?.color,
                ),
              ),
              Text(
                'Academic velocity.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodyLarge?.color?.withOpacity(0.5),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),

              // Auth Card
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _isLogin ? 'Welcome Back' : 'Create Account',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildTextField(
                          controller: _emailController,
                          label: 'EMAIL',
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _passwordController,
                          label: 'PASSWORD',
                          icon: Icons.lock_outline,
                          obscureText: true,
                        ),
                        if (_isLogin) ...[
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            title: Text("Remember Me (Biometrics)",
                                style: theme.textTheme.bodyMedium),
                            value: _isRememberMe,
                            activeColor: theme.primaryColor,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) {
                              setState(() => _isRememberMe = val ?? false);
                            },
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _fullNameController,
                            label: 'FULL NAME',
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _addressController,
                            label: 'CAMPUS / ADDRESS',
                            icon: Icons.home_outlined,
                          ),
                          const SizedBox(height: 20),
                          SwitchListTile.adaptive(
                            title: Text('Register as Tutor?',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            value: _isTutor,
                            activeColor: theme.primaryColor,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setState(() => _isTutor = val),
                          ),
                        ],
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    _isLogin ? 'Log In' : 'Sign Up',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {
                            setState(() => _isLogin = !_isLogin);
                          },
                          child: Text(
                            _isLogin
                                ? 'New here? Create account'
                                : 'Already have an account? Log In',
                            style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
