import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models.dart';

/// Interactive Prompt Jump Bar (ChatGPT/Claude style).
/// Displays subtle dash lines (_) on the left edge when collapsed.
/// When hovered, lines hide and an expanded list of user prompts appears in sequence on the left.
/// Clicking any prompt scrolls the chat viewport directly to that prompt message.
class PromptJumpBar extends StatefulWidget {
  final List<ChatMessage> messages;
  final List<GlobalKey> messageKeys;
  final ValueChanged<int> onJump;

  const PromptJumpBar({
    super.key,
    required this.messages,
    required this.messageKeys,
    required this.onJump,
  });

  @override
  State<PromptJumpBar> createState() => _PromptJumpBarState();
}

class _PromptJumpBarState extends State<PromptJumpBar> {
  bool _isHovered = false;
  int? _hoveredItemIndex;

  @override
  Widget build(BuildContext context) {
    final userPrompts = <MapEntry<int, ChatMessage>>[];
    for (int i = 0; i < widget.messages.length; i++) {
      if (widget.messages[i].isUser) {
        userPrompts.add(MapEntry(i, widget.messages[i]));
      }
    }

    // Show jump bar if there are 2 or more user prompts
    if (userPrompts.length < 2) return const SizedBox.shrink();

    final isDark = context.isDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(left: 8, top: 12, bottom: 12),
        padding: _isHovered
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: _isHovered
              ? (isDark ? const Color(0xFF222222) : Colors.white).withValues(alpha: 0.96)
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? AppColors.purple.withValues(alpha: 0.4)
                : context.borderColor.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.18 : 0.08),
              blurRadius: _isHovered ? 14 : 8,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isHovered
              ? _buildExpandedPromptList(context, userPrompts)
              : _buildCollapsedDashLines(context, userPrompts),
        ),
      ),
    );
  }

  /// Collapsed view: Subtle dash lines (_) representing each prompt
  Widget _buildCollapsedDashLines(
      BuildContext context, List<MapEntry<int, ChatMessage>> userPrompts) {
    final isDark = context.isDark;
    return Column(
      key: const ValueKey('collapsed_dashes'),
      mainAxisSize: MainAxisSize.min,
      children: userPrompts.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.5, horizontal: 2),
          child: Container(
            width: 12,
            height: 3,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF666666) : const Color(0xFFB0B0B0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Expanded view: Clean sequence list of user prompts
  Widget _buildExpandedPromptList(
      BuildContext context, List<MapEntry<int, ChatMessage>> userPrompts) {
    final isDark = context.isDark;
    return ConstrainedBox(
      key: const ValueKey('expanded_prompts'),
      constraints: const BoxConstraints(maxWidth: 240, maxHeight: 360),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.list_alt_rounded, size: 14, color: AppColors.purple),
                  const SizedBox(width: 6),
                  Text(
                    'Prompts (${userPrompts.length})',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: context.borderColor, height: 8),
            ...userPrompts.asMap().entries.map((entry) {
              final rank = entry.key;
              final msgIndex = entry.value.key;
              final msg = entry.value.value;
              final isItemHovered = _hoveredItemIndex == rank;

              final rawText = msg.text.trim().replaceAll(RegExp(r'\s+'), ' ');
              final promptPreview = rawText.isNotEmpty
                  ? rawText
                  : (msg.attachments.isNotEmpty ? msg.attachments.first.name : 'Prompt');

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onHover: (hovered) {
                    if (hovered && _hoveredItemIndex != rank) {
                      setState(() => _hoveredItemIndex = rank);
                    } else if (!hovered && _hoveredItemIndex == rank) {
                      setState(() => _hoveredItemIndex = null);
                    }
                  },
                  onTap: () {
                    widget.onJump(msgIndex);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isItemHovered
                          ? AppColors.purple.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isItemHovered
                                ? AppColors.purple
                                : (isDark
                                    ? const Color(0xFF333333)
                                    : const Color(0xFFE5E5E5)),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${rank + 1}',
                            style: TextStyle(
                              color: isItemHovered
                                  ? Colors.white
                                  : context.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            promptPreview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isItemHovered
                                  ? AppColors.purple
                                  : context.textPrimary,
                              fontSize: 12,
                              fontWeight: isItemHovered
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
