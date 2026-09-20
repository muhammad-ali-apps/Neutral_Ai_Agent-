import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;
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

    final response = await ApiService.sendChatMessage(
      prompt: text,
      sessionId: _session?.backendSessionId,
    );

    if (!mounted || _session == null) return;

    if (response != null) {
      final replyText = response['reply']?.toString() ?? 'No response returned';
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
          text: replyText,
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
          text: 'Failed to connect to AI server. Please check your backend connection.',
        ));
        historyStore.touch(_session!);
      });
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
      final replyText = response['reply']?.toString() ?? 'No response returned';
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
          text: replyText,
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
      final replyText = response['reply']?.toString() ?? 'No response returned';
      final modelUsed = response['model_used']?.toString();
      final category = response['category']?.toString();
      final routingMethod = response['routing_method']?.toString();

      setState(() {
        _thinking = false;
        _session!.messages[index] = ChatMessage(
          isUser: false,
          text: replyText,
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
              Text(
                'Smart Routing Mode',
                style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
              ),
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
                    if (m.isUser && m.attachments.isNotEmpty) ...[
                      ChatAttachmentsView(attachments: m.attachments, isUser: true),
                      const SizedBox(height: 6),
                    ],
                    if (!m.isUser) ...[
                      Row(
                        children: [
                          if (model != null) ...[
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: model.color,
                              child: Text(model.badgeLetter,
                                  style: const TextStyle(fontSize: 10, color: Colors.white)),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(m.modelName ?? 'AI Model',
                              style: TextStyle(
                                  color: context.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                          if (m.category != null && m.category!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.purple.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                m.category!,
                                style: const TextStyle(color: AppColors.purple, fontSize: 10, fontWeight: FontWeight.w600),
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
                                style: const TextStyle(color: AppColors.geminiBlue, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    m.isUser
                        ? SelectionArea(
                            child: Text(
                              m.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          )
                        : SelectionArea(
                            child: MarkdownBody(
                              data: m.text,
                              shrinkWrap: true,
                              builders: {
                                'latex': LatexElementBuilder(
                                  textStyle: TextStyle(color: context.textPrimary, fontSize: 14),
                                ),
                              },
                              extensionSet: md.ExtensionSet(
                                [LatexBlockSyntax()],
                                [LatexInlineSyntax()],
                              ),
                              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                p: TextStyle(color: context.textPrimary, fontSize: 14, height: 1.45),
                                h1: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                                h2: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                h3: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                                strong: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
                                em: TextStyle(color: context.textPrimary, fontStyle: FontStyle.italic),
                                code: TextStyle(
                                  color: AppColors.purple,
                                  backgroundColor: context.surface.withValues(alpha: 0.5),
                                  fontSize: 12.5,
                                  fontFamily: 'monospace',
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: context.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.borderColor),
                                ),
                                listBullet: TextStyle(color: context.textPrimary, fontSize: 14),
                              ),
                            ),
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
