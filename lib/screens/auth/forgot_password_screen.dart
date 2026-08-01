import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'auth_widgets.dart';
import 'otp_screen.dart';

/// Forgot password screen.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _sendCode() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const OtpScreen(purpose: OtpPurpose.passwordReset)));
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
            IconButton(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back_rounded, color: context.textSecondary),
            ),
            const SizedBox(height: 6),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lock_reset_rounded, color: AppColors.purple, size: 28),
            ),
            const SizedBox(height: 18),
            Text('Forgot Password?',
                style: TextStyle(color: context.textPrimary, fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            // Text(
            //   "No worries — enter the email linked to your account and we'll "
            //   'send you a verification code to reset it.',
            //   style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.5),
            // ),
            const SizedBox(height: 24),
            AuthTextField(
              label: 'Email',
              hint: 'opcodedevelopers@gmail.com',
              icon: Icons.mail_outline_rounded,
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 4),
            AuthPrimaryButton(label: 'Send Reset Code', onPressed: _sendCode, loading: _loading),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 14, color: context.textSecondary),
                    const SizedBox(width: 6),
                    Text('Back to log in', style: TextStyle(color: context.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
