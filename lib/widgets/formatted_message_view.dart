import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../app_theme.dart';
import '../services/api_services.dart';

/// Formats AI assistant messages using GptMarkdown for ChatGPT/Gemini style response rendering.
class FormattedMessageView extends StatelessWidget {
  final String text;
  final bool isUser;
  final Color? textColor;

  const FormattedMessageView({
    super.key,
    required this.text,
    required this.isUser,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return Text(
        text,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 14,
          height: 1.45,
        ),
      );
    }

    final cleaned = cleanAiResponse(text);

    return GptMarkdown(
      cleaned,
      style: TextStyle(
        color: textColor ?? context.textPrimary,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}
