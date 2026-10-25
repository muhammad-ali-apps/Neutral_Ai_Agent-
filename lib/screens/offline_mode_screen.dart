import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/animated_title_text.dart';
import '../app_theme.dart';
import '../models.dart';
import '../services/ollama_service.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_actions.dart';
import '../widgets/copy_toast.dart';
import '../widgets/chat_attachment_view.dart';
import '../widgets/formatted_message_view.dart';
import '../widgets/offline_models_manager_dialog.dart';
import '../services/model_download_manager.dart';
import '../services/attachment_processor.dart';

const Color _errorColor = Color(0xFFEF4444);

enum EngineStatus { checking, ready, stopped, notInstalled, installing }

/// Production-ready Offline Mode screen powered by local Ollama runtime.
class OfflineModeScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final ValueChanged<String?>? onSessionChanged;
  const OfflineModeScreen({super.key, this.onMenuTap, this.onSessionChanged});

  @override
  State<OfflineModeScreen> createState() => OfflineModeScreenState();
}

class OfflineModeScreenState extends State<OfflineModeScreen> with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  EngineStatus _engineStatus = EngineStatus.checking;
  String _statusMessage = 'Connecting to local AI engine...';
  double _installProgress = 0.0;

  List<InstalledModel> _installedModels = [];
  String? _selectedModelTag;

  StreamSubscription? _chatStreamSub;
  StreamSubscription? _modelCompletedSub;
  bool _isGenerating = false;

  ChatSession? _session;
  int? _editingIndex;
  TextEditingController? _editController;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeLocalEngine();
    modelDownloadManager.addListener(_onDownloadManagerChanged);
    _modelCompletedSub = modelDownloadManager.onModelCompleted.listen((modelId) {
      if (!mounted) return;
      _loadModels();
    });
  }

  void _onDownloadManagerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    _chatStreamSub?.cancel();
    _modelCompletedSub?.cancel();
    modelDownloadManager.removeListener(_onDownloadManagerChanged);
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _initializeLocalEngine() async {
    setState(() {
      _engineStatus = EngineStatus.checking;
      _statusMessage = 'Checking local Ollama service...';
    });

    final isRunning = await OllamaService.ensureOllamaRunning();
    if (isRunning) {
      await _loadModels();
      setState(() {
        _engineStatus = EngineStatus.ready;
        _statusMessage = 'Engine active and ready';
      });
    } else {
      // Check if binary exists
      final binPath = await OllamaService.findOllamaBinary();
      if (binPath != null) {
        setState(() {
          _engineStatus = EngineStatus.stopped;
          _statusMessage = 'Ollama is installed but not running.';
        });
      } else {
        setState(() {
          _engineStatus = EngineStatus.notInstalled;
          _statusMessage = 'Ollama engine is not installed on this system.';
        });
      }
    }
  }

  Future<void> _loadModels() async {
    final installed = await OllamaService.getInstalledModels();

    if (!mounted) return;
    setState(() {
      _installedModels = installed;

      if (_installedModels.isNotEmpty) {
        if (_selectedModelTag == null || !_installedModels.any((m) => m.modelTag == _selectedModelTag)) {
          _selectedModelTag = _installedModels.first.modelTag;
        }
      } else {
        _selectedModelTag = null;
      }
    });
  }

  void _notifySession() => widget.onSessionChanged?.call(_session?.id);

  void startNewChat() {
    _chatStreamSub?.cancel();
    setState(() {
      _session = null;
      _editingIndex = null;
      _editController = null;
      _isGenerating = false;
    });
    _notifySession();
  }

  void openSession(ChatSession s) {
    _chatStreamSub?.cancel();
    setState(() {
      _session = s;
      _editingIndex = null;
      _editController = null;
      _isGenerating = false;
    });
    _notifySession();
    _scrollToBottom(animate: false);
  }

  /// Start One-Click Automated Silent Setup
  Future<void> _startAutoInstall() async {
    setState(() {
      _engineStatus = EngineStatus.installing;
      _installProgress = 0.05;
      _statusMessage = 'Starting one-click setup...';
    });

    try {
      await for (final progress in OllamaService.autoInstallOllamaOnWindows(
        onStatus: (msg) {
          if (mounted) setState(() => _statusMessage = msg);
        },
      )) {
        if (mounted) {
          setState(() => _installProgress = progress);
        }
      }

      await _initializeLocalEngine();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _engineStatus = EngineStatus.notInstalled;
        _statusMessage = 'Auto-installation failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Installation error: $e'),
          backgroundColor: _errorColor,
        ),
      );
    }
  }



  /// User sends a prompt
  void _send(String text, List<ChatAttachment> attachments) {
    if (_isGenerating) return;
    if (text.trim().isEmpty && attachments.isEmpty) return;

    if (_engineStatus != EngineStatus.ready) {
      _showModelManagerModal();
      return;
    }

    if (_installedModels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please download at least one offline model first!'),
          backgroundColor: Colors.orange,
        ),
      );
      _showModelManagerModal();
      return;
    }

    final activeModel = _selectedModelTag ?? _installedModels.first.modelTag;

    setState(() {
      _session ??= ChatSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: text.length > 42 ? '${text.substring(0, 42)}...' : (text.isNotEmpty ? text : 'Offline Chat'),
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
    _scrollToBottom();
    _streamAiResponse(prompt: text, model: activeModel, attachments: attachments);
  }

  bool _isVisionModel(String tag) {
    final lower = tag.toLowerCase();
    return lower.contains('moondream') ||
        lower.contains('llava') ||
        lower.contains('vision') ||
        lower.contains('bakllava') ||
        lower.contains('minicpm-v');
  }

  /// Stream AI response live token-by-token directly from local Ollama with document and image support
  void _streamAiResponse({
    required String prompt,
    required String model,
    List<ChatAttachment> attachments = const [],
    ChatMessage? existingMessage,
  }) {
    _chatStreamSub?.cancel();

    // Check if current request or past turn contains images
    final hasImageAttachments = attachments.any((a) => a.isImage) ||
        (_session?.messages.any((m) => m.isUser && m.attachments.any((a) => a.isImage)) ?? false);

    String effectiveModel = model;
    // Auto-switch to an installed vision model if user provided images and current model is text-only
    if (hasImageAttachments && !_isVisionModel(model)) {
      final installedVision = _installedModels.where((m) => _isVisionModel(m.modelTag)).toList();
      if (installedVision.isNotEmpty) {
        effectiveModel = installedVision.first.modelTag;
        setState(() => _selectedModelTag = effectiveModel);
      }
    }

    final bool canSendImagesToModel = _isVisionModel(effectiveModel);

    // Prepare message history for context with rich documents & base64 images
    final List<Map<String, dynamic>> messagesPayload = [];
    if (_session != null) {
      for (final m in _session!.messages) {
        // Exclude the existing message being regenerated from historical context
        if (existingMessage != null && identical(m, existingMessage)) {
          continue;
        }
        if (m.isUser) {
          final enrichedContent = AttachmentProcessor.buildEnrichedPrompt(m.text, m.attachments);
          final Map<String, dynamic> userMsg = {
            'role': 'user',
            'content': enrichedContent,
          };
          if (canSendImagesToModel) {
            final b64Images = AttachmentProcessor.extractBase64Images(m.attachments);
            if (b64Images.isNotEmpty) {
              userMsg['images'] = b64Images;
            }
          }
          messagesPayload.add(userMsg);
        } else {
          if (m.text.isNotEmpty) {
            messagesPayload.add({
              'role': 'assistant',
              'content': m.text,
            });
          }
        }
      }
    } else {
      final enrichedPrompt = AttachmentProcessor.buildEnrichedPrompt(prompt, attachments);
      final Map<String, dynamic> userMsg = {
        'role': 'user',
        'content': enrichedPrompt,
      };
      if (canSendImagesToModel) {
        final b64Images = AttachmentProcessor.extractBase64Images(attachments);
        if (b64Images.isNotEmpty) {
          userMsg['images'] = b64Images;
        }
      }
      messagesPayload.add(userMsg);
    }

    final ChatMessage assistantMsg;
    if (existingMessage != null) {
      assistantMsg = existingMessage;
      assistantMsg.modelName = effectiveModel;
      if (assistantMsg.versions == null || assistantMsg.versions!.isEmpty) {
        assistantMsg.versions = [assistantMsg.text];
      }
      assistantMsg.versions!.add('');
      assistantMsg.currentVersionIndex = assistantMsg.versions!.length - 1;
      assistantMsg.text = '';
      setState(() {
        _isGenerating = true;
      });
    } else {
      assistantMsg = ChatMessage(
        isUser: false,
        modelName: effectiveModel,
        text: (hasImageAttachments && !canSendImagesToModel)
            ? '> ⚠️ **Vision Model Required:** The active offline model (`$effectiveModel`) is text-only. While code and text documents are analyzed directly, visual image inspection requires a vision model like **Moondream 2 (Vision 1.8B)** or **LLaVA (7B)** from the Models Manager.\n\n'
            : '',
        versions: [],
        currentVersionIndex: 0,
      );

      setState(() {
        _session!.messages.add(assistantMsg);
        _isGenerating = true;
      });
    }

    _scrollToBottom();

    _chatStreamSub = OllamaService.chatStream(
      model: effectiveModel,
      messages: messagesPayload,
    ).listen(
      (chunk) {
        if (!mounted || _session == null) return;
        setState(() {
          assistantMsg.text += chunk;
          if (assistantMsg.versions != null && assistantMsg.versions!.isNotEmpty) {
            assistantMsg.versions![assistantMsg.currentVersionIndex] = assistantMsg.text;
          }
        });
        _scrollToBottom(animate: false);
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
          if (assistantMsg.versions == null || assistantMsg.versions!.isEmpty) {
            assistantMsg.versions = [assistantMsg.text];
            assistantMsg.currentVersionIndex = 0;
          } else {
            assistantMsg.versions![assistantMsg.currentVersionIndex] = assistantMsg.text;
          }
        });
        historyStore.touch(_session!);
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          assistantMsg.text += '\n\n[Generation stopped: $err]';
          if (assistantMsg.versions != null && assistantMsg.versions!.isNotEmpty) {
            assistantMsg.versions![assistantMsg.currentVersionIndex] = assistantMsg.text;
          }
          _isGenerating = false;
        });
        historyStore.touch(_session!);
      },
    );
  }

  void _stopGeneration() {
    _chatStreamSub?.cancel();
    setState(() {
      _isGenerating = false;
    });
  }

  void _startEdit(int index) {
    if (_isGenerating) return;
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
    if (_isGenerating) return;
    final newText = _editController!.text.trim();
    if (newText.isEmpty) return;
    final activeModel = _selectedModelTag ?? (_installedModels.isNotEmpty ? _installedModels.first.modelTag : 'llama3.2:1b');
    final messageAttachments = _session!.messages[index].attachments;

    setState(() {
      _session!.messages[index].text = newText;
      if (_session!.messages.length > index + 1) {
        _session!.messages.removeRange(index + 1, _session!.messages.length);
      }
      _editingIndex = null;
      _editController = null;
    });
    historyStore.touch(_session!);
    _streamAiResponse(prompt: newText, model: activeModel, attachments: messageAttachments);
  }

  void _regenerateAt(int index) {
    if (_isGenerating || _session == null) return;
    if (index < 0 || index >= _session!.messages.length) return;
    final targetMsg = _session!.messages[index];
    if (targetMsg.isUser) return;

    final activeModel = _selectedModelTag ?? (_installedModels.isNotEmpty ? _installedModels.first.modelTag : 'llama3.2:1b');
    String prompt = '';
    List<ChatAttachment> attachments = [];
    for (int i = index - 1; i >= 0; i--) {
      if (_session!.messages[i].isUser) {
        prompt = _session!.messages[i].text;
        attachments = _session!.messages[i].attachments;
        break;
      }
    }

    _streamAiResponse(
      prompt: prompt,
      model: activeModel,
      attachments: attachments,
      existingMessage: targetMsg,
    );
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showCopiedToast(context);
  }

  String get _inputHint => 'Ask anything';

  @override
  Widget build(BuildContext context) {
    final hasMessages = _session != null && _session!.messages.isNotEmpty;

    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          // Header with Model Selector & Manager button
          _buildTopBar(context),

          // Main Chat / Empty State Body
          Expanded(
            child: Stack(
              children: [
                hasMessages ? _buildChatList(context) : _buildEmptyState(context),
                if (hasMessages) _buildScrollToBottomButton(context),
              ],
            ),
          ),

          // Bottom Input Bar only when messages are present (matching Smart Routing)
          if (hasMessages)
            ChatInputBar(
              key: const ValueKey('bottom_chat_input_bar'),
              controller: _controller,
              showAttachButton: false,
              hint: _inputHint,
              isGenerating: _isGenerating,
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

            // Only show Offline Mode title & wifi icon in new chats
            if (!hasMessages) ...[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.wifi_off_rounded, color: AppColors.purple, size: 20),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () {
                  if (_engineStatus == EngineStatus.notInstalled) {
                    _startAutoInstall();
                  } else if (_engineStatus != EngineStatus.ready) {
                    _initializeLocalEngine();
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Offline Mode',
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
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _engineStatus == EngineStatus.ready
                                ? AppColors.success
                                : (_engineStatus == EngineStatus.installing ? Colors.blue : Colors.orange),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Tooltip(
                          message: _statusMessage,
                          child: Text(
                            _engineStatus == EngineStatus.ready
                                ? 'Local Engine Active'
                                : (_engineStatus == EngineStatus.installing
                                    ? 'Installing (${(_installProgress * 100).toInt()}%)...'
                                    : 'Engine Offline'),
                            style: TextStyle(color: context.textSecondary, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // Active Model Picker Pill (always visible in new chats and when prompt is sent)
            _buildActiveModelSelector(context),

            const SizedBox(width: 8),

            // Models Manager Button (always visible in new chats and when prompt is sent)
            InkWell(
              onTap: _showModelManagerModal,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  'Models',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
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

  Widget _buildActiveModelSelector(BuildContext context) {
    final activeTag = _selectedModelTag ?? (_installedModels.isNotEmpty ? _installedModels.first.modelTag : null);
    final activeDisplayName = activeTag != null ? _formatOfflineModelName(activeTag) : 'Select Model';

    return PopupMenuButton<String>(
      tooltip: '',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      borderRadius: BorderRadius.circular(8),
      color: context.bg,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide.none,
      ),
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      onSelected: (val) {
        setState(() {
          _selectedModelTag = val;
        });
      },
      itemBuilder: (ctx) {
        if (_installedModels.isEmpty) {
          return [
            PopupMenuItem<String>(
              enabled: false,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'No models downloaded',
                style: TextStyle(
                  color: ctx.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ];
        }

        final List<PopupMenuEntry<String>> items = [];

        for (final m in _installedModels) {
          final isSelected = m.modelTag == activeTag;
          final formattedName = _formatOfflineModelName(m.modelTag);

          items.add(
            PopupMenuItem<String>(
              value: m.modelTag,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                formattedName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ctx.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        }

        return items;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              activeDisplayName,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: context.textSecondary,
            ),
          ],
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

  String _formatOfflineModelName(String? raw) {
    if (raw == null || raw.isEmpty) return 'Offline AI';
    String clean = raw.trim();
    if (clean.toLowerCase().startsWith('local:')) {
      clean = clean.substring(6).trim();
    }
    final lower = clean.toLowerCase();
    if (lower.startsWith('deepseek-r1') || lower.startsWith('deepseek -r1')) {
      return 'DeepSeek-R1';
    } else if (lower.startsWith('deepseek-coder')) {
      return 'DeepSeek-Coder';
    } else if (lower.startsWith('deepseek')) {
      return 'DeepSeek';
    } else if (lower.startsWith('llama3.2') || lower.startsWith('llama-3.2') || lower.startsWith('llama 3.2')) {
      return 'Llama 3.2';
    } else if (lower.startsWith('llama3.1') || lower.startsWith('llama-3.1') || lower.startsWith('llama 3.1')) {
      return 'Llama 3.1';
    } else if (lower.startsWith('llama3') || lower.startsWith('llama-3')) {
      return 'Llama 3';
    } else if (lower.startsWith('llama2') || lower.startsWith('llama-2')) {
      return 'Llama 2';
    } else if (lower.startsWith('qwen2.5') || lower.startsWith('qwen-2.5')) {
      return 'Qwen 2.5';
    } else if (lower.startsWith('qwen')) {
      return 'Qwen';
    } else if (lower.startsWith('mistral')) {
      return 'Mistral';
    } else if (lower.startsWith('phi3') || lower.startsWith('phi-3')) {
      return 'Phi-3';
    } else if (lower.startsWith('gemma2') || lower.startsWith('gemma-2')) {
      return 'Gemma 2';
    } else if (lower.startsWith('gemma')) {
      return 'Gemma';
    } else if (lower.startsWith('moondream')) {
      return 'Moondream';
    } else if (lower.startsWith('llava')) {
      return 'LLaVA';
    } else if (lower.startsWith('tinyllama')) {
      return 'TinyLlama';
    }

    if (clean.contains(':')) {
      clean = clean.split(':').first;
    }
    return clean.split(RegExp(r'[-_ ]')).map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1);
    }).join('-');
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

  Widget _buildChatList(BuildContext context) {
    final messages = _session!.messages;
    final isDark = context.isDark;

    int lastAssistantIndex = -1;
    for (int k = messages.length - 1; k >= 0; k--) {
      if (!messages[k].isUser) {
        lastAssistantIndex = k;
        break;
      }
    }

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

        final isLatestAssistant = (i == lastAssistantIndex);

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
                        Row(
                          children: [
                            Text(
                              _formatOfflineModelName(m.modelName),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
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
                          : FormattedMessageView(
                              text: m.text.isEmpty && _isGenerating ? 'Thinking...' : m.text,
                              isUser: false,
                              fontSize: 14.5,
                              height: 1.55,
                              textColor: context.textPrimary,
                            ),
                      const SizedBox(height: 6),
                      m.isUser
                          ? UserMessageActions(
                              onEdit: () => _startEdit(i),
                              onCopy: () => _copy(m.text),
                            )
                          : AssistantMessageActions(
                              leading: _buildVersionSwitcher(context, m),
                              onCopy: () => _copy(m.text),
                              onRegenerate: (isLatestAssistant && !_isGenerating)
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
                text: 'Offline AI Engine',
              ),
              const SizedBox(height: 24),
              ChatInputBar(
                key: const ValueKey('centered_chat_input_bar'),
                controller: _controller,
                showAttachButton: false,
                hint: _inputHint,
                isGenerating: _isGenerating,
                onStop: _stopGeneration,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show the Full-Featured Models Manager Modal
  void _showModelManagerModal() {
    OfflineModelsManagerDialog.show(
      context: context,
      selectedModelTag: _selectedModelTag,
      onModelSelected: (tag) {
        setState(() => _selectedModelTag = tag);
      },
      onModelsChanged: () {
        _loadModels();
      },
    );
  }
}
