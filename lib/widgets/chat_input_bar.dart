import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';

class PickedAttachment {
  final String name;
  final IconData icon;
  PickedAttachment(this.name, this.icon);
}

/// Reusable chat input bar with attach menu and send control.
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final void Function(String text, List<String> attachmentNames) onSend;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.hint = 'Ask anything...',
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final List<PickedAttachment> _attachments = [];
  bool _busy = false;

  void _submit() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text, _attachments.map((a) => a.name).toList());
    widget.controller.clear();
    setState(() => _attachments.clear());
  }

  Future<void> _pickCamera() async {
    setState(() => _busy = true);
    try {
      final XFile? file = await ImagePicker().pickImage(source: ImageSource.camera);
      if (file != null) {
        setState(() => _attachments.add(PickedAttachment(file.name, Icons.photo_camera_outlined)));
      }
    } catch (e) {
      _showError('Could not open camera: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickScreenshot() async {
    setState(() => _busy = true);
    try {
      final XFile? file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file != null) {
        setState(() =>
            _attachments.add(PickedAttachment(file.name, Icons.screenshot_monitor_outlined)));
      }
    } catch (e) {
      _showError('Could not open gallery: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickProject() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.isNotEmpty) {
        setState(() =>
            _attachments.add(PickedAttachment(result.files.first.name, Icons.folder_outlined)));
      }
    } catch (e) {
      _showError('Could not open file picker: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_attachments.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _attachments
                  .map(
                    (a) => Chip(
                      backgroundColor: context.surface2,
                      avatar: Icon(a.icon, size: 14, color: AppColors.purple),
                      label: Text(
                        a.name,
                        style: TextStyle(color: context.textPrimary, fontSize: 11.5),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => setState(() => _attachments.remove(a)),
                      side: BorderSide(color: context.borderColor),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            decoration: BoxDecoration(
              color: context.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: Focus(
                    onKeyEvent: (node, event) {
                      final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter;
                      if (event is KeyDownEvent && isEnter) {
                        if (HardwareKeyboard.instance.isShiftPressed) {
                          return KeyEventResult.ignored;
                        }
                        _submit();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: widget.controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(color: context.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        hintText: widget.hint,
                        hintStyle: TextStyle(color: context.textSecondary, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _busy
                        ? const Padding(
                            padding: EdgeInsets.all(7),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.purple,
                              ),
                            ),
                          )
                        : PopupMenuButton<String>(
                            tooltip: 'Add attachment',
                            offset: const Offset(0, -160),
                            color: context.surface2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: context.borderColor),
                            ),
                            onSelected: (v) {
                              if (v == 'Camera') _pickCamera();
                              if (v == 'Screenshot') _pickScreenshot();
                              if (v == 'Project') _pickProject();
                            },
                            itemBuilder: (context) => [
                              _menuItem(context, 'Camera', Icons.photo_camera_outlined),
                              _menuItem(context, 'Screenshot', Icons.screenshot_monitor_outlined),
                              _menuItem(context, 'Project', Icons.folder_outlined),
                            ],
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.purple.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add_rounded, color: AppColors.purple, size: 18),
                            ),
                          ),
                    const Spacer(),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: widget.controller,
                      builder: (context, value, _) {
                        final hasText = value.text.trim().isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: hasText ? AppColors.purple : context.borderColor,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: hasText ? _submit : null,
                            icon: Icon(
                              Icons.arrow_upward_rounded,
                              color: hasText ? Colors.white : context.textSecondary,
                              size: 17,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Press Enter to send, Shift+Enter for new line',
            style: TextStyle(color: context.textSecondary, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(BuildContext context, String label, IconData icon) {
    return PopupMenuItem<String>(
      value: label,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: context.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}
