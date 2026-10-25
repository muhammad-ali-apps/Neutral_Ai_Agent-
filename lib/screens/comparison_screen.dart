import 'package:http/http.dart' as http;
import '../widgets/animated_title_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../models.dart';
import '../services/api_services.dart';
import '../widgets/moving_red_border_painter.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_actions.dart';
import '../widgets/copy_toast.dart';
import '../widgets/chat_attachment_view.dart';
import '../widgets/formatted_message_view.dart';
import '../services/attachment_processor.dart';

/// Comparison screen — live side-by-side model comparison backed by dynamic APIs.
class ComparisonScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final ValueChanged<String?>? onSessionChanged;
  const ComparisonScreen({super.key, this.onMenuTap, this.onSessionChanged});

  @override
  State<ComparisonScreen> createState() => ComparisonScreenState();
}

class ComparisonScreenState extends State<ComparisonScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  final Set<String> _selected = <String>{};
  final Set<String> _appliedModelIds = <String>{};
  ChatSession? _session;
  bool _thinking = false;

  final Set<String> _collapsedContainers = <String>{};
  final Set<String> _expandedContainers = <String>{};
  final Set<String> _thinkingCardKeys = <String>{};

  int? _editingIndex;
  TextEditingController? _editController;
  http.Client? _activeClient;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUserPreferencesAndModels();
  }

  @override
  void dispose() {
    _activeClient?.close();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _stopGeneration() {
    _activeClient?.close();
    _activeClient = null;
    setState(() {
      _thinking = false;
      _thinkingCardKeys.clear();
    });
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

  Future<void> _loadUserPreferencesAndModels() async {
    if (modelStore.models.isEmpty) {
      await modelStore.loadFromApi();
    }

    final res = await ApiService.fetchComparisonModels();
    if (!mounted) return;

    if (res != null && res['saved_model_ids'] is List) {
      final savedIds = List<String>.from(res['saved_model_ids']);
      if (savedIds.isNotEmpty) {
        setState(() {
          _selected.clear();
          _selected.addAll(savedIds);
          _appliedModelIds.clear();
          _appliedModelIds.addAll(savedIds);
        });
        return;
      }
    }

    _initDefaultSelection();
  }

  void _initDefaultSelection() {
    final pool = modelStore.models;
    final active = pool.where((m) => m.active).toList();
    final toSelect = active.isNotEmpty ? active : pool;
    setState(() {
      _selected.clear();
      for (final m in toSelect.take(2)) {
        _selected.add(m.id);
      }
      _appliedModelIds.clear();
      _appliedModelIds.addAll(_selected);
    });
  }

  List<LlmModel> get _selectedModels {
    final pool = modelStore.models;
    final selected = pool.where((m) => _selected.contains(m.id)).toList();
    if (selected.isNotEmpty) return selected;
    final active = pool.where((m) => m.active).toList();
    final fallback = active.isNotEmpty ? active : pool;
    return fallback.take(2).toList();
  }

  void _persistModelSelection() async {
    final selectedIds = _selected.toList();
    if (selectedIds.isNotEmpty) {
      await ApiService.updateComparisonModels(selectedIds);
    }
  }

  void _notifySession() => widget.onSessionChanged?.call(_session?.id);

  void startNewChat() {
    setState(() {
      _session = null;
      _editingIndex = null;
      _editController = null;
      _thinking = false;
      _collapsedContainers.clear();
      _expandedContainers.clear();
      _thinkingCardKeys.clear();
    });
    _notifySession();
  }

  /// Called by HomeShell when the user selects a history item in the Sidebar.
  void openSession(ChatSession s) {
    setState(() {
      _session = s;
      _editingIndex = null;
      _editController = null;
      _thinking = false;
      _collapsedContainers.clear();
      _expandedContainers.clear();
      _thinkingCardKeys.clear();
    });
    _notifySession();
    _scrollToBottom(animate: false);
  }

  void _send(String text, List<ChatAttachment> attachments) async {
    if (_thinking || _thinkingCardKeys.isNotEmpty) return;
    if (text.trim().isEmpty && attachments.isEmpty) return;
    final modelsToUse = _selectedModels;
    if (modelsToUse.isEmpty) {
      _scaffoldKey.currentState?.openEndDrawer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select models to compare first')),
      );
      return;
    }

    final selectedIds = modelsToUse.map((m) => m.id).toList();

    setState(() {
      _session ??= ChatSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: text.length > 42
            ? '${text.substring(0, 42)}...'
            : (text.isNotEmpty ? text : (attachments.isNotEmpty ? attachments.first.name : 'Comparison Chat')),
        mode: ChatMode.comparison,
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

    _activeClient = http.Client();
    final enrichedPrompt = AttachmentProcessor.buildEnrichedPrompt(text, attachments);
    final response = await ApiService.sendChatMessage(
      prompt: enrichedPrompt,
      sessionId: _session?.backendSessionId,
      mode: 'compare',
      selectedModels: selectedIds,
      attachments: attachments,
      client: _activeClient,
    );

    if (!mounted || _session == null) return;

    if (response != null) {
      final returnedSessionId = response['session_id']?.toString();
      if (returnedSessionId != null && returnedSessionId.isNotEmpty) {
        _session!.backendSessionId = returnedSessionId;
      }

      final responsesList = response['responses'] as List<dynamic>? ?? [];

      setState(() {
        _thinking = false;
        if (responsesList.isNotEmpty) {
          for (final item in responsesList) {
            final modelName = item['model_name']?.toString() ?? 'AI Model';
            final status = item['status']?.toString() ?? 'success';
            final reply = (status == 'success' && item['reply'] != null)
                ? item['reply'].toString()
                : (item['error']?.toString() ?? 'Model returned empty response');
            final latency = item['latency_ms'] != null
                ? double.tryParse(item['latency_ms'].toString())
                : null;
            final tokenUsage = item['token_usage'] is Map
                ? Map<String, dynamic>.from(item['token_usage'])
                : null;

            _session!.messages.add(ChatMessage(
              isUser: false,
              modelName: modelName,
              text: reply,
              latencyMs: latency,
              tokenUsage: tokenUsage,
              status: status,
              versions: [reply],
              versionLatencies: [latency],
              versionTokenUsages: [tokenUsage],
              currentVersionIndex: 0,
            ));
          }
        } else {
          _session!.messages.add(ChatMessage(
            isUser: false,
            text: response['error']?.toString() ??
                'No model responses returned from backend.',
            status: 'error',
          ));
        }
        historyStore.touch(_session!);
      });
      _scrollToBottom();
    } else {
      if (!mounted || _session == null) return;
      if (_thinking) {
        setState(() {
          _thinking = false;
          _session!.messages.add(ChatMessage(
            isUser: false,
            text: 'Failed to connect to AI comparison server. Please check backend connection.',
            status: 'error',
          ));
          historyStore.touch(_session!);
        });
        _scrollToBottom();
      }
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
    if (_thinking || _thinkingCardKeys.isNotEmpty) return;
    final newText = _editController!.text.trim();
    if (newText.isEmpty) return;
    final modelsToUse = _selectedModels;
    final selectedIds = modelsToUse.map((m) => m.id).toList();

    setState(() {
      _session!.messages[index].text = newText;
      // Remove old AI response group
      int end = index + 1;
      while (end < _session!.messages.length && !_session!.messages[end].isUser) {
        end++;
      }
      if (end > index + 1) {
        _session!.messages.removeRange(index + 1, end);
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
      mode: 'compare',
      selectedModels: selectedIds,
      attachments: messageAttachments,
    );

    if (!mounted || _session == null) return;

    if (response != null) {
      final returnedSessionId = response['session_id']?.toString();
      if (returnedSessionId != null && returnedSessionId.isNotEmpty) {
        _session!.backendSessionId = returnedSessionId;
      }

      final responsesList = response['responses'] as List<dynamic>? ?? [];

      setState(() {
        _thinking = false;
        int insertPos = index + 1;
        if (responsesList.isNotEmpty) {
          for (final item in responsesList) {
            final modelName = item['model_name']?.toString() ?? 'AI Model';
            final status = item['status']?.toString() ?? 'success';
            final reply = (status == 'success' && item['reply'] != null)
                ? item['reply'].toString()
                : (item['error']?.toString() ?? 'Model returned empty response');
            final latency = item['latency_ms'] != null
                ? double.tryParse(item['latency_ms'].toString())
                : null;
            final tokenUsage = item['token_usage'] is Map
                ? Map<String, dynamic>.from(item['token_usage'])
                : null;

            _session!.messages.insert(
              insertPos++,
              ChatMessage(
                isUser: false,
                modelName: modelName,
                text: reply,
                latencyMs: latency,
                tokenUsage: tokenUsage,
                status: status,
                versions: [reply],
                versionLatencies: [latency],
                versionTokenUsages: [tokenUsage],
                currentVersionIndex: 0,
              ),
            );
          }
        }
        historyStore.touch(_session!);
      });
    } else {
      setState(() {
        _thinking = false;
      });
    }
  }

  /// Single model per-container regeneration.
  /// Only regenerates the targeted model without touching any other model in that turn!
  void _regenerateSingleModel(int index, ChatMessage msg) async {
    if (_thinking || _thinkingCardKeys.isNotEmpty) return;
    if (_session == null || index < 1) return;

    // Find the prompt and attachments associated with this turn
    String prompt = '';
    List<ChatAttachment> messageAttachments = [];
    for (int i = index - 1; i >= 0; i--) {
      if (_session!.messages[i].isUser) {
        prompt = _session!.messages[i].text;
        messageAttachments = _session!.messages[i].attachments;
        break;
      }
    }
    if (prompt.isEmpty && messageAttachments.isEmpty) return;

    final targetModelName = msg.modelName;
    final matchingModel = modelStore.models.where((e) => e.name == targetModelName).toList();
    final modelId = matchingModel.isNotEmpty ? matchingModel.first.id : (_selected.isNotEmpty ? _selected.first : '');
    if (modelId.isEmpty) return;

    final cardKey = '${index}_$targetModelName';

    setState(() {
      _thinkingCardKeys.add(cardKey);
    });

    _activeClient = http.Client();
    final enrichedPrompt = AttachmentProcessor.buildEnrichedPrompt(prompt, messageAttachments);
    final response = await ApiService.sendChatMessage(
      prompt: enrichedPrompt,
      sessionId: _session?.backendSessionId,
      mode: 'compare',
      selectedModels: [modelId],
      attachments: messageAttachments,
      client: _activeClient,
    );

    if (!mounted || _session == null) {
      setState(() => _thinkingCardKeys.remove(cardKey));
      return;
    }

    if (response != null) {
      final responsesList = response['responses'] as List<dynamic>? ?? [];
      final matched = responsesList.isNotEmpty
          ? responsesList.firstWhere(
              (r) => r['model_name'] == targetModelName,
              orElse: () => responsesList.first,
            )
          : null;

      if (matched != null) {
        final status = matched['status']?.toString() ?? 'success';
        final newReply = (status == 'success' && matched['reply'] != null)
            ? matched['reply'].toString()
            : (matched['error']?.toString() ?? 'Model returned empty response');
        final newLatency = matched['latency_ms'] != null
            ? double.tryParse(matched['latency_ms'].toString())
            : null;
        final newTokenUsage = matched['token_usage'] is Map
            ? Map<String, dynamic>.from(matched['token_usage'])
            : null;

        setState(() {
          msg.versions ??= [msg.text];
          msg.versionLatencies ??= [msg.latencyMs];
          msg.versionTokenUsages ??= [msg.tokenUsage];

          msg.versions!.add(newReply);
          msg.versionLatencies!.add(newLatency);
          msg.versionTokenUsages!.add(newTokenUsage);

          msg.currentVersionIndex = msg.versions!.length - 1;
          msg.text = newReply;
          msg.latencyMs = newLatency;
          msg.tokenUsage = newTokenUsage;
          msg.status = status;

          _thinkingCardKeys.remove(cardKey);
        });
        historyStore.touch(_session!);
      } else {
        setState(() => _thinkingCardKeys.remove(cardKey));
      }
    } else {
      setState(() => _thinkingCardKeys.remove(cardKey));
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showCopiedToast(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasMessages = _session != null && _session!.messages.isNotEmpty;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bg,
      endDrawer: _buildModelDrawer(context),
      body: Column(
        children: [
          _buildTopBar(context),
          if (_selectedModels.isNotEmpty) _buildSelectedBar(context),
          Expanded(
            child: hasMessages
                ? Stack(
                    children: [
                      _buildChatList(context),
                      _buildScrollToBottomButton(context),
                    ],
                  )
                : _buildEmptyState(context),
          ),
          if (hasMessages)
            ChatInputBar(
              key: const ValueKey('bottom_comparison_input_bar'),
              controller: _controller,
              hint: _selectedModels.isEmpty
                  ? 'Select models to compare...'
                  : 'Ask anything',
              isGenerating: _thinking || _thinkingCardKeys.isNotEmpty,
              onStop: _stopGeneration,
              onSend: _send,
            ),
        ],
      ),
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

            // Only show title & icon in new chats (matching Smart Routing & Offline Mode)
            if (!hasMessages) ...[
              InkWell(
                onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.compare_arrows_rounded, color: Color(0xFFEF4444), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Comparison Mode',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Row(
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
                                'Compare Models',
                                style: TextStyle(color: context.textSecondary, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Sidebar icon without quantity badge
            IconButton(
              tooltip: 'Select models',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              icon: Icon(Icons.view_sidebar_rounded, color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedBar(BuildContext context) {
    return ListenableBuilder(
      listenable: modelStore,
      builder: (context, _) => Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            for (int i = 0; i < _selectedModels.length; i++) ...[
              if (i > 0)
                Text(
                  '•',
                  style: TextStyle(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              Text(
                _selectedModels[i].name,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
                key: const ValueKey('centered_comparison_input_bar'),
                controller: _controller,
                hint: _selectedModels.isEmpty
                    ? 'Select models to compare...'
                    : 'Ask anything',
                isGenerating: _thinking || _thinkingCardKeys.isNotEmpty,
                onStop: _stopGeneration,
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

  Widget _buildChatList(BuildContext context) {
    final messages = _session!.messages;
    final widgets = <Widget>[];
    int i = 0;
    while (i < messages.length) {
      if (i == _editingIndex) {
        widgets.add(Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: MessageEditBox(
              controller: _editController!,
              onCancel: _cancelEdit,
              onConfirm: () => _confirmEdit(i),
            ),
          ),
        ));
        i++;
        continue;
      }
      final m = messages[i];
      if (m.isUser) {
        widgets.add(_userBubble(context, m, i));
        i++;
      } else {
        final group = <MapEntry<int, ChatMessage>>[];
        while (i < messages.length && !messages[i].isUser) {
          group.add(MapEntry(i, messages[i]));
          i++;
        }
        final isLastGroup = i == messages.length;
        widgets.add(_responseGroup(context, group, isLastGroup: isLastGroup));
      }
    }

    if (_thinking) {
      widgets.add(_thinkingResponseGroup(context));
    }

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 500 ? 12 : 20,
        vertical: 16,
      ),
      children: widgets,
    );
  }

  Widget _userBubble(BuildContext context, ChatMessage m, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleMaxWidth = screenWidth < 660 ? screenWidth * 0.90 : 640.0;
    final isDark = context.isDark;

    const claudeUserDark = Color(0xFF262522);
    const claudeBorderDark = Color(0xFF3E3C37);
    const claudeUserLight = Color(0xFFF5F3ED);
    const claudeBorderLight = Color(0xFFE2DFD6);

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? claudeUserDark : claudeUserLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? claudeBorderDark : claudeBorderLight,
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
                if (m.attachments.isNotEmpty)
                  ChatAttachmentsView(attachments: m.attachments, isUser: true),
                SelectionArea(
                  child: Text(
                    m.text,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      fontSize: 14.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          UserMessageActions(onEdit: () => _startEdit(index), onCopy: () => _copy(m.text)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _thinkingResponseGroup(BuildContext context) {
    final selected = _selectedModels;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: selected.map((m) {
            return Container(
              width: 360,
              height: 200,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.name,
                          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFFEF4444)),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Thinking...',
                              style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.0, color: Color(0xFFEF4444)),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Thinking...',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildVersionSwitcher(BuildContext context, ChatMessage m) {
    if (m.versions == null || m.versions!.length <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: context.borderColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: m.currentVersionIndex > 0
                ? () {
                    setState(() {
                      m.currentVersionIndex--;
                      m.text = m.versions![m.currentVersionIndex];
                      if (m.versionLatencies != null && m.currentVersionIndex < m.versionLatencies!.length) {
                        m.latencyMs = m.versionLatencies![m.currentVersionIndex];
                      }
                      if (m.versionTokenUsages != null && m.currentVersionIndex < m.versionTokenUsages!.length) {
                        m.tokenUsage = m.versionTokenUsages![m.currentVersionIndex];
                      }
                    });
                  }
                : null,
            child: Icon(
              Icons.chevron_left_rounded,
              size: 16,
              color: m.currentVersionIndex > 0
                  ? context.textPrimary
                  : context.textSecondary.withValues(alpha: 0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '${m.currentVersionIndex + 1}/${m.versions!.length}',
              style: TextStyle(color: context.textPrimary, fontSize: 10.5, fontWeight: FontWeight.w600),
            ),
          ),
          InkWell(
            onTap: m.currentVersionIndex < m.versions!.length - 1
                ? () {
                    setState(() {
                      m.currentVersionIndex++;
                      m.text = m.versions![m.currentVersionIndex];
                      if (m.versionLatencies != null && m.currentVersionIndex < m.versionLatencies!.length) {
                        m.latencyMs = m.versionLatencies![m.currentVersionIndex];
                      }
                      if (m.versionTokenUsages != null && m.currentVersionIndex < m.versionTokenUsages!.length) {
                        m.tokenUsage = m.versionTokenUsages![m.currentVersionIndex];
                      }
                    });
                  }
                : null,
            child: Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: m.currentVersionIndex < m.versions!.length - 1
                  ? context.textPrimary
                  : context.textSecondary.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _responseGroup(BuildContext context, List<MapEntry<int, ChatMessage>> group, {bool isLastGroup = true}) {
    final isDark = context.isDark;

    // Check if any model container in this turn is expanded in focus mode
    MapEntry<int, ChatMessage>? expandedEntry;
    for (final entry in group) {
      final key = '${entry.key}_${entry.value.modelName}';
      if (_expandedContainers.contains(key)) {
        expandedEntry = entry;
        break;
      }
    }

    // IF A MODEL IS EXPANDED: Show ONLY that model full width & hide all other models!
    if (expandedEntry != null) {
      final index = expandedEntry.key;
      final m = expandedEntry.value;
      final cardKey = '${index}_${m.modelName}';
      final isThinking = _thinkingCardKeys.contains(cardKey);

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          width: double.infinity,
          height: 580.0,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      m.modelName ?? 'AI Model',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  // Version Switcher < 1/2 >
                  if (m.versions != null && m.versions!.length > 1) ...[
                    _buildVersionSwitcher(context, m),
                    const SizedBox(width: 8),
                  ],

                  if (m.latencyMs != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 11, color: Color(0xFFEF4444)),
                          const SizedBox(width: 2),
                          Text(
                            m.latencyMs! >= 1000
                                ? '${(m.latencyMs! / 1000).toStringAsFixed(2)}s'
                                : '${m.latencyMs!.toStringAsFixed(0)}ms',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Token usage chip in expanded view
                  if (m.tokenUsage != null && m.tokenUsage!['total_tokens'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${m.tokenUsage!['total_tokens']} t',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Restore Height Button (Unhides other models and restores horizontal view)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _expandedContainers.remove(cardKey);
                      });
                    },
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: const Icon(
                      Icons.fullscreen_exit_rounded,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),

              Expanded(
                child: isThinking
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFFEF4444)),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Thinking...',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Scrollbar(
                        child: SingleChildScrollView(
                          child: FormattedMessageView(
                            text: m.text,
                            isUser: false,
                            textColor: context.textPrimary,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              AssistantMessageActions(
                onCopy: () => _copy(m.text),
                onRegenerate: isLastGroup && !_thinking && _thinkingCardKeys.isEmpty
                    ? () => _regenerateSingleModel(index, m)
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    // Normal Horizontal Scrollable Cards view showing all selected models side-by-side
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: group.map((entry) {
            final index = entry.key;
            final m = entry.value;
            final cardKey = '${index}_${m.modelName}';

            final isCollapsed = _collapsedContainers.contains(cardKey);
            final isThinking = _thinkingCardKeys.contains(cardKey);

            final isError = m.status == 'error';

            const double cardWidth = 360.0;
            const double cardHeight = 380.0;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: cardWidth,
              height: cardHeight,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isError
                      ? Colors.redAccent.withValues(alpha: 0.5)
                      : (isThinking
                          ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                          : context.borderColor),
                  width: isThinking ? 1.4 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.modelName ?? 'AI Model',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      
                      // Version Switcher < 1/2 >
                      if (m.versions != null && m.versions!.length > 1) ...[
                        _buildVersionSwitcher(context, m),
                        const SizedBox(width: 4),
                      ],

                      if (m.latencyMs != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt_rounded, size: 10, color: Color(0xFFEF4444)),
                              const SizedBox(width: 2),
                              Text(
                                m.latencyMs! >= 1000
                                    ? '${(m.latencyMs! / 1000).toStringAsFixed(2)}s'
                                    : '${m.latencyMs!.toStringAsFixed(0)}ms',
                                style: const TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (m.tokenUsage != null && m.tokenUsage!['total_tokens'] != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.borderColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${m.tokenUsage!['total_tokens']} t',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],

                      // Expand Height Button (Hides all other models and expands this model to full view)
                      // Tooltip removed per user request
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _expandedContainers.add(cardKey);
                          });
                        },
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        icon: Icon(
                          Icons.fullscreen_rounded,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (!isCollapsed) ...[
                    const Divider(height: 14),
                    Expanded(
                      child: isThinking
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.0, color: Color(0xFFEF4444)),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Thinking...',
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Scrollbar(
                              child: SingleChildScrollView(
                                child: FormattedMessageView(
                                  text: m.text,
                                  isUser: false,
                                  textColor: context.textPrimary,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    AssistantMessageActions(
                      onCopy: () => _copy(m.text),
                      onRegenerate: isLastGroup && !_thinking && _thinkingCardKeys.isEmpty
                          ? () => _regenerateSingleModel(index, m)
                          : null,
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildModelDrawer(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;

    // Compact, sleek drawer width (shortened for a balanced, attractive look)
    final double drawerWidth;
    if (screenW < 360) {
      drawerWidth = screenW * 0.84;
    } else if (screenW < 600) {
      drawerWidth = 270.0;
    } else {
      drawerWidth = 285.0;
    }

    return Drawer(
      backgroundColor: context.surface,
      width: drawerWidth,
      child: SafeArea(
        child: _ComparisonModelDrawer(
          initialSelected: _selected,
          appliedIds: _appliedModelIds,
          onApply: (newSelection) {
            setState(() {
              _selected.clear();
              _selected.addAll(newSelection);
              _appliedModelIds.clear();
              _appliedModelIds.addAll(newSelection);
            });
            _persistModelSelection();
          },
        ),
      ),
    );
  }
}

class _ComparisonModelDrawer extends StatefulWidget {
  final Set<String> initialSelected;
  final Set<String> appliedIds;
  final ValueChanged<Set<String>> onApply;

  const _ComparisonModelDrawer({
    required this.initialSelected,
    required this.appliedIds,
    required this.onApply,
  });

  @override
  State<_ComparisonModelDrawer> createState() => _ComparisonModelDrawerState();
}

class _ComparisonModelDrawerState extends State<_ComparisonModelDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beamController;
  late final Set<String> _draftSelected;

  @override
  void initState() {
    super.initState();
    _draftSelected = Set<String>.from(widget.initialSelected);
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

  Widget _buildModelTile(
    BuildContext context,
    LlmModel m,
    bool isSelected,
    bool isApplied,
    bool isDark, {
    required double minHeight,
    required double nameFontSize,
    required double providerFontSize,
    required double dotFontSize,
    required bool isCompact,
  }) {
    final providerEnum = LlmProvider.fromString(m.provider);

    final innerContent = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 15,
        vertical: isCompact ? 6 : 8,
      ),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: m.name,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: nameFontSize,
                  ),
                ),
                if (isApplied)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 4),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF10A37F),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            providerEnum.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: providerFontSize,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );

    return InkWell(
      onTap: () {
        setState(() {
          if (_draftSelected.contains(m.id)) {
            _draftSelected.remove(m.id);
          } else {
            _draftSelected.add(m.id);
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: isSelected
          ? CustomPaint(
              painter: MovingRedBorderPainter(
                progress: _beamController.value,
                borderRadius: 10,
                isDark: isDark,
              ),
              child: innerContent,
            )
          : Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: context.borderColor.withValues(alpha: 0.5),
                  width: 1.0,
                ),
              ),
              child: innerContent,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isCompact = availableWidth < 340;
        final isSpacious = availableWidth >= 420;

        final horizontalPadding = isCompact ? 12.0 : (isSpacious ? 20.0 : 16.0);
        final topPadding = isCompact ? 14.0 : 20.0;
        final bottomPadding = isCompact ? 12.0 : 16.0;
        final tileMinHeight = isCompact ? 50.0 : (isSpacious ? 56.0 : 52.0);
        final nameFontSize = isCompact ? 13.0 : (isSpacious ? 14.5 : 13.5);
        final providerFontSize = isCompact ? 10.5 : (isSpacious ? 12.0 : 11.0);
        final dotFontSize = isCompact ? 16.0 : (isSpacious ? 20.0 : 18.0);
        final applyButtonHeight = isCompact ? 44.0 : (isSpacious ? 48.0 : 46.0);
        final applyFontSize = isCompact ? 13.5 : (isSpacious ? 15.0 : 14.0);

        return Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: modelStore,
                builder: (context, _) {
                  final availableModels = modelStore.models;
                  if (availableModels.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(horizontalPadding),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (modelStore.isLoading)
                              const CircularProgressIndicator(color: Color(0xFFEF4444))
                            else ...[
                              Icon(Icons.widgets_outlined, color: context.textSecondary, size: 36),
                              const SizedBox(height: 12),
                              Text('No models found',
                                  style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Models from backend will appear here once loaded.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: context.textSecondary, fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return AnimatedBuilder(
                    animation: _beamController,
                    builder: (context, _) {
                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, 12),
                        itemCount: availableModels.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final m = availableModels[i];
                          final isSelected = _draftSelected.contains(m.id);
                          final isApplied = widget.appliedIds.contains(m.id);
                          return _buildModelTile(
                            context,
                            m,
                            isSelected,
                            isApplied,
                            isDark,
                            minHeight: tileMinHeight,
                            nameFontSize: nameFontSize,
                            providerFontSize: providerFontSize,
                            dotFontSize: dotFontSize,
                            isCompact: isCompact,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // Apply Button with animated red laser line and responsive sizing
            Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, bottomPadding),
              child: SizedBox(
                width: double.infinity,
                child: AnimatedBuilder(
                  animation: _beamController,
                  builder: (context, _) {
                    return InkWell(
                      onTap: () {
                        widget.onApply(_draftSelected);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: CustomPaint(
                        painter: MovingRedBorderPainter(
                          progress: _beamController.value,
                          borderRadius: 10,
                          isDark: isDark,
                        ),
                        child: Container(
                          height: applyButtonHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Apply',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: applyFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
