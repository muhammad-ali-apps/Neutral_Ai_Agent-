import 'dart:math';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../models.dart';
import '../services/dummy_response_generator.dart';
import '../widgets/screen_header.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_actions.dart';
import '../widgets/copy_toast.dart';
import '../widgets/chat_attachment_view.dart';
import '../widgets/formatted_message_view.dart';

/// Smart Routing screen — routes prompts to the best available model.
class SmartRoutingScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final ValueChanged<String?>? onSessionChanged;
  const SmartRoutingScreen({super.key, this.onMenuTap, this.onSessionChanged});

  @override
  State<SmartRoutingScreen> createState() => SmartRoutingScreenState();
}

class SmartRoutingScreenState extends State<SmartRoutingScreen> {
  final _controller = TextEditingController();
  bool _thinking = false;
  ChatSession? _session;

  int? _editingIndex;
  TextEditingController? _editController;

  final _suggestions = const [
    'Write a Python function to sort a list',
    'Explain quantum entanglement',
    'Write a short poem about the sea',
    'Solve: 2x² + 5x - 3 = 0',
  ];

  void _notifySession() => widget.onSessionChanged?.call(_session?.id);

  /// Called by the main app Sidebar's "New Chat" button when this screen is active.
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

  void _send(String text, List<ChatAttachment> attachments) {
    if (text.trim().isEmpty && attachments.isEmpty) return;
    setState(() {
      _session ??= ChatSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: text.length > 42 ? '${text.substring(0, 42)}...' : (text.isNotEmpty ? text : (attachments.isNotEmpty ? attachments.first.name : 'New Chat')),
        mode: ChatMode.smartRouting,
      );
      final isNew = !historyStore.sessions.contains(_session);
      _session!.messages.add(ChatMessage(isUser: true, text: text, attachments: attachments));
      if (isNew) {
        historyStore.addSession(_session!);
      } else {
        historyStore.touch(_session!);
      }
      _thinking = true;
    });
    _notifySession();
    _appendAiResponse(prompt: text, attachments: attachments);
  }

  void _appendAiResponse({String? prompt, List<ChatAttachment>? attachments}) {
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || _session == null) return;
      final pool = modelStore.active.isNotEmpty
          ? modelStore.active
          : (modelStore.models.isNotEmpty ? modelStore.models : seedModels());
      final rnd = Random();
      final model = pool.isNotEmpty ? pool[rnd.nextInt(pool.length)] : seedModels().first;

      final lastUserMsg = _session!.messages.reversed.where((m) => m.isUser).cast<ChatMessage?>().firstOrNull;
      final effectivePrompt = prompt ?? lastUserMsg?.text ?? '';
      final effectiveAttachments = attachments ?? lastUserMsg?.attachments ?? [];

      final aiText = DummyResponseGenerator.generate(
        prompt: effectivePrompt,
        attachments: effectiveAttachments,
        modelName: model.name,
        modeName: 'Smart Routing',
      );

      setState(() {
        _thinking = false;
        _session!.messages.add(ChatMessage(
          isUser: false,
          modelName: model.name,
          text: aiText,
        ));
        historyStore.touch(_session!);
      });
    });
  }

  void _sendSuggestion(String text) => _send(text, []);

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
      // Drop the old AI response(s) that followed this prompt
      if (_session!.messages.length > index + 1) {
        _session!.messages.removeRange(index + 1, _session!.messages.length);
      }
      _editingIndex = null;
      _editController = null;
      _thinking = true;
    });
    historyStore.touch(_session!);
    _appendAiResponse(prompt: newText, attachments: _session!.messages[index].attachments);
  }

  void _regenerateAt(int index) {
    final pool = modelStore.active.isNotEmpty
        ? modelStore.active
        : (modelStore.models.isNotEmpty ? modelStore.models : seedModels());
    final rnd = Random();
    final model = pool.isNotEmpty ? pool[rnd.nextInt(pool.length)] : seedModels().first;

    // Find preceding user prompt
    String prompt = '';
    List<ChatAttachment> attachments = [];
    for (int i = index - 1; i >= 0; i--) {
      if (_session!.messages[i].isUser) {
        prompt = _session!.messages[i].text;
        attachments = _session!.messages[i].attachments;
        break;
      }
    }

    final regeneratedText = DummyResponseGenerator.generate(
      prompt: prompt,
      attachments: attachments,
      modelName: model.name,
      modeName: 'Smart Routing',
    );

    setState(() {
      _session!.messages[index] = ChatMessage(
        isUser: false,
        modelName: model.name,
        text: regeneratedText,
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
    final activeCount = modelStore.active.length;
    final hasMessages = _session != null && _session!.messages.isNotEmpty;
    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          ScreenHeader(
            icon: Icons.bolt_rounded,
            title: 'Smart Routing',
            subtitle: 'Auto route prompts to the best AI model for the task',
            onMenuTap: widget.onMenuTap,
            trailing: ListenableBuilder(
              listenable: modelStore,
              builder: (context, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(radius: 3.5, backgroundColor: AppColors.success),
                    const SizedBox(width: 6),
                    Text('${modelStore.active.length} models active',
                        style: const TextStyle(
                            color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: hasMessages ? _buildChatList(context) : _buildEmptyState(context, activeCount),
          ),
          if (_thinking) _buildThinkingBar(context),
          ChatInputBar(
            controller: _controller,
            hint: "Ask anything ",
            onSend: _send,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, int activeCount) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.bolt_rounded, color: AppColors.purple, size: 30),
              ),
              const SizedBox(height: 16),
              // Text('Smart Routing Mode',
              //     style:
              //         TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              // const SizedBox(height: 8),
             AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    'Smart Routing Mode',
                    textStyle: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                    speed: const Duration(milliseconds: 200),
                  ),
                ],
                totalRepeatCount: 19,
                pause: const Duration(milliseconds: 600),
                displayFullTextOnTap: true,
                stopPauseOnTap: true,
              ),
              // Text(
              //   'Type any prompt — the system will automatically analyze it and route it '
              //   'to the best AI model for that task.',
              //   textAlign: TextAlign.center,
              //   style: TextStyle(color: context.textSecondary, fontSize: 13.5, height: 1.45),
              // ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;
                  return GridView.count(
                    crossAxisCount: isNarrow ? 1 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 10,
                    childAspectRatio: isNarrow ? 4.6 : 2.8,
                    children: _suggestions.map((s) {
                      return _SuggestionCard(text: s, onTap: () => _sendSuggestion(s));
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatList(BuildContext context) {
    final messages = _session!.messages;
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleMaxWidth = screenWidth < 660 ? screenWidth * 0.90 : 640.0;
    final isDark = context.isDark;

    const claudeUserDark = Color(0xFF262522); // Claude warm charcoal
    const claudeBorderDark = Color(0xFF3E3C37);
    const claudeUserLight = Color(0xFFF5F3ED);
    const claudeBorderLight = Color(0xFFE2DFD6);
    const claudeAccent = Color(0xFFDA7756);

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth < 500 ? 12 : 20,
        vertical: 16,
      ),
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

        final model = m.modelName == null
            ? null
            : modelStore.models.where((e) => e.name == m.modelName).cast<LlmModel?>().firstOrNull;

        return Align(
          alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: m.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: m.isUser
                      ? (isDark ? claudeUserDark : claudeUserLight)
                      : context.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: m.isUser
                        ? (isDark ? claudeBorderDark : claudeBorderLight)
                        : context.borderColor,
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Claude-styled Attachments at top of bubble
                    if (m.attachments.isNotEmpty)
                      ChatAttachmentsView(attachments: m.attachments, isUser: m.isUser),
                    // Model identity header for Assistant
                    if (!m.isUser) ...[
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: model?.color ?? claudeAccent,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              model?.badgeLetter ?? 'C',
                              style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            m.modelName ?? 'Claude 3.5 Sonnet',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: claudeAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Smart Routed',
                              style: TextStyle(
                                color: claudeAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Message content rendered with Markdown / Code blocks
                    if (m.isUser)
                      Text(
                        m.text,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                          fontSize: 14.5,
                          height: 1.5,
                        ),
                      )
                    else
                      FormattedMessageView(
                        text: m.text,
                        isUser: false,
                        textColor: context.textPrimary,
                      ),
                  ],
                ),
              ),
              m.isUser
                  ? UserMessageActions(onEdit: () => _startEdit(i), onCopy: () => _copy(m.text))
                  : AssistantMessageActions(onCopy: () => _copy(m.text), onRegenerate: () => _regenerateAt(i)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThinkingBar(BuildContext context) {
    const claudeAccent = Color(0xFFDA7756);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: claudeAccent),
          ),
          const SizedBox(width: 10),
          Text(
            'Analyzing prompt & routing to Claude AI model...',
            style: TextStyle(color: context.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SuggestionCard({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.borderColor),
          ),
          alignment: Alignment.centerLeft,
          child: Text(text, style: TextStyle(color: context.textSecondary, fontSize: 12.5, height: 1.3)),
        ),
      ),
    );
  }
}
