import 'dart:math' as math;
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
  final bool isDrawer;

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
    this.isDrawer = false,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isAdmin = false;
  bool _isCollapsed = false;
  bool _isHistoryCollapsed = false;

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
    final effectiveCollapsed = widget.isDrawer ? false : _isCollapsed;
    final targetWidth = effectiveCollapsed ? 64.0 : 260.0;

    final sidebarContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Header section
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Row(
              mainAxisAlignment:
                  effectiveCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                if (!effectiveCollapsed) ...[
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
                if (widget.isDrawer)
                  IconButton(
                    tooltip: 'Close sidebar',
                    onPressed: () => widget.onClose?.call(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.textSecondary,
                      size: 20,
                    ),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  )
                else
                  IconButton(
                    tooltip: effectiveCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                    onPressed: () {
                      setState(() {
                        _isCollapsed = !_isCollapsed;
                      });
                    },
                    icon: Icon(
                      effectiveCollapsed ? Icons.view_sidebar_outlined : Icons.view_sidebar_rounded,
                      color: context.textSecondary,
                      size: 19,
                    ),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
              ],
            ),
          ),

          // New Chat Button (ChatGPT style: transparent background, compose icon, no border)
          if (!widget.adminSelected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: effectiveCollapsed
                  ? Tooltip(
                      message: 'New chat',
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            widget.onNewChat();
                            widget.onClose?.call();
                          },
                          hoverColor: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.05),
                          child: Container(
                            width: 44,
                            height: 38,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.edit_square,
                              color: context.textPrimary,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          widget.onNewChat();
                          widget.onClose?.call();
                        },
                        hoverColor: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.05),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_square,
                                color: context.textPrimary,
                                size: 17,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'New chat',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          const SizedBox(height: 4),

          // Navigation Items
          ...List.generate(navItems.length, (i) {
            final item = navItems[i];
            final selected = i == widget.selectedIndex && !widget.adminSelected;
            return _NavTile(
              icon: item.icon,
              label: item.label,
              selected: selected,
              isCollapsed: effectiveCollapsed,
              onTap: () {
                widget.onSelect(i);
                widget.onClose?.call();
              },
            );
          }),

          // History Section with "Recent" and collapsible ^ / v controller
          if (!effectiveCollapsed && mode != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
              child: Text(
                'HISTORY',
                style: TextStyle(
                  color: context.textSecondary.withValues(alpha: 0.65),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    setState(() {
                      _isHistoryCollapsed = !_isHistoryCollapsed;
                    });
                  },
                  hoverColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          _isHistoryCollapsed
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          size: 18,
                          color: context.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!_isHistoryCollapsed)
              Expanded(
                child: _HistoryList(
                  mode: mode,
                  activeSessionId: widget.activeSessionId,
                  onSelect: (s) {
                    widget.onSelectSession(s);
                    widget.onClose?.call();
                  },
                ),
              )
            else
              const Spacer(),
          ] else
            const Spacer(),

          Divider(color: context.borderColor, height: 1),

          // Admin Panel (Theme toggle removed from sidebar as requested)
          if (_isAdmin) ...[
            _NavTile(
              icon: Icons.settings_outlined,
              label: 'Admin Panel',
              selected: widget.adminSelected,
              isCollapsed: effectiveCollapsed,
              onTap: () {
                context.go('/admin-panel');
                widget.onClose?.call();
              },
            ),
            Divider(color: context.borderColor, height: 1),
          ],

          // Account Tile
          _AccountTile(
            onLogout: widget.onLogout,
            isCollapsed: effectiveCollapsed,
          ),
          const SizedBox(height: 4),
        ],
      );

    final innerContent = widget.isDrawer
        ? sidebarContent
        : OverflowBox(
            minWidth: targetWidth,
            maxWidth: targetWidth,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: targetWidth,
              child: sidebarContent,
            ),
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      clipBehavior: Clip.hardEdge,
      width: widget.isDrawer ? double.infinity : targetWidth,
      color: context.surface,
      child: innerContent,
    );
  }
}

/// Compact history list scoped to one chat mode (without date headers).
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
                child: SizedBox(
                  height: 32,
                  child: Material(
                    color: selected
                        ? (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFECECEC))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: isEditing ? null : () => widget.onSelect(s),
                      hoverColor: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
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
                                        height: 1.2,
                                        fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                                      ),
                                    ),
                            ),
                            if (!isEditing)
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_horiz_rounded,
                                    size: 14,
                                    color: context.textSecondary,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                  splashRadius: 12,
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
                                      height: 30,
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
                                      height: 30,
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
                              ),
                          ],
                        ),
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

class _MovingRedBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final bool isDark;

  const _MovingRedBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.0),
      Radius.circular(borderRadius),
    );

    // 1. Static subtle red guide outline
    final trackPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.22 : 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, trackPaint);

    // 2. Rotating sweep gradient red beam
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      transform: GradientRotation(progress * 2 * math.pi),
      colors: const [
        Colors.transparent,
        Color(0x00EF4444),
        Color(0x44EF4444),
        Color(0xFFEF4444),
        Color(0xFFFF6666),
        Color(0xFFEF4444),
        Color(0x00EF4444),
        Colors.transparent,
      ],
      stops: const [0.0, 0.65, 0.78, 0.88, 0.94, 0.98, 1.0, 1.0],
    );

    final shader = sweepGradient.createShader(rect);

    // 3. Glowing neon beam halo
    final glowPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawRRect(rrect, glowPaint);

    // 4. Sharp high-intensity laser line
    final beamPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(rrect, beamPaint);
  }

  @override
  bool shouldRepaint(_MovingRedBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.isDark != isDark;
  }
}

class _NavTile extends StatefulWidget {
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
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> with SingleTickerProviderStateMixin {
  late final AnimationController _beamController;

  @override
  void initState() {
    super.initState();
    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.selected) {
      _beamController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _NavTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !_beamController.isAnimating) {
      _beamController.repeat();
    } else if (!widget.selected && _beamController.isAnimating) {
      _beamController.stop();
      _beamController.reset();
    }
  }

  @override
  void dispose() {
    _beamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    if (widget.isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Center(
          child: Tooltip(
            message: widget.label,
            child: AnimatedBuilder(
              animation: _beamController,
              builder: (context, child) {
                if (!widget.selected) return child!;
                return CustomPaint(
                  painter: _MovingRedBorderPainter(
                    progress: _beamController.value,
                    borderRadius: 8,
                    isDark: isDark,
                  ),
                  child: child,
                );
              },
              child: Material(
                color: Colors.transparent, // Selected container removed
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: widget.onTap,
                  hoverColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                  child: Container(
                    width: 44,
                    height: 38,
                    alignment: Alignment.center,
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: widget.selected ? const Color(0xFFEF4444) : context.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: AnimatedBuilder(
        animation: _beamController,
        builder: (context, child) {
          if (!widget.selected) return child!;
          return CustomPaint(
            painter: _MovingRedBorderPainter(
              progress: _beamController.value,
              borderRadius: 7,
              isDark: isDark,
            ),
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent, // Selected container removed
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: widget.onTap,
            hoverColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 17,
                    color: widget.selected ? const Color(0xFFEF4444) : context.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.selected ? context.textPrimary : context.textSecondary,
                        fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
