import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'auth_widgets.dart';
import 'otp_screen.dart';

/// Signup screen with form validation.
class SignupScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  const SignupScreen({super.key, required this.isDarkMode, required this.onToggleTheme});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _agree = false;
  bool _agreeError = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _signup() {
    final formValid = _formKey.currentState!.validate();
    setState(() => _agreeError = !_agree);
    if (!formValid || !_agree) return;

    setState(() => _loading = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpScreen(
          purpose: OtpPurpose.signupVerification,
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
        ),
      ));
    });
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
            Text('Create your account',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textPrimary, fontSize: 19, fontWeight: FontWeight.bold)),
            // const SizedBox(height: 6),
            // Text('Start routing prompts to the best AI models',
            //     textAlign: TextAlign.center,
            //     style: TextStyle(color: context.textSecondary, fontSize: 13)),
            const SizedBox(height: 26),
            AuthTextField(
              label: 'Full Name',
              hint: 'Muhammad Ali',
              icon: Icons.person_outline_rounded,
              controller: _nameCtrl,
              validator: (v) => AuthValidators.required(v, field: 'Full name'),
            ),
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
              hint: 'Create a password',
              icon: Icons.lock_outline_rounded,
              controller: _passwordCtrl,
              obscure: _obscure,
              validator: AuthValidators.password,
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18, color: context.textSecondary),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            AuthTextField(
              label: 'Confirm Password',
              hint: 'Confirm your password',
              icon: Icons.lock_outline_rounded,
              controller: _confirmCtrl,
              obscure: _obscureConfirm,
              validator: AuthValidators.confirmPassword(_passwordCtrl),
              suffix: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18, color: context.textSecondary),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _agree,
                    activeColor: AppColors.purple,
                    onChanged: (v) => setState(() {
                      _agree = v ?? false;
                      if (_agree) _agreeError = false;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('I agree to the Terms of Service & Privacy Policy',
                        style: TextStyle(
                            color: _agreeError ? Colors.redAccent : context.textSecondary, fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AuthPrimaryButton(label: 'Create Account', onPressed: _signup, loading: _loading),
            const SizedBox(height: 22),
            const AuthDivider(),
            const SizedBox(height: 16),
            const SocialSignInRow(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Already have an account? ', style: TextStyle(color: context.textSecondary, fontSize: 13)),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Text('Log in',
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
