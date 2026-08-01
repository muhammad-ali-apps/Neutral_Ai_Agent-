import 'package:flutter/material.dart';
import '../app_theme.dart';

Widget messageActionIcon(
  BuildContext context,
  IconData icon,
  VoidCallback onTap, {
  String? tooltip,
}) {
  return Tooltip(
    message: tooltip ?? '',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        hoverColor: AppColors.purple.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 14, color: context.textSecondary),
        ),
      ),
    ),
  );
}

/// Edit and copy actions under a user message bubble.
class UserMessageActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  const UserMessageActions({super.key, required this.onEdit, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          messageActionIcon(context, Icons.edit_outlined, onEdit, tooltip: 'Edit'),
          messageActionIcon(context, Icons.copy_rounded, onCopy, tooltip: 'Copy'),
        ],
      ),
    );
  }
}

/// Copy and regenerate actions under an assistant response.
class AssistantMessageActions extends StatelessWidget {
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;
  const AssistantMessageActions({super.key, required this.onCopy, required this.onRegenerate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          messageActionIcon(context, Icons.copy_rounded, onCopy, tooltip: 'Copy'),
          messageActionIcon(context, Icons.refresh_rounded, onRegenerate, tooltip: 'Regenerate'),
        ],
      ),
    );
  }
}

/// Inline edit box that replaces a user bubble while editing.
class MessageEditBox extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const MessageEditBox({
    super.key,
    required this.controller,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.purple, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 6,
            style: TextStyle(color: context.textPrimary, fontSize: 14),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  ),
                  child: const Text('Save & Regenerate', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
