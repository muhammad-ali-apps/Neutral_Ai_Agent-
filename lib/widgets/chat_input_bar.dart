import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../models.dart';

class PickedAttachment {
  final String name;
  final IconData icon;
  final String? path;
  final Uint8List? bytes;
  final bool isImage;
  final String fileType; // 'screenshot', 'camera', 'project'
  final int? sizeInBytes;

  PickedAttachment({
    required this.name,
    required this.icon,
    this.path,
    this.bytes,
    this.isImage = false,
    required this.fileType,
    this.sizeInBytes,
  });

  String get formattedSize {
    int count = sizeInBytes ?? bytes?.length ?? 0;
    if (count == 0) {
      return isImage ? 'Image File' : 'Project File';
    }
    final kb = count / 1024;
    if (kb >= 1024) {
      return '${(kb / 1024).toStringAsFixed(1)} MB';
    }
    return '${kb.toStringAsFixed(0)} KB';
  }

  String get extensionLabel {
    final idx = name.lastIndexOf('.');
    if (idx != -1 && idx < name.length - 1) {
      final ext = name.substring(idx + 1).toUpperCase();
      if (ext.length <= 5) return ext;
    }
    return isImage ? 'IMG' : 'FILE';
  }

  String get typeSubtitle {
    final ext = extensionLabel;
    final size = formattedSize;
    if (fileType == 'screenshot') return 'Screenshot • $size';
    if (fileType == 'camera') return 'Photo • $size';
    if (fileType == 'project') return '$ext File • $size';
    return isImage ? 'Image • $size' : '$ext Document • $size';
  }
}

/// Reusable chat input bar with attach menu (Screenshot, Camera, Project)
/// and ChatGPT-style rich attachment cards.
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final void Function(String text, List<ChatAttachment> attachments) onSend;
  final bool showAttachButton;
  final bool isGenerating;
  final VoidCallback? onStop;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.hint = 'Ask anything...',
    this.showAttachButton = true,
    this.isGenerating = false,
    this.onStop,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _borderAnimationController;
  final List<PickedAttachment> _attachments = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _borderAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _borderAnimationController.dispose();
    super.dispose();
  }

  String get _effectiveHint {
    if (_attachments.isNotEmpty) {
      final last = _attachments.last;
      if (last.fileType == 'screenshot') {
        return 'Ask anything about this screenshot...';
      } else if (last.fileType == 'camera') {
        return 'Ask anything about this photo...';
      } else if (last.fileType == 'project') {
        return 'Ask anything about this project file...';
      }
    }
    return widget.hint;
  }

  void _submit() {
    if (widget.isGenerating) return;
    final text = widget.controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    final attachmentsToSend = _attachments
        .map((a) => ChatAttachment(
              name: a.name,
              path: a.path,
              bytes: a.bytes,
              isImage: a.isImage,
              fileType: a.fileType,
              sizeInBytes: a.sizeInBytes,
            ))
        .toList();

    final promptText = text.isEmpty && _attachments.isNotEmpty
        ? (_attachments.any((a) => a.fileType == 'project')
            ? 'Please analyze this project file.'
            : 'Please analyze this image.')
        : text;

    widget.onSend(promptText, attachmentsToSend);
    widget.controller.clear();
    setState(() => _attachments.clear());
  }

  Future<void> _pickCamera() async {
    setState(() => _busy = true);
    try {
      final XFile? file =
          await ImagePicker().pickImage(source: ImageSource.camera);
      if (file != null) {
        Uint8List bytes = await file.readAsBytes();
        if (bytes.isEmpty && file.path.isNotEmpty) {
          try {
            bytes = await File(file.path).readAsBytes();
          } catch (_) {}
        }
        setState(() => _attachments.add(PickedAttachment(
              name: file.name,
              icon: Icons.photo_camera_outlined,
              path: file.path,
              bytes: bytes,
              isImage: true,
              fileType: 'camera',
              sizeInBytes: bytes.length,
            )));
      }
    } catch (e) {
      _showError('Could not open camera: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Screenshot option: Strictly allows screenshot / image picking from gallery
  Future<void> _pickScreenshot() async {
    setState(() => _busy = true);
    try {
      final XFile? file =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file != null) {
        Uint8List bytes = await file.readAsBytes();
        if (bytes.isEmpty && file.path.isNotEmpty) {
          try {
            bytes = await File(file.path).readAsBytes();
          } catch (_) {}
        }
        setState(() => _attachments.add(PickedAttachment(
              name: file.name,
              icon: Icons.screenshot_monitor_outlined,
              path: file.path,
              bytes: bytes,
              isImage: true,
              fileType: 'screenshot',
              sizeInBytes: bytes.length,
            )));
      }
    } catch (e) {
      _showError('Could not open gallery: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Project option: Allows project code, text files, and documents
  Future<void> _pickProject() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes = file.bytes;
        if ((bytes == null || bytes.isEmpty) && file.path != null) {
          try {
            bytes = await File(file.path!).readAsBytes();
          } catch (_) {}
        }
        final ext = (file.extension ?? '').toLowerCase();
        final isImg = ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'].contains(ext);
        setState(() => _attachments.add(PickedAttachment(
              name: file.name,
              icon: isImg ? Icons.image_outlined : Icons.folder_outlined,
              path: file.path,
              bytes: bytes,
              isImage: isImg,
              fileType: isImg ? 'screenshot' : 'project',
              sizeInBytes: bytes?.length ?? file.size,
            )));
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
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ChatGPT style attachment preview cards
            if (_attachments.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _attachments
                      .map((a) => _buildAttachmentPreview(a))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? const Color(0xFF2F2F2F)
                        : const Color(0xFFF4F4F4),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: context.isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.fromLTRB(
                    widget.showAttachButton ? 12 : 16,
                    6,
                    8,
                    6,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.showAttachButton) ...[
                        _busy
                            ? const Padding(
                                padding: EdgeInsets.all(7),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.openaiGreen,
                                  ),
                                ),
                              )
                            : PopupMenuButton<String>(
                                tooltip: 'Attach file',
                                offset: const Offset(0, -160),
                                color: context.surface2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: context.borderColor),
                                ),
                                onSelected: (v) {
                                  if (v == 'Camera') _pickCamera();
                                  if (v == 'Screenshot') _pickScreenshot();
                                  if (v == 'Project') _pickProject();
                                },
                                itemBuilder: (context) => [
                                  _menuItem(
                                    context,
                                    'Screenshot',
                                    Icons.screenshot_monitor_outlined,
                                    'Attach image / screenshot',
                                  ),
                                  _menuItem(
                                    context,
                                    'Project',
                                    Icons.folder_outlined,
                                    'Attach project file / code',
                                  ),
                                  _menuItem(
                                    context,
                                    'Camera',
                                    Icons.photo_camera_outlined,
                                    'Take a photo',
                                  ),
                                ],
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: context.isDark
                                        ? Colors.white10
                                        : Colors.black12,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: context.textPrimary,
                                    size: 20,
                                  ),
                                ),
                              ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 140),
                          child: Focus(
                            onKeyEvent: (node, event) {
                              final isEnter =
                                  event.logicalKey == LogicalKeyboardKey.enter ||
                                      event.logicalKey ==
                                          LogicalKeyboardKey.numpadEnter;
                              if (event is KeyDownEvent && isEnter) {
                                if (HardwareKeyboard.instance.isShiftPressed) {
                                  return KeyEventResult.ignored;
                                }
                                if (!widget.isGenerating) {
                                  _submit();
                                }
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: TextField(
                              controller: widget.controller,
                              minLines: 1,
                              maxLines: 6,
                              textInputAction: TextInputAction.newline,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14.5,
                                height: 1.35,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 8),
                                hintText: _effectiveHint,
                                hintStyle: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.controller,
                        builder: (context, value, _) {
                          if (widget.isGenerating) {
                            return Tooltip(
                              message: 'Stop generating',
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: context.isDark ? Colors.white : Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: widget.onStop,
                                  icon: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: context.isDark ? Colors.black : Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          final canSend = value.text.trim().isNotEmpty ||
                              _attachments.isNotEmpty;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: canSend
                                  ? (context.isDark ? Colors.white : Colors.black)
                                  : (context.isDark
                                      ? Colors.white24
                                      : Colors.black12),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: canSend ? _submit : null,
                              icon: Icon(
                                Icons.arrow_upward_rounded,
                                color: canSend
                                    ? (context.isDark ? Colors.black : Colors.white)
                                    : context.textSecondary,
                                size: 18,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _borderAnimationController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: AnimatedRgbBorderPainter(
                            progress: _borderAnimationController.value,
                            borderRadius: 26,
                            strokeWidth: 2.0,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Orbit AI can make mistakes. Check important information',
              style: TextStyle(
                color: context.textSecondary.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Claude-style attachment card preview in the input area
  Widget _buildAttachmentPreview(PickedAttachment a) {
    const claudeAccent = Color(0xFFDA7756);
    final isDark = context.isDark;
    final isProject = a.fileType == 'project';

    return Container(
      margin: const EdgeInsets.only(right: 10),
      height: 56,
      constraints: const BoxConstraints(maxWidth: 250, minWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262522) : const Color(0xFFF7F5F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF3E3C37) : const Color(0xFFE2DFD6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (a.isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 42,
                height: 42,
                color: Colors.black26,
                child: a.bytes != null
                    ? Image.memory(a.bytes!, fit: BoxFit.cover)
                    : (a.path != null && !kIsWeb
                        ? Image.file(File(a.path!), fit: BoxFit.cover)
                        : const Icon(Icons.image,
                            color: claudeAccent, size: 20)),
              ),
            )
          else
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDA7756), Color(0xFFC06243)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isProject
                        ? Icons.terminal_rounded
                        : Icons.description_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  Text(
                    a.extensionLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  a.typeSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _attachments.remove(a)),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.black12,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded,
                  size: 13, color: context.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    BuildContext context,
    String label,
    IconData icon,
    String subtitle,
  ) {
    const claudeAccent = Color(0xFFDA7756);
    return PopupMenuItem<String>(
      value: label,
      height: 48,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: claudeAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: claudeAccent),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: TextStyle(color: context.textSecondary, fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated custom painter that renders a dynamic, moving RGB border beam
/// covering exactly half the perimeter of the rounded rectangle container.
///
/// Features:
/// - Smooth Euclidean perimeter tracking with constant speed
/// - Exactly half-length border beam (totalLength * 0.5)
/// - Continuous 360° cycling RGB/rainbow spectrum
/// - Smooth fading at both ends of the beam
/// - Subtle neon glow pass + crisp core line
class AnimatedRgbBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final double strokeWidth;

  AnimatedRgbBorderPainter({
    required this.progress,
    this.borderRadius = 26.0,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final halfStroke = strokeWidth / 2;
    final clampedRadius = math.min(
      borderRadius,
      math.min(size.width, size.height) / 2,
    );

    final rect = Rect.fromLTWH(
      halfStroke,
      halfStroke,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.max(0, clampedRadius - halfStroke)),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final totalLength = metric.length;
    if (totalLength <= 0) return;

    // Half length of the border perimeter as requested
    final beamLength = totalLength * 0.5;
    final startDist = (progress * totalLength) % totalLength;

    const int segments = 48;
    for (int i = 0; i < segments; i++) {
      final double t1 = i / segments;
      final double t2 = (i + 1) / segments;
      final double d1 = (startDist + t1 * beamLength) % totalLength;
      final double d2 = (startDist + t2 * beamLength) % totalLength;

      final double frac = i / (segments - 1);

      // Smooth fade at the two ends of the half-length beam
      double alpha;
      if (frac < 0.12) {
        alpha = frac / 0.12;
      } else if (frac > 0.88) {
        alpha = (1.0 - frac) / 0.12;
      } else {
        alpha = 1.0;
      }

      // Animated cycling RGB spectrum
      final double hue = (frac * 360.0 + progress * 360.0) % 360.0;
      final color = HSVColor.fromAHSV(
        alpha.clamp(0.0, 1.0),
        hue,
        1.0,
        1.0,
      ).toColor();

      // Soft neon glow layer
      final glowPaint = Paint()
        ..color = color.withValues(alpha: alpha * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      // Sharp core RGB line
      final corePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      if (d1 < d2) {
        final p = metric.extractPath(d1, d2);
        canvas.drawPath(p, glowPaint);
        canvas.drawPath(p, corePaint);
      } else if (d1 > d2) {
        final p1 = metric.extractPath(d1, totalLength);
        canvas.drawPath(p1, glowPaint);
        canvas.drawPath(p1, corePaint);
        final p2 = metric.extractPath(0, d2);
        canvas.drawPath(p2, glowPaint);
        canvas.drawPath(p2, corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant AnimatedRgbBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
