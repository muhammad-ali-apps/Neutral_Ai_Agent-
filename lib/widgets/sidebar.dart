import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../models.dart';

class NavItem {
  final IconData icon;
  final String label;
  NavItem(this.icon, this.label);
}

final navItems = [
  NavItem(Icons.bolt_rounded, 'Smart Routing'),
  NavItem(Icons.grid_view_rounded, 'Comparison'),
  NavItem(Icons.wifi_off_rounded, 'Offline Mode'),
];

/// Application sidebar with navigation, per-mode history, and account controls.
class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdminTap;
  final bool adminSelected;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;
  final VoidCallback onNewChat;
  final VoidCallback? onClose;
  final String? activeSessionId;
  final ValueChanged<ChatSession> onSelectSession;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdminTap,
    required this.adminSelected,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onLogout,
    required this.onNewChat,
    required this.activeSessionId,
    required this.onSelectSession,
    this.onClose,
  });

  ChatMode? get _currentMode {
    if (adminSelected) return null;
    switch (selectedIndex) {
      case 0:
        return ChatMode.smartRouting;
      case 1:
        return ChatMode.comparison;
      case 2:
        return ChatMode.offline;
      default:
        return ChatMode.smartRouting;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = _currentMode;

    return Container(
      width: 260,
      color: context.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color.fromARGB(255, 215, 213, 235), AppColors.purpleGradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  // child: const Icon(Icons.route_rounded, color: Colors.white, size: 20),
                child: Image.asset(
                    'assets/images/logo.png',
                    width: 20,
                    height: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Neutral',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                    Text(
                      'AI Agent',
                      style: TextStyle(color: context.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!adminSelected)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Material(
                color: AppColors.purple,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    onNewChat();
                    onClose?.call();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'New Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Divider(color: context.borderColor, height: 1),
          const SizedBox(height: 6),
          ...List.generate(navItems.length, (i) {
            final item = navItems[i];
            final selected = i == selectedIndex && !adminSelected;
            return _NavTile(
              icon: item.icon,
              label: item.label,
              selected: selected,
              onTap: () {
                onSelect(i);
                onClose?.call();
              },
            );
          }),
          if (mode != null) ...[
            const SizedBox(height: 4),
            Divider(color: context.borderColor, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Text(
                '${mode.label} History',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Expanded(
              child: _HistoryList(
                mode: mode,
                activeSessionId: activeSessionId,
                onSelect: (s) {
                  onSelectSession(s);
                  onClose?.call();
                },
              ),
            ),
          ] else
            const Spacer(),
          Divider(color: context.borderColor, height: 1),
          const SizedBox(height: 4),
          _NavTile(
            icon: isDarkMode ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
            label: isDarkMode ? 'Light Mode' : 'Dark Mode',
            selected: false,
            onTap: onToggleTheme,
          ),
          _NavTile(
            icon: Icons.settings_outlined,
            label: 'Admin Panel',
            selected: adminSelected,
            onTap: () {
              onAdminTap();
              onClose?.call();
            },
          ),
          Divider(color: context.borderColor, height: 1),
          _AccountTile(onLogout: onLogout),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Compact history list scoped to one chat mode.
class _HistoryList extends StatefulWidget {
  final ChatMode mode;
  final String? activeSessionId;
  final ValueChanged<ChatSession> onSelect;

  const _HistoryList({
    required this.mode,
    required this.activeSessionId,
    required this.onSelect,
  });

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  String? _editingId;
  String? _confirmDeleteId;
  final Map<String, TextEditingController> _editControllers = {};
  final Map<String, FocusNode> _editFocusNodes = {};

  @override
  void dispose() {
    for (final c in _editControllers.values) {
      c.dispose();
    }
    for (final n in _editFocusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(ChatSession s) {
    return _editControllers.putIfAbsent(
      s.id,
      () => TextEditingController(text: s.title),
    );
  }

  FocusNode _focusNodeFor(ChatSession s) {
    return _editFocusNodes.putIfAbsent(s.id, () => FocusNode());
  }

  void _startRename(ChatSession s) {
    setState(() {
      _confirmDeleteId = null;
      _editingId = s.id;
      final ctrl = _controllerFor(s);
      ctrl.text = s.title;
      ctrl.selection = TextSelection(baseOffset: 0, extentOffset: s.title.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodeFor(s).requestFocus();
    });
  }

  void _commitRename(ChatSession s) {
    final text = _controllerFor(s).text.trim();
    if (text.isNotEmpty && text != s.title) {
      historyStore.rename(s.id, text);
    }
    setState(() => _editingId = null);
  }

  void _cancelRename() {
    setState(() => _editingId = null);
  }

  void _requestDelete(String id) {
    setState(() {
      _editingId = null;
      _confirmDeleteId = id;
    });
  }

  void _confirmDelete(String id) {
    historyStore.delete(id);
    setState(() => _confirmDeleteId = null);
  }

  void _cancelDelete() {
    setState(() => _confirmDeleteId = null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: historyStore,
      builder: (context, _) {
        final sessions = historyStore.forMode(widget.mode);
        if (sessions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'No chats yet',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 2),
          itemCount: sessions.length,
          itemBuilder: (context, i) {
            final s = sessions[i];
            final selected = s.id == widget.activeSessionId;
            final isEditing = _editingId == s.id;
            final isConfirming = _confirmDeleteId == s.id;

            if (isConfirming) {
              return _DeleteConfirmRow(
                title: s.title,
                onConfirm: () => _confirmDelete(s.id),
                onCancel: _cancelDelete,
              );
            }

            return Dismissible(
              key: ValueKey(s.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.redAccent.withValues(alpha: 0.9),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 14),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 16),
              ),
              confirmDismiss: (_) async {
                _requestDelete(s.id);
                return false;
              },
              child: Material(
                color: selected ? AppColors.purple.withValues(alpha: 0.1) : Colors.transparent,
                child: InkWell(
                  onTap: isEditing ? null : () => widget.onSelect(s),
                  hoverColor: AppColors.purple.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: isEditing
                              ? _InlineRenameField(
                                  controller: _controllerFor(s),
                                  focusNode: _focusNodeFor(s),
                                  onSubmit: () => _commitRename(s),
                                  onCancel: _cancelRename,
                                )
                              : Text(
                                  s.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected ? AppColors.purple : context.textPrimary,
                                    fontSize: 13,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                        ),
                        if (!isEditing)
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              size: 16,
                              color: context.textSecondary,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            tooltip: '',
                            color: context.surface2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: context.borderColor),
                            ),
                            onSelected: (v) {
                              if (v == 'rename') _startRename(s);
                              if (v == 'delete') _requestDelete(s.id);
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'rename',
                                height: 36,
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 15, color: context.textSecondary),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Rename',
                                      style: TextStyle(color: context.textPrimary, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                height: 36,
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 15, color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.redAccent, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Inline title editor for chat history items.
class _InlineRenameField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _InlineRenameField({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          onCancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        cursorColor: AppColors.purple,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.purple, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.purple, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.purple, width: 1.2),
          ),
        ),
        onSubmitted: (_) => onSubmit(),
        onTapOutside: (_) => onSubmit(),
      ),
    );
  }
}

/// Lightweight inline delete confirmation row.
class _DeleteConfirmRow extends StatelessWidget {
  final String title;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _DeleteConfirmRow({
    required this.title,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Delete this chat?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.textPrimary, fontSize: 12.5),
            ),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Cancel', style: TextStyle(color: context.textSecondary, fontSize: 12)),
          ),
          const SizedBox(width: 2),
          TextButton(
            onPressed: onConfirm,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final VoidCallback onLogout;
  const _AccountTile({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.purple, AppColors.purpleGradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'MA',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Muhammad Ali',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  'muhammad.ali@example.com',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: onLogout,
            iconSize: 18,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: selected ? AppColors.purple.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          hoverColor: AppColors.purple.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.purple : context.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.purple : context.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
