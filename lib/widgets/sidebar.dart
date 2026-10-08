import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../models.dart';
import '../services/api_services.dart';
import 'package:go_router/go_router.dart';

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

/// ChatGPT-style application sidebar with navigation, per-mode history, and collapsible toggle.
class Sidebar extends StatefulWidget {
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

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isAdmin = false;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String role = prefs.getString('userRole')?.toLowerCase() ?? '';
    if (mounted) {
      setState(() {
        _isAdmin = (role == 'admin' || role == 'administrator');
      });
    }
  }

  ChatMode? get _currentMode {
    if (widget.adminSelected) return null;
    switch (widget.selectedIndex) {
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
    final isDark = context.isDark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _isCollapsed ? 64 : 260,
      color: context.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Row(
              mainAxisAlignment:
                  _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                if (!_isCollapsed) ...[
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: AppColors.purple,
                              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Orbit AI',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ],
                IconButton(
                  tooltip: _isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                  onPressed: () {
                    setState(() {
                      _isCollapsed = !_isCollapsed;
                    });
                  },
                  icon: Icon(
                    _isCollapsed ? Icons.view_sidebar_outlined : Icons.view_sidebar_rounded,
                    color: context.textSecondary,
                    size: 19,
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          // New Chat Button
          if (!widget.adminSelected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: _isCollapsed
                  ? Tooltip(
                      message: 'New chat',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          widget.onNewChat();
                          widget.onClose?.call();
                        },
                        child: Container(
                          width: 44,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2F2F2F) : const Color(0xFFEBEBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: context.borderColor,
                              width: 1,
                            ),
                          ),
                          child: Icon(Icons.add_rounded, color: context.textPrimary, size: 20),
                        ),
                      ),
                    )
                  : Material(
                      color: isDark ? const Color(0xFF212121) : const Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          widget.onNewChat();
                          widget.onClose?.call();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.add_rounded, color: context.textPrimary, size: 17),
                              const SizedBox(width: 8),
                              Text(
                                'New chat',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          const SizedBox(height: 6),

          // Navigation Items
          ...List.generate(navItems.length, (i) {
            final item = navItems[i];
            final selected = i == widget.selectedIndex && !widget.adminSelected;
            return _NavTile(
              icon: item.icon,
              label: item.label,
              selected: selected,
              isCollapsed: _isCollapsed,
              onTap: () {
                widget.onSelect(i);
                widget.onClose?.call();
              },
            );
          }),

          // History Section
          if (!_isCollapsed && mode != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(
                'HISTORY',
                style: TextStyle(
                  color: context.textSecondary.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Expanded(
              child: _HistoryList(
                mode: mode,
                activeSessionId: widget.activeSessionId,
                onSelect: (s) {
                  widget.onSelectSession(s);
                  widget.onClose?.call();
                },
              ),
            ),
          ] else
            const Spacer(),

          Divider(color: context.borderColor, height: 1),
          const SizedBox(height: 4),

          // Dark/Light Theme Toggle
          _NavTile(
            icon: widget.isDarkMode ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
            label: widget.isDarkMode ? 'Light Mode' : 'Dark Mode',
            selected: false,
            isCollapsed: _isCollapsed,
            onTap: widget.onToggleTheme,
          ),

          // Admin Panel
          if (_isAdmin)
            _NavTile(
              icon: Icons.settings_outlined,
              label: 'Admin Panel',
              selected: widget.adminSelected,
              isCollapsed: _isCollapsed,
              onTap: () {
                context.go('/admin-panel');
                widget.onClose?.call();
              },
            ),

          Divider(color: context.borderColor, height: 1),

          // Account Tile
          _AccountTile(
            onLogout: widget.onLogout,
            isCollapsed: _isCollapsed,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

String _getDateCategory(DateTime dateTime) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
  final dateStart = DateTime(dateTime.year, dateTime.month, dateTime.day);

  if (dateStart == todayStart) {
    return 'Today';
  } else if (dateStart == yesterdayStart) {
    return 'Yesterday';
  } else {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }
}

abstract class _HistoryItem {}

class _HistoryHeaderItem extends _HistoryItem {
  final String title;
  _HistoryHeaderItem(this.title);
}

class _HistorySessionItem extends _HistoryItem {
  final ChatSession session;
  _HistorySessionItem(this.session);
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
        if (historyStore.isLoading && sessions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.purple),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading...',
                  style: TextStyle(color: context.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          );
        }
        if (sessions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Text(
              'No chats yet',
              style: TextStyle(color: context.textSecondary, fontSize: 11.5),
            ),
          );
        }

        final items = <_HistoryItem>[];
        String? lastGroupLabel;

        for (final s in sessions) {
          final groupLabel = _getDateCategory(s.updatedAt);
          if (groupLabel != lastGroupLabel) {
            items.add(_HistoryHeaderItem(groupLabel));
            lastGroupLabel = groupLabel;
          }
          items.add(_HistorySessionItem(s));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 2),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];

            if (item is _HistoryHeaderItem) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: context.textSecondary.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            final s = (item as _HistorySessionItem).session;
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

            final isDark = context.isDark;

            return Dismissible(
              key: ValueKey(s.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.redAccent.withValues(alpha: 0.9),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 12),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 15),
              ),
              confirmDismiss: (_) async {
                _requestDelete(s.id);
                return false;
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: Material(
                  color: selected
                      ? (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFECECEC))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: isEditing ? null : () => widget.onSelect(s),
                    hoverColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 2, 6),
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
                                      color: context.textPrimary,
                                      fontSize: 12.5,
                                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                                    ),
                                  ),
                          ),
                          if (!isEditing)
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                size: 15,
                                color: context.textSecondary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              tooltip: '',
                              color: context.surface2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: context.borderColor),
                              ),
                              onSelected: (v) {
                                if (v == 'rename') _startRename(s);
                                if (v == 'delete') _requestDelete(s.id);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'rename',
                                  height: 32,
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 14, color: context.textSecondary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Rename',
                                        style: TextStyle(color: context.textPrimary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  height: 32,
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
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
        style: TextStyle(color: context.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w400),
        cursorColor: AppColors.purple,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: AppColors.purple, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: AppColors.purple, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: AppColors.purple, width: 1),
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
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Delete chat?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.textPrimary, fontSize: 11.5),
            ),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Cancel', style: TextStyle(color: context.textSecondary, fontSize: 11)),
          ),
          const SizedBox(width: 2),
          TextButton(
            onPressed: onConfirm,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatefulWidget {
  final VoidCallback onLogout;
  final bool isCollapsed;

  const _AccountTile({required this.onLogout, required this.isCollapsed});

  @override
  State<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<_AccountTile> {
  String userName = 'Loading...';
  String email = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? 'Guest User';
      email = prefs.getString('userEmail') ?? 'guest@example.com';
    });
  }

  String getInitials(String name) {
    if (name.isEmpty) return '';
    List<String> nameParts = name.trim().split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Tooltip(
            message: '$userName\n$email',
            child: InkWell(
              onTap: () async {
                bool success = await ApiService.logoutUser();
                if (success && context.mounted) {
                  context.go('/login');
                }
                widget.onLogout();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
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
                child: Text(
                  getInitials(userName),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.purple, AppColors.purpleGradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              getInitials(userName),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10.5),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              bool success = await ApiService.logoutUser();
              if (success && context.mounted) {
                context.go('/login');
              }
              widget.onLogout();
            },
            iconSize: 16,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: Icon(Icons.logout_rounded, color: context.textSecondary),
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
  final bool isCollapsed;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Center(
          child: Tooltip(
            message: label,
            child: Material(
              color: selected
                  ? (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE4E4E4))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTap,
                child: Container(
                  width: 44,
                  height: 38,
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? AppColors.purple : context.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected
            ? (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEBEBEB))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          hoverColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? AppColors.purple : context.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
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
