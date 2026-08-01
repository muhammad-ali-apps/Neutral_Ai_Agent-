import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_theme.dart';
import '../../widgets/home_shell.dart';
import 'auth_widgets.dart';
import 'reset_password_screen.dart';

enum OtpPurpose { signupVerification, passwordReset }

/// OTP verification screen for signup and password reset.
class OtpScreen extends StatefulWidget {
  final OtpPurpose purpose;
  final bool isDarkMode;
  final VoidCallback? onToggleTheme;

  const OtpScreen({
    super.key,
    required this.purpose,
    this.isDarkMode = true,
    this.onToggleTheme,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _showError = false;
  int _secondsLeft = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsLeft = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  bool get _isComplete => _controllers.every((c) => c.text.trim().isNotEmpty);

  void _verify() {
    if (!_isComplete) {
      setState(() => _showError = true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter all 6 digits of the code.')));
      return;
    }
    setState(() {
      _showError = false;
      _loading = true;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _loading = false);
      if (widget.purpose == OtpPurpose.passwordReset) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResetPasswordScreen()));
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeShell(
              isDarkMode: widget.isDarkMode,
              onToggleTheme: widget.onToggleTheme ?? () {},
            ),
          ),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.purpose == OtpPurpose.signupVerification
        ? 'Enter the 6-digit code sent to your email to verify your account.'
        : 'Enter the 6-digit code sent to your email to reset your password.';

    return AuthScaffold(
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
            child: const Icon(Icons.mark_email_read_outlined, color: AppColors.purple, size: 28),
          ),
          const SizedBox(height: 18),
          Text('Verify OTP',
              style: TextStyle(color: context.textPrimary, fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.5)),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) => _otpBox(context, i)),
          ),
          if (_showError) ...[
            const SizedBox(height: 10),
            const Text('All 6 digits are required', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
          const SizedBox(height: 24),
          AuthPrimaryButton(label: 'Verify Code', onPressed: _verify, loading: _loading),
          const SizedBox(height: 18),
          Center(
            child: _secondsLeft > 0
                ? Text('Resend code in 00:${_secondsLeft.toString().padLeft(2, '0')}',
                    style: TextStyle(color: context.textSecondary, fontSize: 12.5))
                : GestureDetector(
                    onTap: _startTimer,
                    child: const Text('Resend Code',
                        style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _otpBox(BuildContext context, int index) {
    return SizedBox(
      width: 44,
      height: 52,
      child: TextField(
        controller: _controllers[index],
        focusNode: _nodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: context.surface2,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _showError ? Colors.redAccent : context.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _showError ? Colors.redAccent : context.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.purple, width: 1.6),
          ),
        ),
        onChanged: (v) {
          if (v.isNotEmpty) {
            setState(() => _showError = false);
            if (index < 5) _nodes[index + 1].requestFocus();
          } else if (v.isEmpty && index > 0) {
            _nodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}
