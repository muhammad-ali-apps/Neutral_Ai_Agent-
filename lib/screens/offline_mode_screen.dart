import 'dart:math';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../models.dart';
import '../widgets/screen_header.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_actions.dart';
import '../widgets/copy_toast.dart';

/// Offline Mode screen — local Ollama-powered chat.
class OfflineModeScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final ValueChanged<String?>? onSessionChanged;
  const OfflineModeScreen({super.key, this.onMenuTap, this.onSessionChanged});

  @override
  State<OfflineModeScreen> createState() => OfflineModeScreenState();
}

class OfflineModeScreenState extends State<OfflineModeScreen> {
  final _controller = TextEditingController();
  bool _connecting = false;
  bool _connected = false;
  ChatSession? _session;

  int? _editingIndex;
  TextEditingController? _editController;

  final _dummyLocalModels = const ['llama3:8b', 'mistral:7b', 'phi3:mini'];

  void _notifySession() => widget.onSessionChanged?.call(_session?.id);

  void startNewChat() {
    setState(() {
      _session = null;
      _editingIndex = null;
      _editController = null;
    });
    _notifySession();
  }

  /// Called by HomeShell when the user selects a history item in the Sidebar.
  void openSession(ChatSession s) {
    setState(() {
      _session = s;
      _editingIndex = null;
      _editController = null;
    });
    _notifySession();
  }

  void _connect() {
    setState(() => _connecting = true);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connected = true;
      });
    });
  }

  void _send(String text, List<String> attachments) {
    if (text.trim().isEmpty) return;
    setState(() {
      _session ??= ChatSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: text.length > 42 ? '${text.substring(0, 42)}...' : text,
        mode: ChatMode.offline,
      );
      final isNew = !historyStore.sessions.contains(_session);
      _session!.messages.add(ChatMessage(isUser: true, text: text, attachments: attachments));
      if (isNew) {
        historyStore.addSession(_session!);
      } else {
        historyStore.touch(_session!);
      }
    });
    _notifySession();
    _appendAiResponse();
  }

  void _appendAiResponse() {
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || _session == null) return;
      final model = _dummyLocalModels[Random().nextInt(_dummyLocalModels.length)];
      setState(() {
        _session!.messages.add(ChatMessage(
          isUser: false,
          modelName: model,
          text: '[Dummy local response placeholder from $model — UI demo only, '
              'runs fully offline once a real Ollama server is wired up.]',
        ));
        historyStore.touch(_session!);
      });
    });
  }

  void _startEdit(int index) {
    setState(() {
      _editingIndex = index;
      _editController = TextEditingController(text: _session!.messages[index].text);
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _editController = null;
    });
  }

  void _confirmEdit(int index) {
    final newText = _editController!.text.trim();
    if (newText.isEmpty) return;
    setState(() {
      _session!.messages[index].text = newText;
      if (_session!.messages.length > index + 1) {
        _session!.messages.removeRange(index + 1, _session!.messages.length);
      }
      _editingIndex = null;
      _editController = null;
    });
    historyStore.touch(_session!);
    _appendAiResponse();
  }

  void _regenerateAt(int index) {
    final model = _dummyLocalModels[Random().nextInt(_dummyLocalModels.length)];
    setState(() {
      _session!.messages[index] = ChatMessage(
        isUser: false,
        modelName: model,
        text: '[Regenerated dummy local response from $model — UI demo only.]',
      );
    });
    historyStore.touch(_session!);
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showCopiedToast(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasMessages = _session != null && _session!.messages.isNotEmpty;
    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          ScreenHeader(
            icon: Icons.wifi_off_rounded,
            title: 'Offline Mode',
            subtitle: 'Ollama models',
            onMenuTap: widget.onMenuTap,
          ),
          Expanded(child: hasMessages ? _buildChatList(context) : _buildSetupState(context)),
          ChatInputBar(controller: _controller, hint: 'Ask Anything', onSend: _send),
        ],
      ),
    );
  }

  Widget _buildChatList(BuildContext context) {
    final messages = _session!.messages;
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];

        if (i == _editingIndex) {
          return Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: MessageEditBox(
                controller: _editController!,
                onCancel: _cancelEdit,
                onConfirm: () => _confirmEdit(i),
              ),
            ),
          );
        }

        return Align(
          alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: m.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 560),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: m.isUser ? AppColors.purple.withValues(alpha: 0.85) : context.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: m.isUser ? null : Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!m.isUser && m.modelName != null) ...[
                      Row(
                        children: [
                          Icon(Icons.memory_rounded, size: 14, color: context.textSecondary),
                          const SizedBox(width: 6),
                          Text(m.modelName!,
                              style: TextStyle(
                                  color: context.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(m.text,
                        style: TextStyle(
                            color: m.isUser ? Colors.white : context.textPrimary, fontSize: 14, height: 1.45)),
                  ],
                ),
              ),
              m.isUser
                  ? UserMessageActions(onEdit: () => _startEdit(i), onCopy: () => _copy(m.text))
                  : AssistantMessageActions(onCopy: () => _copy(m.text), onRegenerate: () => _regenerateAt(i)),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSetupState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.wifi_off_rounded, color: AppColors.purple, size: 30),
              ),
              const SizedBox(height: 16),
              // Text('Offline Mode',
              //     style:
              //         TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    'Offline Mode',
                    textStyle: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                    speed: const Duration(milliseconds: 200),
                  ),
                ],
                totalRepeatCount: 19,
                pause: const Duration(milliseconds: 1000),
                displayFullTextOnTap: true,
                stopPauseOnTap: true,
              ),
              const SizedBox(height: 8),
              Text(
                'Run AI models without internet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary, fontSize: 13.5, height: 1.45),
              ),
              // const SizedBox(height: 22),
              // Container(
              //   width: double.infinity,
              //   padding: const EdgeInsets.all(18),
              //   decoration: BoxDecoration(
              //     color: context.surface2,
              //     borderRadius: BorderRadius.circular(12),
              //     border: Border.all(color: context.borderColor),
              //   ),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Text('Setup Instructions:',
              //           style: TextStyle(
              //               color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              //       const SizedBox(height: 10),
              //       _stepText(context, '1. Install Ollama from ', 'ollama.ai'),
              //       _stepText(context, '2. Run: ', 'ollama pull llama3', mono: true),
              //       _stepText(context, '3. Start Ollama server', ''),
              //       _stepText(context, '4. Type a message below once connected', ''),
              //     ],
              //   ),
              // ),
              const SizedBox(height: 20),
              if (!_connected)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _connecting ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _connecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(_connecting ? 'Connecting...' : 'Connect to Ollama'),
                  ),
                )
              else
                _buildConnectedPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Text('Connected to Ollama',
                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ..._dummyLocalModels.map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.memory_rounded, size: 15, color: context.textSecondary),
                    const SizedBox(width: 8),
                    Text(m, style: TextStyle(color: context.textPrimary, fontSize: 13)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _stepText(BuildContext context, String plain, String code, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.5),
          children: [
            TextSpan(text: plain),
            if (code.isNotEmpty)
              TextSpan(
                text: code,
                style: TextStyle(
                  color: AppColors.purple,
                  fontWeight: FontWeight.w600,
                  fontFamily: mono ? 'monospace' : null,
                  backgroundColor: mono ? context.surface : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
