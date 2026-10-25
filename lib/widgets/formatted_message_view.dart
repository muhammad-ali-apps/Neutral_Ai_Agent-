import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../app_theme.dart';
import '../services/api_services.dart';
import '../services/url_launcher_service.dart';

/// Formats AI assistant messages using GptMarkdown for ChatGPT/Gemini style response rendering.
///
/// Features:
/// - Fully selectable text (like ChatGPT) via [SelectionArea].
/// - Clickable links (both markdown links and plain URLs) that open in browser via [openAppUrl].
/// - Distinct link styling with accent color and underline for clear interactivity.
class FormattedMessageView extends StatelessWidget {
  final String text;
  final bool isUser;
  final Color? textColor;
  final double? fontSize;
  final double? height;
  final bool selectable;

  const FormattedMessageView({
    super.key,
    required this.text,
    required this.isUser,
    this.textColor,
    this.fontSize,
    this.height,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      final userText = Text(
        text,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: fontSize ?? 14,
          height: height ?? 1.45,
        ),
      );
      return selectable ? SelectionArea(child: userText) : userText;
    }

    final cleaned = cleanAiResponse(text);

    final markdownWidget = GptMarkdown(
      cleaned,
      autolink: true,
      onLinkTap: (url, title) => openAppUrl(url),
      styleSheet: const GptMarkdownStyleSheet(
        link: LinkStyle(
          color: Color(0xFF388BFD),
          hoverColor: Color(0xFF58A6FF),
          decoration: TextDecoration.underline,
        ),
      ),
      style: TextStyle(
        color: textColor ?? context.textPrimary,
        fontSize: fontSize ?? 14,
        height: height ?? 1.5,
      ),
    );

    return selectable ? SelectionArea(child: markdownWidget) : markdownWidget;
  }
}
