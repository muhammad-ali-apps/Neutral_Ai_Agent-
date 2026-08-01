import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

/// Set new password screen.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen(isDarkMode: true, onToggleTheme: _noop)),
        (route) => false,
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password reset successful. Please log in.')));
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
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.password_rounded, color: AppColors.purple, size: 28),
            ),
            const SizedBox(height: 18),
            Text('Set New Password',
                style: TextStyle(color: context.textPrimary, fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Your new password must be different from previously used passwords.',
                style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            AuthTextField(
              label: 'New Password',
              hint: 'Enter new password',
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
              label: 'Confirm New Password',
              hint: 'Re-enter new password',
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
            const SizedBox(height: 4),
            AuthPrimaryButton(label: 'Reset Password', onPressed: _reset, loading: _loading),
          ],
        ),
      ),
    );
  }
}

void _noop() {}
