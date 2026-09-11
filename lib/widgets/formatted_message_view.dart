import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import 'copy_toast.dart';

/// Formats AI assistant messages with ChatGPT-style headers, code blocks, bold text, and lists.
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

    final blocks = _parseMarkdownBlocks(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) => _buildBlock(context, block)).toList(),
    );
  }

  List<_MarkdownBlock> _parseMarkdownBlocks(String input) {
    final blocks = <_MarkdownBlock>[];
    final codeBlockRegex = RegExp(r'```(\w*)\n([\s\S]*?)```');
    
    int lastIndex = 0;
    for (final match in codeBlockRegex.allMatches(input)) {
      if (match.start > lastIndex) {
        final textPart = input.substring(lastIndex, match.start).trim();
        if (textPart.isNotEmpty) {
          blocks.add(_MarkdownBlock(type: _BlockType.text, content: textPart));
        }
      }

      final lang = match.group(1) ?? '';
      final code = match.group(2) ?? '';
      blocks.add(_MarkdownBlock(type: _BlockType.code, content: code, language: lang));
      lastIndex = match.end;
    }

    if (lastIndex < input.length) {
      final remaining = input.substring(lastIndex).trim();
      if (remaining.isNotEmpty) {
        blocks.add(_MarkdownBlock(type: _BlockType.text, content: remaining));
      }
    }

    if (blocks.isEmpty) {
      blocks.add(_MarkdownBlock(type: _BlockType.text, content: input));
    }

    return blocks;
  }

  Widget _buildBlock(BuildContext context, _MarkdownBlock block) {
    if (block.type == _BlockType.code) {
      return _buildCodeBlock(context, block.content, block.language ?? 'code');
    }

    // Process text paragraphs line by line
    final lines = block.content.split('\n');
    final children = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      if (trimmed.startsWith('### ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            trimmed.replaceFirst('### ', ''),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ));
      } else if (trimmed.startsWith('## ') || trimmed.startsWith('# ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            trimmed.replaceFirst(RegExp(r'^#+\s*'), ''),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || trimmed.startsWith('• ')) {
        final bulletText = trimmed.replaceFirst(RegExp(r'^[-*•]\s*'), '');
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6, right: 8),
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.purple,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: _buildRichText(context, bulletText),
              ),
            ],
          ),
        ));
      } else if (trimmed.startsWith('> ')) {
        children.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: const Border(left: BorderSide(color: AppColors.purple, width: 3)),
            color: AppColors.purple.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
          ),
          child: _buildRichText(context, trimmed.replaceFirst('> ', '')),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _buildRichText(context, line),
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildRichText(BuildContext context, String input) {
    final spans = <InlineSpan>[];
    final boldRegex = RegExp(r'\*\*(.*?)\*\*|`([^`]+)`');

    int lastIndex = 0;
    for (final match in boldRegex.allMatches(input)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: input.substring(lastIndex, match.start),
          style: TextStyle(color: textColor ?? context.textPrimary, fontSize: 13.5, height: 1.45),
        ));
      }

      final boldGroup = match.group(1);
      final codeInlineGroup = match.group(2);

      if (boldGroup != null) {
        spans.add(TextSpan(
          text: boldGroup,
          style: TextStyle(
            color: textColor ?? context.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ));
      } else if (codeInlineGroup != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              codeInlineGroup,
              style: const TextStyle(
                color: AppColors.purple,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < input.length) {
      spans.add(TextSpan(
        text: input.substring(lastIndex),
        style: TextStyle(color: textColor ?? context.textPrimary, fontSize: 13.5, height: 1.45),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildCodeBlock(BuildContext context, String code, String language) {
    final displayLang = language.isEmpty ? 'CODE' : language.toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E2C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayLang,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code.trim()));
                    showCopiedToast(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 12, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          'Copy code',
                          style: TextStyle(color: Colors.white70, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code Content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Text(
              code.trim(),
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12.5,
                fontFamily: 'monospace',
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BlockType { text, code }

class _MarkdownBlock {
  final _BlockType type;
  final String content;
  final String? language;

  _MarkdownBlock({
    required this.type,
    required this.content,
    this.language,
  });
}
