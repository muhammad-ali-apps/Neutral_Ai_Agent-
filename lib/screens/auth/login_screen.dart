import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../widgets/home_shell.dart';
import 'auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import '../../services/api_services.dart';
import 'package:go_router/go_router.dart';


/// Login screen with form validation.
class LoginScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  const LoginScreen({super.key, required this.isDarkMode, required this.onToggleTheme});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);

    bool success = await ApiService.loginUser(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;
    
    setState(() => _loading = false);
    print("user success : $success");
    if (success) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Please check your credentials.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthLogo(),
            const SizedBox(height: 26),
            Text('Welcome back',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textPrimary, fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            // Text('Log in to continue to Neural AI Agent',
            //     textAlign: TextAlign.center,
            //     style: TextStyle(color: context.textSecondary, fontSize: 13)),
            const SizedBox(height: 26),
            AuthTextField(
              label: 'Email',
              hint: 'opcodedevelopers@gmail.com',
              icon: Icons.mail_outline_rounded,
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: AuthValidators.email,
            ),
            AuthTextField(
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              controller: _passwordCtrl,
              obscure: _obscure,
              validator: (v) => AuthValidators.required(v, field: 'Password'),
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18, color: context.textSecondary),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                child: const Text('Forgot password?',
                    style: TextStyle(color: AppColors.purple, fontSize: 12.5)),
              ),
            ),
            const SizedBox(height: 8),
            AuthPrimaryButton(label: 'Log In', onPressed: _login, loading: _loading),
            const SizedBox(height: 22),
            const AuthDivider(),
            const SizedBox(height: 16),
            const SocialSignInRow(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Don't have an account? ", style: TextStyle(color: context.textSecondary, fontSize: 13)),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SignupScreen(isDarkMode: widget.isDarkMode, onToggleTheme: widget.onToggleTheme),
                    ),
                  ),
                  child: const Text('Sign up',
                      style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
