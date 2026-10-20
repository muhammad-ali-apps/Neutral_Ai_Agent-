import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
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
  List<CatalogModel> _catalogModels = [];
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
      // Also prefetch catalog
      _catalogModels = await OllamaService.getCatalog();
    }
  }

  Future<void> _loadModels() async {
    final installed = await OllamaService.getInstalledModels();
    final catalog = await OllamaService.getCatalog();

    if (!mounted) return;
    setState(() {
      _installedModels = installed;
      _catalogModels = catalog;

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

    // Add empty assistant response to list
    final assistantMsg = ChatMessage(
      isUser: false,
      modelName: effectiveModel,
      text: (hasImageAttachments && !canSendImagesToModel)
          ? '> ⚠️ **Vision Model Required:** The active offline model (`$effectiveModel`) is text-only. While code and text documents are analyzed directly, visual image inspection requires a vision model like **Moondream 2 (Vision 1.8B)** or **LLaVA (7B)** from the Models Manager.\n\n'
          : '',
    );

    setState(() {
      _session!.messages.add(assistantMsg);
      _isGenerating = true;
    });
    _scrollToBottom();

    _chatStreamSub = OllamaService.chatStream(
      model: effectiveModel,
      messages: messagesPayload,
    ).listen(
      (chunk) {
        if (!mounted || _session == null) return;
        setState(() {
          assistantMsg.text += chunk;
        });
        _scrollToBottom(animate: false);
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
        });
        historyStore.touch(_session!);
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          assistantMsg.text += '\n\n[Generation stopped: $err]';
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

    setState(() {
      _session!.messages[index] = ChatMessage(
        isUser: false,
        modelName: activeModel,
        text: '',
      );
      _isGenerating = true;
    });

    _streamAiResponse(prompt: prompt, model: activeModel, attachments: attachments);
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
          // Header with Model Selector & Manager button
          _buildTopBar(context),

          // Main Chat / Setup Body
          Expanded(
            child: Stack(
              children: [
                hasMessages ? _buildChatList(context) : _buildSetupState(context),
                if (hasMessages) _buildScrollToBottomButton(context),
                if (_isGenerating) _buildGeneratingOverlay(context),
              ],
            ),
          ),

          // Input Bar with Stop option
          ChatInputBar(
            controller: _controller,
            hint: _engineStatus == EngineStatus.ready
                ? (_installedModels.isNotEmpty ? 'Ask ${_selectedModelTag ?? "local model"} (100% Offline)...' : 'Download a model below to chat offline...')
                : 'Local engine offline...',
            onSend: _send,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.surface2,
        border: Border(bottom: BorderSide(color: context.borderColor, width: 1)),
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
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.wifi_off_rounded, color: AppColors.purple, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
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
                    Text(
                      _engineStatus == EngineStatus.ready
                          ? 'Local Engine Active'
                          : (_engineStatus == EngineStatus.installing ? 'Installing...' : 'Engine Offline'),
                      style: TextStyle(color: context.textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),

            // Active Model Picker Pill
            if (_installedModels.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedModelTag,
                    isDense: true,
                    icon: Icon(Icons.arrow_drop_down_rounded, color: context.textSecondary, size: 20),
                    dropdownColor: context.surface2,
                    items: _installedModels.map((m) {
                      return DropdownMenuItem<String>(
                        value: m.modelTag,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.memory_rounded, size: 14, color: AppColors.purple),
                            const SizedBox(width: 6),
                            Text(
                              m.name,
                              style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedModelTag = val);
                      }
                    },
                  ),
                ),
              ),

            // Live Background Download Indicator Pill
            if (modelDownloadManager.hasActiveDownloads)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: _showModelManagerModal,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.purple.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.purple,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          modelDownloadManager.primaryDownloadSummary ?? 'Downloading...',
                          style: const TextStyle(
                            color: AppColors.purple,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Models Manager Button
            ElevatedButton.icon(
              onPressed: _showModelManagerModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple.withValues(alpha: 0.15),
                foregroundColor: AppColors.purple,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.inventory_2_outlined, size: 16),
              label: Text(
                'Models (${_installedModels.length})',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratingOverlay(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: context.surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple),
              ),
              const SizedBox(width: 10),
              Text('Generating offline response...', style: TextStyle(color: context.textPrimary, fontSize: 12.5)),
              const SizedBox(width: 10),
              InkWell(
                onTap: _stopGeneration,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _errorColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Stop', style: TextStyle(color: _errorColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleMaxWidth = screenWidth < 660 ? screenWidth * 0.90 : 640.0;
    final isDark = context.isDark;

    const claudeUserDark = Color(0xFF262522);
    const claudeBorderDark = Color(0xFF3E3C37);
    const claudeUserLight = Color(0xFFF5F3ED);
    const claudeBorderLight = Color(0xFFE2DFD6);

    return ListView.builder(
      controller: _scrollController,
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
                    if (m.attachments.isNotEmpty)
                      ChatAttachmentsView(attachments: m.attachments, isUser: m.isUser),
                    if (!m.isUser && m.modelName != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, size: 14, color: AppColors.purple),
                          const SizedBox(width: 4),
                          Text(
                            'Local: ${m.modelName!}',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Offline', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
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
                        text: m.text.isEmpty && _isGenerating ? 'Thinking...' : m.text,
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

  Widget _buildSetupState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.wifi_off_rounded, color: AppColors.purple, size: 34),
              ),
              const SizedBox(height: 16),
              AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    'Offline AI Engine',
                    textStyle: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                    speed: const Duration(milliseconds: 140),
                  ),
                ],
                totalRepeatCount: 1,
                displayFullTextOnTap: true,
              ),
              const SizedBox(height: 8),
              Text(
                'Run powerful local LLMs completely offline on your CPU / GPU with zero internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary, fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 24),

              // Engine Status Card
              if (_engineStatus == EngineStatus.notInstalled)
                _buildInstallCard(context)
              else if (_engineStatus == EngineStatus.installing)
                _buildInstallingCard(context)
              else if (_engineStatus == EngineStatus.ready)
                _buildReadyCard(context)
              else
                _buildStoppedCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstallCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Text('Ollama Runtime Not Detected', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'To run models offline without internet, the local Ollama runtime is required. You do not need to install it manually — click below for automated background setup.',
            style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startAutoInstall,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.download_for_offline_rounded),
              label: const Text('One-Click Auto-Setup Engine', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallingCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.purple),
              ),
              const SizedBox(width: 10),
              Text('Setting Up Engine...', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              Text('${(_installProgress * 100).toInt()}%', style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _installProgress,
              minHeight: 8,
              backgroundColor: context.surface,
              color: AppColors.purple,
            ),
          ),
          const SizedBox(height: 10),
          Text(_statusMessage, style: TextStyle(color: context.textSecondary, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildStoppedCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Text('Ollama is installed but not currently responding.', style: TextStyle(color: context.textPrimary, fontSize: 13.5)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _initializeLocalEngine,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Start Local Engine'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              const Text('Ollama Runtime is Online', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              TextButton.icon(
                onPressed: _showModelManagerModal,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Get Models'),
                style: TextButton.styleFrom(foregroundColor: AppColors.purple),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_installedModels.isEmpty) ...[
            Text(
              'No models are downloaded on this device yet. Click "Manage Models" to pick and download an offline model (e.g. Llama 3.2 1B).',
              style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showModelManagerModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.inventory_2_rounded),
                label: const Text('Browse & Download Offline Models'),
              ),
            ),
          ] else ...[
            Text('Ready Models installed on your disk:', style: TextStyle(color: context.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 8),
            ..._installedModels.map((m) {
              final isSelected = m.modelTag == _selectedModelTag;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.purple.withValues(alpha: 0.12) : context.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.purple : context.borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.memory_rounded, size: 16, color: isSelected ? AppColors.purple : context.textSecondary),
                    const SizedBox(width: 8),
                    Text(m.name, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    Text(m.sizeFormatted, style: TextStyle(color: context.textSecondary, fontSize: 12)),
                    const SizedBox(width: 8),
                    if (isSelected)
                      const Icon(Icons.check_rounded, color: AppColors.purple, size: 18)
                    else
                      InkWell(
                        onTap: () => setState(() => _selectedModelTag = m.modelTag),
                        child: const Text('Select', style: TextStyle(color: AppColors.purple, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),
            Text('Type a question in the chat bar below to test your local AI model!', style: TextStyle(color: context.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ],
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
