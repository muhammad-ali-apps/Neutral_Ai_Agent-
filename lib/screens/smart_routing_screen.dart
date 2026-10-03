import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../app_theme.dart';
import '../models.dart';
import '../services/api_services.dart';
import '../widgets/screen_header.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_actions.dart';
import '../widgets/copy_toast.dart';
import '../widgets/chat_attachment_view.dart';
import '../widgets/prompt_jump_bar.dart';

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

  // Auto-scroll & jump anchors
  final _scrollController = ScrollController();
  final List<GlobalKey> _messageKeys = [];

  final _suggestions = const [
    'Write a Python function to sort a list',
    'Explain quantum entanglement',
    'Write a short poem about the sea',
    'Solve: 2x² + 5x - 3 = 0',
  ];

  void _notifySession() => widget.onSessionChanged?.call(_session?.id);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToMessage(int index) {
    if (index < 0 || index >= _messageKeys.length) return;
    final ctx = _messageKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        alignment: 0.0,
      );
    } else if (_scrollController.hasClients) {
      final totalMessages = _session?.messages.length ?? 1;
      final ratio = index / (totalMessages > 1 ? totalMessages - 1 : 1);
      final targetOffset = (ratio * _scrollController.position.maxScrollExtent)
          .clamp(0.0, _scrollController.position.maxScrollExtent);

      _scrollController.jumpTo(targetOffset);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final delayedCtx = _messageKeys[index].currentContext;
        if (delayedCtx != null) {
          Scrollable.ensureVisible(
            delayedCtx,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: 0.0,
          );
        }
      });
    }
  }

  /// Called by the main app Sidebar's "New Chat" button when this screen is active.
  void startNewChat() {
    setState(() {
      _session = null;
      _editingIndex = null;
      _editController = null;
      _messageKeys.clear();
    });
    _notifySession();
  }

  /// Called by HomeShell when the user selects a history item in the Sidebar.
  void openSession(ChatSession s) {
    setState(() {
      _session = s;
      _editingIndex = null;
      _editController = null;
      _messageKeys.clear();
      for (int i = 0; i < s.messages.length; i++) {
        _messageKeys.add(GlobalKey());
      }
    });
    _notifySession();
    _scrollToBottom();
  }

  void _send(String text, List<ChatAttachment> attachments) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _session ??= ChatSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: text.length > 42 ? '${text.substring(0, 42)}...' : (text.isNotEmpty ? text : (attachments.isNotEmpty ? attachments.first.name : 'New Chat')),
        mode: ChatMode.smartRouting,
      );
      final isNew = !historyStore.sessions.contains(_session);
      _session!.messages.add(ChatMessage(isUser: true, text: text, attachments: attachments));
      _messageKeys.add(GlobalKey());
      if (isNew) {
        historyStore.addSession(_session!);
      } else {
        historyStore.touch(_session!);
      }
      _thinking = true;
    });
    _notifySession();
    _scrollToBottom();

    final response = await ApiService.sendChatMessage(
      prompt: text,
      sessionId: _session?.backendSessionId,
    );

    if (!mounted || _session == null) return;

    if (response != null) {
      final replyText = cleanAiResponse(response['reply']);
      final modelUsed = response['model_used']?.toString();
      final category = response['category']?.toString();
      final routingMethod = response['routing_method']?.toString();
      final returnedSessionId = response['session_id']?.toString();

      if (returnedSessionId != null && returnedSessionId.isNotEmpty) {
        _session!.backendSessionId = returnedSessionId;
      }

      setState(() {
        _thinking = false;
        _session!.messages.add(ChatMessage(
          isUser: false,
          text: replyText.isNotEmpty ? replyText : 'No response returned',
          modelName: modelUsed,
          category: category,
          routingMethod: routingMethod,
        ));
        _messageKeys.add(GlobalKey());
        historyStore.touch(_session!);
      });
      _scrollToBottom();
    } else {
      setState(() {
        _thinking = false;
        _session!.messages.add(ChatMessage(
          isUser: false,
          text: 'Failed to connect to AI server. Please check your backend connection.',
        ));
        _messageKeys.add(GlobalKey());
        historyStore.touch(_session!);
      });
      _scrollToBottom();
    }
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

  void _confirmEdit(int index) async {
    final newText = _editController!.text.trim();
    if (newText.isEmpty) return;
    setState(() {
      _session!.messages[index].text = newText;
      // Drop the old AI response(s) that followed this prompt
      if (_session!.messages.length > index + 1) {
        _session!.messages.removeRange(index + 1, _session!.messages.length);
        _messageKeys.removeRange(index + 1, _messageKeys.length);
      }
      _editingIndex = null;
      _editController = null;
      _thinking = true;
    });
    historyStore.touch(_session!);

    final response = await ApiService.sendChatMessage(
      prompt: newText,
      sessionId: _session?.backendSessionId,
    );

    if (!mounted || _session == null) return;

    if (response != null) {
      final replyText = cleanAiResponse(response['reply']);
      final modelUsed = response['model_used']?.toString();
      final category = response['category']?.toString();
      final routingMethod = response['routing_method']?.toString();
      final returnedSessionId = response['session_id']?.toString();

      if (returnedSessionId != null && returnedSessionId.isNotEmpty) {
        _session!.backendSessionId = returnedSessionId;
      }

      setState(() {
        _thinking = false;
        _session!.messages.add(ChatMessage(
          isUser: false,
          text: replyText.isNotEmpty ? replyText : 'No response returned',
          modelName: modelUsed,
          category: category,
          routingMethod: routingMethod,
        ));
        _messageKeys.add(GlobalKey());
        historyStore.touch(_session!);
      });
      _scrollToBottom();
    } else {
      setState(() {
        _thinking = false;
        _session!.messages.add(ChatMessage(
          isUser: false,
          text: 'Failed to connect to AI server.',
        ));
        _messageKeys.add(GlobalKey());
        historyStore.touch(_session!);
      });
      _scrollToBottom();
    }
  }

  void _regenerateAt(int index) async {
    if (_session == null || index < 1) return;
    final userPrompt = _session!.messages[index - 1].text;
    if (userPrompt.isEmpty) return;

    setState(() {
      _thinking = true;
    });

    final response = await ApiService.sendChatMessage(
      prompt: userPrompt,
      sessionId: _session?.backendSessionId,
    );

    if (!mounted || _session == null) return;

    if (response != null) {
      final replyText = cleanAiResponse(response['reply']);
      final modelUsed = response['model_used']?.toString();
      final category = response['category']?.toString();
      final routingMethod = response['routing_method']?.toString();

      setState(() {
        _thinking = false;
        _session!.messages[index] = ChatMessage(
          isUser: false,
          text: replyText.isNotEmpty ? replyText : 'No response returned',
          modelName: modelUsed,
          category: category,
          routingMethod: routingMethod,
        );
        historyStore.touch(_session!);
      });
    } else {
      setState(() {
        _thinking = false;
      });
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showCopiedToast(context);
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = modelStore.active.length;
    final hasMessages = _session != null && _session!.messages.isNotEmpty;
    // Count only user messages for jump bar threshold
    final userMsgCount = _session?.messages.where((m) => m.isUser).length ?? 0;
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
            child: Stack(
              children: [
                hasMessages ? _buildChatList(context) : _buildEmptyState(context, activeCount),
                // Jump anchors — show when 5+ user messages
                if (userMsgCount >= 5)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: PromptJumpBar(
                      messages: _session!.messages,
                      messageKeys: _messageKeys,
                      onJump: _scrollToMessage,
                    ),
                  ),
              ],
            ),
          ),
          if (_thinking) _buildThinkingBar(context),
          ChatInputBar(
            controller: _controller,
            hint: _thinking ? "AI is responding..." : "Ask anything...",
            isLoading: _thinking,
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
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.openaiGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 20),
              Text(
                'What can I help with today?',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;
                  return GridView.count(
                    crossAxisCount: isNarrow ? 1 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isNarrow ? 4.8 : 3.0,
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
    final isDark = context.isDark;

    // Ensure keys list matches message count
    while (_messageKeys.length < messages.length) {
      _messageKeys.add(GlobalKey());
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];

        if (i == _editingIndex) {
          return Center(
            key: _messageKeys[i],
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.centerRight,
              child: MessageEditBox(
                controller: _editController!,
                onCancel: _cancelEdit,
                onConfirm: () => _confirmEdit(i),
              ),
            ),
          );
        }

        final cleanedText = m.isUser ? m.text : cleanAiResponse(m.text);

        return Center(
          key: _messageKeys[i],
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!m.isUser) ...[
                  Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(top: 2, right: 12),
                    decoration: const BoxDecoration(
                      color: AppColors.openaiGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: m.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (!m.isUser) ...[
                        Row(
                          children: [
                            Text(
                              m.modelName ?? 'Smart Routing',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (m.category != null && m.category!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.openaiGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  m.category!,
                                  style: const TextStyle(
                                    color: AppColors.openaiGreen,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            if (m.routingMethod != null && m.routingMethod!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.geminiBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  m.routingMethod == 'llm_router' ? 'LLM Router' : m.routingMethod!,
                                  style: const TextStyle(
                                    color: AppColors.geminiBlue,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      m.isUser
                          ? Container(
                              constraints: const BoxConstraints(maxWidth: 600),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2F2F2F) : const Color(0xFFF4F4F4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E5E5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (m.attachments.isNotEmpty) ...[
                                    ChatAttachmentsView(attachments: m.attachments, isUser: true),
                                    const SizedBox(height: 6),
                                  ],
                                  SelectionArea(
                                    child: Text(
                                      m.text,
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 14.5,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GptMarkdown(
                              cleanedText,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14.5,
                                height: 1.55,
                              ),
                            ),
                      const SizedBox(height: 6),
                      m.isUser
                          ? UserMessageActions(onEdit: () => _startEdit(i), onCopy: () => _copy(m.text))
                          : AssistantMessageActions(onCopy: () => _copy(cleanedText), onRegenerate: () => _regenerateAt(i)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThinkingBar(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.openaiGreen),
            ),
            const SizedBox(width: 10),
            Text(
              'Thinking...',
              style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
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
    final isDark = context.isDark;
    return Material(
      color: isDark ? const Color(0xFF212121) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        hoverColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E5E5),
              width: 1.1,
            ),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
