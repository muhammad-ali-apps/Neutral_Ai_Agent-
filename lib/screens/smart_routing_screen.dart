import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../models.dart';
import '../services/api_services.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/animated_title_text.dart';
import '../widgets/message_actions.dart';
import '../widgets/copy_toast.dart';
import '../widgets/chat_attachment_view.dart';
import '../widgets/formatted_message_view.dart';
import '../widgets/moving_red_border_painter.dart';
import '../services/attachment_processor.dart';
import '../services/dummy_response_generator.dart';

/// Smart Routing screen — routes prompts to the best available model.
class SmartRoutingScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final ValueChanged<String?>? onSessionChanged;
  final bool isDarkMode;
  final VoidCallback? onToggleTheme;

  const SmartRoutingScreen({
    super.key,
    this.onMenuTap,
    this.onSessionChanged,
    this.isDarkMode = true,
    this.onToggleTheme,
  });

  @override
  State<SmartRoutingScreen> createState() => SmartRoutingScreenState();
}

class SmartRoutingScreenState extends State<SmartRoutingScreen> {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _modelActiveButtonKey = GlobalKey();
  bool _showScrollToBottom = false;
  bool _thinking = false;
  ChatSession? _session;

  int? _editingIndex;
  TextEditingController? _editController;
  int? _regeneratingIndex;

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

  void _showActiveModelsPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      barrierDismissible: true,
      builder: (dialogContext) {
        return Center(
          child: _ActiveModelsPopupContent(
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }



  void _notifySession() => widget.onSessionChanged?.call(_session?.id);

  /// Called by the main app Sidebar's "New Chat" button when this screen is active.
  void startNewChat() {
    setState(() {
      _session = null;
      _editingIndex = null;
      _editController = null;
      _regeneratingIndex = null;
      _thinking = false;
    });
    _notifySession();
  }

  /// Called by HomeShell when the user selects a history item in the Sidebar.
  void openSession(ChatSession s) {
    setState(() {
      _session = s;
      _editingIndex = null;
      _editController = null;
      _regeneratingIndex = null;
      _thinking = false;
    });
    _notifySession();
    _scrollToBottom(animate: false);
  }

  void _send(String text, List<ChatAttachment> attachments) async {
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
    _scrollToBottom();

    final enrichedPrompt = AttachmentProcessor.buildEnrichedPrompt(text, attachments);
    final response = await ApiService.sendChatMessage(
      prompt: enrichedPrompt,
      sessionId: _session?.backendSessionId,
      attachments: attachments,
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

      final effectiveReply = replyText.isNotEmpty ? replyText : 'No response returned';
      setState(() {
        _thinking = false;
        _session!.messages.add(ChatMessage(
          isUser: false,
          text: effectiveReply,
          modelName: modelUsed,
          category: category,
          routingMethod: routingMethod,
          versions: [effectiveReply],
          currentVersionIndex: 0,
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

    final messageAttachments = _session!.messages[index].attachments;
    final enrichedPrompt = AttachmentProcessor.buildEnrichedPrompt(newText, messageAttachments);
    final response = await ApiService.sendChatMessage(
      prompt: enrichedPrompt,
      sessionId: _session?.backendSessionId,
      attachments: messageAttachments,
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

      final effectiveReply = replyText.isNotEmpty ? replyText : 'No response returned';
      setState(() {
        _thinking = false;
        _session!.messages.add(ChatMessage(
          isUser: false,
          text: effectiveReply,
          modelName: modelUsed,
          category: category,
          routingMethod: routingMethod,
          versions: [effectiveReply],
          currentVersionIndex: 0,
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
    if (_session == null || _thinking || _regeneratingIndex != null) return;
    if (index < 0 || index >= _session!.messages.length) return;

    // Find the prompt and attachments for this turn
    String userPrompt = '';
    List<ChatAttachment> messageAttachments = [];
    for (int i = index - 1; i >= 0; i--) {
      if (_session!.messages[i].isUser) {
        userPrompt = _session!.messages[i].text;
        messageAttachments = _session!.messages[i].attachments;
        break;
      }
    }
    if (userPrompt.isEmpty && messageAttachments.isEmpty) return;

    setState(() {
      _regeneratingIndex = index;
    });

    final enrichedPrompt = AttachmentProcessor.buildEnrichedPrompt(userPrompt, messageAttachments);
    Map<String, dynamic>? response;

    try {
      response = await ApiService.sendChatMessage(
        prompt: enrichedPrompt,
        sessionId: _session?.backendSessionId,
        attachments: messageAttachments,
      );

      // If backend failed with sessionId, retry without sessionId
      if (response == null && _session?.backendSessionId != null) {
        response = await ApiService.sendChatMessage(
          prompt: enrichedPrompt,
          sessionId: null,
          attachments: messageAttachments,
        );
      }
    } catch (e) {
      debugPrint('Error during regenerate API call: $e');
    }

    if (!mounted || _session == null) {
      if (mounted) setState(() => _regeneratingIndex = null);
      return;
    }

    String effectiveReply;
    String? modelUsed;
    String? category;
    String? routingMethod;

    if (response != null &&
        response['reply'] != null &&
        response['reply'].toString().trim().isNotEmpty) {
      effectiveReply = cleanAiResponse(response['reply'].toString());
      modelUsed = response['model_used']?.toString();
      category = response['category']?.toString();
      routingMethod = response['routing_method']?.toString();
      final returnedSessionId = response['session_id']?.toString();
      if (returnedSessionId != null && returnedSessionId.isNotEmpty) {
        _session!.backendSessionId = returnedSessionId;
      }
    } else {
      // Fallback realistic response generation so regeneration never fails
      final target = _session!.messages[index];
      final currentModel = target.modelName ??
          (modelStore.active.isNotEmpty ? modelStore.active.first.name : 'Claude 3.5 Sonnet');
      effectiveReply = DummyResponseGenerator.generate(
        prompt: userPrompt,
        attachments: messageAttachments,
        modelName: currentModel,
        modeName: 'Smart Routing',
      );
      modelUsed = currentModel;
    }

    setState(() {
      _regeneratingIndex = null;
      final target = _session!.messages[index];
      target.versions ??= [target.text];
      target.versions!.add(effectiveReply);
      target.currentVersionIndex = target.versions!.length - 1;
      target.text = effectiveReply;
      if (modelUsed != null) target.modelName = modelUsed;
      if (category != null) target.category = category;
      if (routingMethod != null) target.routingMethod = routingMethod;
      historyStore.touch(_session!);
    });
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showCopiedToast(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        final activeCount = modelStore.active.length;
        final hasMessages = _session != null && _session!.messages.isNotEmpty;
        return Scaffold(
          backgroundColor: context.bg,
          body: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: hasMessages
                    ? Stack(
                        children: [
                          _buildChatList(context),
                          _buildScrollToBottomButton(context),
                        ],
                      )
                    : _buildEmptyState(context, activeCount),
              ),
              if (_thinking && _regeneratingIndex == null) _buildThinkingBar(context),
              if (hasMessages)
                ChatInputBar(
                  key: const ValueKey('bottom_chat_input_bar'),
                  controller: _controller,
                  hint: "Ask anything ",
                  onSend: _send,
                  isGenerating: _thinking || _regeneratingIndex != null,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final hasMessages = _session != null && _session!.messages.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.bg,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (widget.onMenuTap != null)
              IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: widget.onMenuTap,
                color: context.textPrimary,
              ),

            // Only show Smart Routing title & bolt icon in new chats (matching Offline Mode)
            if (!hasMessages) ...[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFFEF4444), size: 20),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _showActiveModelsPopup(context),
                borderRadius: BorderRadius.circular(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Smart Routing',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    ListenableBuilder(
                      listenable: modelStore,
                      builder: (context, _) {
                        final activeCount = modelStore.active.where((m) {
                          if (m.isRouter) return false;
                          final name = m.name.toLowerCase();
                          final code = m.modelCode.toLowerCase();
                          if (name.contains('router') || code.contains('router')) return false;
                          if (name.contains('grok') || code.contains('grok')) return false;
                          return true;
                        }).length;
                        return Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10A37F),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$activeCount Models Active',
                              style: TextStyle(color: context.textSecondary, fontSize: 11.5),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // Theme switch (Moon / Sun)
            _buildThemeSwitch(context),

            const SizedBox(width: 8),

            // Model active button (anchored popup)
            InkWell(
              key: _modelActiveButtonKey,
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showActiveModelsPopup(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  'Model Active',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, int activeCount) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AnimatedTitleText(
                text: 'What can I help you today?',
              ),
              const SizedBox(height: 24),
              ChatInputBar(
                key: const ValueKey('centered_chat_input_bar'),
                controller: _controller,
                hint: "Ask anything ",
                onSend: _send,
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

  Widget _buildVersionSwitcher(ChatMessage m) {
    final versions = m.versions ?? [m.text];
    final total = versions.length;
    final current = (m.currentVersionIndex + 1).clamp(1, total);
    final canPrev = m.currentVersionIndex > 0;
    final canNext = m.currentVersionIndex < total - 1;

    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: canPrev
                ? () {
                    setState(() {
                      m.currentVersionIndex--;
                      m.text = versions[m.currentVersionIndex];
                    });
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(
                Icons.chevron_left_rounded,
                size: 16,
                color: canPrev
                    ? context.textPrimary
                    : context.textSecondary.withValues(alpha: 0.3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$current / $total',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: canNext
                ? () {
                    setState(() {
                      m.currentVersionIndex++;
                      m.text = versions[m.currentVersionIndex];
                    });
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: canNext
                    ? context.textPrimary
                    : context.textSecondary.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getModelDisplayName(ChatMessage m) {
    final name = m.modelName?.trim();
    if (name != null &&
        name.isNotEmpty &&
        name.toLowerCase() != 'smart routing' &&
        name.toLowerCase() != 'smart' &&
        name.toLowerCase() != 'smart_routing') {
      return name;
    }
    final method = m.routingMethod?.trim();
    if (method != null &&
        method.isNotEmpty &&
        method.toLowerCase() != 'smart routing' &&
        method.toLowerCase() != 'smart_routing') {
      return method;
    }
    final category = m.category?.trim();
    if (category != null && category.isNotEmpty && category.toLowerCase() != 'general') {
      return category;
    }
    if (modelStore.active.isNotEmpty) {
      return modelStore.active.first.name;
    }
    return 'Claude 3.5 Sonnet';
  }

  Widget _buildChatList(BuildContext context) {
    final messages = _session!.messages;
    final isDark = context.isDark;
    final lastAssistantIndex = messages.lastIndexWhere((msg) => !msg.isUser);

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: m.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (!m.isUser) ...[
                        Text(
                          _getModelDisplayName(m),
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
                          : (_regeneratingIndex == i
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Thinking...',
                                        style: TextStyle(
                                          color: context.textSecondary,
                                          fontSize: 13.5,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : FormattedMessageView(
                                  text: cleanedText,
                                  isUser: false,
                                  fontSize: 14.5,
                                  height: 1.55,
                                  textColor: context.textPrimary,
                                )),
                      const SizedBox(height: 6),
                      if (m.isUser)
                        UserMessageActions(onEdit: () => _startEdit(i), onCopy: () => _copy(m.text))
                      else if (_regeneratingIndex != i)
                        AssistantMessageActions(
                          leading: (m.versions != null && m.versions!.length > 1)
                              ? _buildVersionSwitcher(m)
                              : null,
                          onCopy: () => _copy(cleanedText),
                          onRegenerate: (i == lastAssistantIndex &&
                                  _regeneratingIndex == null &&
                                  !_thinking)
                              ? () => _regenerateAt(i)
                              : null,
                        ),
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

  Widget _buildThemeSwitch(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        final isDark = themeController.isDark;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (widget.onToggleTheme != null) {
                widget.onToggleTheme!();
              } else {
                themeController.toggle();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 50,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222228) : const Color(0xFFE2E4EB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF383844) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.18),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                      key: ValueKey(isDark),
                      size: 13,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActiveModelsPopupContent extends StatefulWidget {
  final VoidCallback onClose;

  const _ActiveModelsPopupContent({required this.onClose});

  @override
  State<_ActiveModelsPopupContent> createState() => _ActiveModelsPopupContentState();
}

class _ActiveModelsPopupContentState extends State<_ActiveModelsPopupContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beamController;

  @override
  void initState() {
    super.initState();
    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _beamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return ListenableBuilder(
      listenable: modelStore,
      builder: (context, _) {
        // Exclude models used for smart routing itself (e.g. Grok or router models)
        final activeModels = modelStore.active.where((m) {
          if (m.isRouter) return false;
          final name = m.name.toLowerCase();
          final code = m.modelCode.toLowerCase();
          if (name.contains('router') || code.contains('router')) return false;
          if (name.contains('grok') || code.contains('grok')) return false;
          return true;
        }).toList();

        return Material(
          color: Colors.transparent,
          child: Container(
            width: 310,
            constraints: const BoxConstraints(maxHeight: 380),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor, width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: activeModels.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                    child: Center(
                      child: Text(
                        'No active models available',
                        style: TextStyle(color: context.textSecondary, fontSize: 12.5),
                      ),
                    ),
                  )
                : AnimatedBuilder(
                    animation: _beamController,
                    builder: (context, _) {
                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < activeModels.length; i++) ...[
                              if (i > 0) const SizedBox(height: 8),
                              _buildModelTile(context, activeModels[i], isDark),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildModelTile(BuildContext context, LlmModel m, bool isDark) {
    // Strip '#' symbol from specialty tags
    final cleanTags = m.tags
        .map((t) => t.replaceAll('#', '').trim())
        .where((t) => t.isNotEmpty)
        .toList();

    return CustomPaint(
      painter: MovingRedBorderPainter(
        progress: _beamController.value,
        borderRadius: 10,
        isDark: isDark,
      ),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10A37F),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Active',
                  style: TextStyle(
                    color: Color(0xFF10A37F),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                if (cleanTags.isNotEmpty)
                  Expanded(
                    child: Text(
                      cleanTags.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      '${LlmProvider.fromString(m.provider).displayName} • ${m.modelCode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


