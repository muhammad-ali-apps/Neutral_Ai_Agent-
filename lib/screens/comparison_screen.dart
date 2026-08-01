import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../models.dart';
import '../widgets/screen_header.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_actions.dart';
import '../widgets/copy_toast.dart';

/// Comparison screen — side-by-side responses from selected models.
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
  final Set<String> _selected = {'gpt4o', 'claude'};
  ChatSession? _session;

  int? _editingIndex;
  TextEditingController? _editController;

  List<LlmModel> get _selectedModels =>
      modelStore.models.where((m) => _selected.contains(m.id)).toList();

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

  void _send(String text, List<String> attachments) {
    if (_selected.isEmpty || text.trim().isEmpty) return;
    setState(() {
      _session ??= ChatSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: text.length > 42 ? '${text.substring(0, 42)}...' : text,
        mode: ChatMode.comparison,
      );
      final isNew = !historyStore.sessions.contains(_session);
      _session!.messages.add(ChatMessage(isUser: true, text: text, attachments: attachments));
      for (final model in _selectedModels) {
        _session!.messages.add(ChatMessage(
          isUser: false,
          modelName: model.name,
          text: '[Dummy response placeholder from ${model.name} — UI demo only, '
              'not a real API call. Would answer: "$text"]',
        ));
      }
      if (isNew) {
        historyStore.addSession(_session!);
      } else {
        historyStore.touch(_session!);
      }
    });
    _notifySession();
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
      // Remove the old response group (all consecutive assistant messages after it).
      int end = index + 1;
      while (end < _session!.messages.length && !_session!.messages[end].isUser) {
        end++;
      }
      if (end > index + 1) {
        _session!.messages.removeRange(index + 1, end);
      }
      // Regenerate a fresh group using the currently selected models.
      for (final model in _selectedModels) {
        _session!.messages.insert(
          index + 1 + _selectedModels.indexOf(model),
          ChatMessage(
            isUser: false,
            modelName: model.name,
            text: '[Dummy response placeholder from ${model.name} — UI demo only, '
                'not a real API call. Would answer: "$newText"]',
          ),
        );
      }
      _editingIndex = null;
      _editController = null;
    });
    historyStore.touch(_session!);
  }

  void _regenerateAt(int index) {
    final m = _session!.messages[index];
    setState(() {
      _session!.messages[index] = ChatMessage(
        isUser: false,
        modelName: m.modelName,
        text: '[Regenerated dummy response from ${m.modelName} — UI demo only.]',
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
      key: _scaffoldKey,
      backgroundColor: context.bg,
      endDrawer: _buildModelDrawer(context),
      body: Column(
        children: [
          ScreenHeader(
            icon: Icons.grid_view_rounded,
            title: 'Comparison Mode',
            subtitle: 'Compare responses from multiple AI models',
            onMenuTap: widget.onMenuTap,
            trailing: IconButton(
              tooltip: 'Select models',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.view_sidebar_rounded, color: context.textSecondary),
                  if (_selected.isNotEmpty)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: AppColors.purple, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text('${_selected.length}',
                            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_selected.isNotEmpty) _buildSelectedBar(context),
          Expanded(
            child: _selected.isEmpty
                ? _buildNoModelsState(context)
                : hasMessages
                    ? _buildChatList(context)
                    : _buildEmptyState(context),
          ),
          ChatInputBar(
            controller: _controller,
            hint: _selected.isEmpty
                ? 'Select the models '
                : 'Ask Anything',
            onSend: _send,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedBar(BuildContext context) {
    return ListenableBuilder(
      listenable: modelStore,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.borderColor))),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedModels
              .map((m) => Chip(
                    avatar: CircleAvatar(
                        radius: 9,
                        backgroundColor: m.color,
                        child: Text(m.badgeLetter, style: const TextStyle(fontSize: 9, color: Colors.white))),
                    backgroundColor: AppColors.purple.withValues(alpha: 0.12),
                    label: Text(m.name, style: const TextStyle(color: AppColors.purple, fontSize: 12)),
                    side: BorderSide.none,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildNoModelsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_sidebar_rounded, color: context.textSecondary, size: 32),
            const SizedBox(height: 12),
            // Text('No models selected',
            //     style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.5)),
            AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'No models selected',
                  textStyle: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.5),
                  speed: const Duration(milliseconds: 100),
                ),
              ],
              totalRepeatCount: 1,
            ),
            const SizedBox(height: 6),
            Text('Tap the icon in the top-right corner to choose models to compare.',
                textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Select Models', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.compare_arrows_rounded, color: AppColors.purple, size: 32),
            const SizedBox(height: 12),
            // Text('Comparison Mode',
            //     style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.5)),
            AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'Comparison Mode',
                  textStyle: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.5),
                  speed: const Duration(milliseconds: 100),
                  
                ),
                
              ],
              totalRepeatCount: 19,
            ),
            const SizedBox(height: 6),
            Text('Type a prompt below to see it answered by all ${_selected.length} selected models.',
                textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary, fontSize: 12.5)),
          ],
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
        widgets.add(_responseGroup(context, group));
      }
    }
    return ListView(padding: const EdgeInsets.all(20), children: widgets);
  }

  Widget _userBubble(BuildContext context, ChatMessage m, int index) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(m.text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45)),
          ),
          UserMessageActions(onEdit: () => _startEdit(index), onCopy: () => _copy(m.text)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _responseGroup(BuildContext context, List<MapEntry<int, ChatMessage>> group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 640;
        final cards = group.map((entry) {
          final index = entry.key;
          final m = entry.value;
          final model = modelStore.models.where((e) => e.name == m.modelName).toList();
          final color = model.isNotEmpty ? model.first.color : AppColors.purple;
          final letter = model.isNotEmpty ? model.first.badgeLetter : '?';
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                        radius: 10,
                        backgroundColor: color,
                        child: Text(letter, style: const TextStyle(fontSize: 10, color: Colors.white))),
                    const SizedBox(width: 8),
                    Text(m.modelName ?? '',
                        style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
                const Divider(height: 18),
                Text(m.text, style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.5)),
                const SizedBox(height: 4),
                AssistantMessageActions(onCopy: () => _copy(m.text), onRegenerate: () => _regenerateAt(index)),
              ],
            ),
          );
        }).toList();

        if (wide) {
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [for (final c in cards) SizedBox(width: (constraints.maxWidth - 14) / 2, child: c)],
          );
        }
        return Column(
            children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList());
      }),
    );
  }

  Widget _buildModelDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: context.surface,
      width: 300,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 10, 10),
              child: Row(
                children: [
                  const Icon(Icons.view_sidebar_rounded, color: AppColors.purple, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Select Models',
                        style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: context.textSecondary),
                  ),
                ],
              ),
            ),
            Divider(color: context.borderColor, height: 1),
            Expanded(
              child: ListenableBuilder(
                listenable: modelStore,
                builder: (context, _) => ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: modelStore.models.length,
                  itemBuilder: (context, i) {
                    final m = modelStore.models[i];
                    final selected = _selected.contains(m.id);
                    return CheckboxListTile(
                      value: selected,
                      activeColor: AppColors.purple,
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(m.id);
                        } else {
                          _selected.remove(m.id);
                        }
                      }),
                      secondary: CircleAvatar(
                        radius: 15,
                        backgroundColor: m.color,
                        child: Text(m.badgeLetter, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      title: Text(m.name,
                          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5)),
                      subtitle: Text(m.active ? m.provider : '${m.provider} · Inactive',
                          style: TextStyle(
                              color: m.active ? context.textSecondary : Colors.redAccent.withValues(alpha: 0.8),
                              fontSize: 11.5)),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Apply Selection (${_selected.length})'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
