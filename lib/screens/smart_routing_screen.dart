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
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  bool _thinking = false;
  ChatSession? _session;

  int? _editingIndex;
  TextEditingController? _editController;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (modelStore.models.isEmpty) {
      modelStore.loadFromApi();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final show = (maxScroll - currentScroll) > 120;
    if (show != _showScrollToBottom) {
      setState(() => _showScrollToBottom = show);
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _showActiveModelsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return ListenableBuilder(
          listenable: modelStore,
          builder: (context, _) {
            final activeModels = modelStore.active;

            return Dialog(
              backgroundColor: context.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: context.borderColor),
              ),
              child: Container(
                width: 520,
                constraints: const BoxConstraints(maxHeight: 600),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.bolt_rounded, color: AppColors.success, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active AI Models',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                '${activeModels.length} active models available for smart routing',
                                style: TextStyle(color: context.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: Icon(Icons.close_rounded, color: context.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: context.borderColor, height: 1),
                    const SizedBox(height: 14),
                    Expanded(
                      child: activeModels.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.widgets_outlined, color: context.textSecondary, size: 40),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No active models found',
                                    style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Make sure models are created and set to active.',
                                    style: TextStyle(color: context.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: activeModels.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final m = activeModels[index];
                                final providerEnum = LlmProvider.fromString(m.provider);
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: context.surface2,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: context.borderColor),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: m.color,
                                        child: Text(
                                          m.badgeLetter,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    m.name,
                                                    style: TextStyle(
                                                      color: context.textPrimary,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.success.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      CircleAvatar(radius: 3, backgroundColor: AppColors.success),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Active',
                                                        style: TextStyle(
                                                          color: AppColors.success,
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${providerEnum.displayName} • ${m.modelCode}',
                                              style: TextStyle(color: context.textSecondary, fontSize: 11.5),
                                            ),
                                            if (m.description != null && m.description!.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                m.description!,
                                                style: TextStyle(color: context.textSecondary, fontSize: 11.5),
                                              ),
                                            ],
                                            if (m.tags.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: m.tags.map((tag) {
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.purple.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '#$tag',
                                                      style: const TextStyle(
                                                        color: AppColors.purple,
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

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
    _scrollToBottom(animate: false);
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
        historyStore.touch(_session!);
      });
    } else {
      setState(() {
        _thinking = false;
        _session!.messages.add(ChatMessage(
          isUser: false,
          text: 'Failed to connect to AI server.',
        ));
        historyStore.touch(_session!);
      });
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
              builder: (context, _) {
                final count = modelStore.active.length;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showActiveModelsDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(radius: 3.5, backgroundColor: AppColors.success),
                        const SizedBox(width: 6),
                        Text('$count models active',
                            style: const TextStyle(
                                color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.success),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                hasMessages ? _buildChatList(context) : _buildEmptyState(context, activeCount),
                if (hasMessages) _buildScrollToBottomButton(context),
              ],
            ),
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

  Widget _buildScrollToBottomButton(BuildContext context) {
    return Positioned(
      right: 24,
      bottom: 16,
      child: AnimatedOpacity(
        opacity: _showScrollToBottom ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_showScrollToBottom,
          child: Material(
            color: context.surface2,
            elevation: 4,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _scrollToBottom(animate: true),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.borderColor, width: 1.2),
                ),
                child: const Icon(
                  Icons.arrow_downward_rounded,
                  color: AppColors.purple,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatList(BuildContext context) {
    final messages = _session!.messages;
    final isDark = context.isDark;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];

        if (i == _editingIndex) {
          return Center(
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
                        Text(
                          m.modelName ?? 'Smart Routing',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
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
