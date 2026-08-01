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

  final _categories = const ['Coding', 'Reasoning', 'Creative Writing', 'Math', 'General Chat'];

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

  void _send(String text, List<String> attachments) {
    if (text.trim().isEmpty) return;
    setState(() {
      _session ??= ChatSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: text.length > 42 ? '${text.substring(0, 42)}...' : text,
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
    _appendAiResponse();
  }

  void _appendAiResponse() {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || _session == null) return;
      final pool = modelStore.active.isNotEmpty ? modelStore.active : modelStore.models;
      final rnd = Random();
      final category = _categories[rnd.nextInt(_categories.length)];
      final model = pool[rnd.nextInt(pool.length)];
      setState(() {
        _thinking = false;
        _session!.messages.add(ChatMessage(
          isUser: false,
          modelName: model.name,
          text: '[Dummy generated response placeholder — UI demo only. '
              'In the real app this text will come from ${model.name} after '
              'the prompt is routed based on detected category: $category.]',
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
      // Drop the old AI response(s) that followed this prompt — they no
      // longer match the edited text.
      if (_session!.messages.length > index + 1) {
        _session!.messages.removeRange(index + 1, _session!.messages.length);
      }
      _editingIndex = null;
      _editController = null;
      _thinking = true;
    });
    historyStore.touch(_session!);
    _appendAiResponse();
  }

  void _regenerateAt(int index) {
    final pool = modelStore.active.isNotEmpty ? modelStore.active : modelStore.models;
    final rnd = Random();
    final category = _categories[rnd.nextInt(_categories.length)];
    final model = pool[rnd.nextInt(pool.length)];
    setState(() {
      _session!.messages[index] = ChatMessage(
        isUser: false,
        modelName: model.name,
        text: '[Regenerated dummy response — UI demo only. From ${model.name}, '
            'category: $category.]',
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
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.8,
                children: _suggestions.map((s) {
                  return _SuggestionCard(text: s, onTap: () => _sendSuggestion(s));
                }).toList(),
              ),
            ],
          ),
        ),
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

        final model = m.modelName == null
            ? null
            : modelStore.models.where((e) => e.name == m.modelName).cast<LlmModel?>().firstOrNull;

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
                    if (m.isUser && m.attachments.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: m.attachments
                            .map((a) => Chip(
                                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                                  label: Text(a, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  side: BorderSide.none,
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (!m.isUser && model != null) ...[
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: model.color,
                            child: Text(model.badgeLetter,
                                style: const TextStyle(fontSize: 10, color: Colors.white)),
                          ),
                          const SizedBox(width: 6),
                          Text(model.name,
                              style: TextStyle(
                                  color: context.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      m.text,
                      style: TextStyle(
                        color: m.isUser ? Colors.white : context.textPrimary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
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

  Widget _buildThinkingBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple),
          ),
          const SizedBox(width: 8),
          Text('Analyzing prompt & selecting best model...',
              style: TextStyle(color: context.textSecondary, fontSize: 12)),
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
