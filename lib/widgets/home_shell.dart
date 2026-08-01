import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/comparison_screen.dart';
import '../screens/offline_mode_screen.dart';
import '../screens/smart_routing_screen.dart';
import 'sidebar.dart';

/// Root shell with responsive sidebar and mode navigation.
class HomeShell extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  const HomeShell({super.key, required this.isDarkMode, required this.onToggleTheme});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _adminSelected = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _smartKey = GlobalKey<SmartRoutingScreenState>();
  final _comparisonKey = GlobalKey<ComparisonScreenState>();
  final _offlineKey = GlobalKey<OfflineModeScreenState>();

  /// Tracks the active session id per mode so the Sidebar can highlight it.
  final Map<ChatMode, String?> _activeSessionIds = {
    ChatMode.smartRouting: null,
    ChatMode.comparison: null,
    ChatMode.offline: null,
  };

  static const _mobileBreakpoint = 820.0;

  ChatMode get _currentMode {
    switch (_index) {
      case 1:
        return ChatMode.comparison;
      case 2:
        return ChatMode.offline;
      default:
        return ChatMode.smartRouting;
    }
  }

  String? get _activeSessionId {
    if (_adminSelected) return null;
    return _activeSessionIds[_currentMode];
  }

  Widget _currentScreen({VoidCallback? onMenuTap}) {
    if (_adminSelected) return AdminPanelScreen(onMenuTap: onMenuTap);
    switch (_index) {
      case 0:
        return SmartRoutingScreen(
          key: _smartKey,
          onMenuTap: onMenuTap,
          onSessionChanged: (id) => setState(() => _activeSessionIds[ChatMode.smartRouting] = id),
        );
      case 1:
        return ComparisonScreen(
          key: _comparisonKey,
          onMenuTap: onMenuTap,
          onSessionChanged: (id) => setState(() => _activeSessionIds[ChatMode.comparison] = id),
        );
      case 2:
        return OfflineModeScreen(
          key: _offlineKey,
          onMenuTap: onMenuTap,
          onSessionChanged: (id) => setState(() => _activeSessionIds[ChatMode.offline] = id),
        );
      default:
        return SmartRoutingScreen(
          key: _smartKey,
          onMenuTap: onMenuTap,
          onSessionChanged: (id) => setState(() => _activeSessionIds[ChatMode.smartRouting] = id),
        );
    }
  }

  void _newChat() {
    if (_adminSelected) return;
    switch (_index) {
      case 0:
        _smartKey.currentState?.startNewChat();
        break;
      case 1:
        _comparisonKey.currentState?.startNewChat();
        break;
      case 2:
        _offlineKey.currentState?.startNewChat();
        break;
    }
    setState(() => _activeSessionIds[_currentMode] = null);
  }

  void _openSession(ChatSession session) {
    final targetIndex = switch (session.mode) {
      ChatMode.smartRouting => 0,
      ChatMode.comparison => 1,
      ChatMode.offline => 2,
    };
    setState(() {
      _index = targetIndex;
      _adminSelected = false;
      _activeSessionIds[session.mode] = session.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (session.mode) {
        case ChatMode.smartRouting:
          _smartKey.currentState?.openSession(session);
          break;
        case ChatMode.comparison:
          _comparisonKey.currentState?.openSession(session);
          break;
        case ChatMode.offline:
          _offlineKey.currentState?.openSession(session);
          break;
      }
    });
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(isDarkMode: widget.isDarkMode, onToggleTheme: widget.onToggleTheme),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < _mobileBreakpoint;

      final sidebar = Sidebar(
        selectedIndex: _index,
        adminSelected: _adminSelected,
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
        onLogout: _logout,
        onNewChat: _newChat,
        activeSessionId: _activeSessionId,
        onSelectSession: _openSession,
        onSelect: (i) => setState(() {
          _index = i;
          _adminSelected = false;
        }),
        onAdminTap: () => setState(() => _adminSelected = true),
        onClose: isMobile ? () => Navigator.of(context).maybePop() : null,
      );

      if (isMobile) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: context.bg,
          drawer: Drawer(backgroundColor: context.surface, child: SafeArea(child: sidebar)),
          body: SafeArea(
            child: _currentScreen(onMenuTap: () => _scaffoldKey.currentState?.openDrawer()),
          ),
        );
      }

      return Scaffold(
        backgroundColor: context.bg,
        body: Row(
          children: [
            sidebar,
            VerticalDivider(width: 1, color: context.borderColor),
            Expanded(child: SafeArea(child: _currentScreen())),
          ],
        ),
      );
    });
  }
}
