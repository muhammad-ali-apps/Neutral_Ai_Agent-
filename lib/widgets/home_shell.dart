import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models.dart';
import '../services/api_services.dart';
import '../services/model_download_manager.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/comparison_screen.dart';
import '../screens/offline_mode_screen.dart';
import '../screens/smart_routing_screen.dart';
import 'sidebar.dart';
import 'package:go_router/go_router.dart';

/// Root shell with responsive sidebar and mode navigation.
class HomeShell extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final bool startWithAdmin;
  const HomeShell({
    super.key, 
    required this.isDarkMode, 
    required this.onToggleTheme,
    this.startWithAdmin = false,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late bool _adminSelected = widget.startWithAdmin;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _smartKey = GlobalKey<SmartRoutingScreenState>();
  final _comparisonKey = GlobalKey<ComparisonScreenState>();
  final _offlineKey = GlobalKey<OfflineModeScreenState>();

  StreamSubscription? _downloadErrorSub;

  @override
  void initState() {
    super.initState();
    modelStore.loadFromApi();
    historyStore.loadFromApi();


    _downloadErrorSub = modelDownloadManager.onModelError.listen((err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed for ${err['modelId']}: ${err['error']}'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  void dispose() {
    _downloadErrorSub?.cancel();
    super.dispose();
  }

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
    return IndexedStack(
      index: _index.clamp(0, 2),
      children: [
        SmartRoutingScreen(
          key: _smartKey,
          onMenuTap: onMenuTap,
          onSessionChanged: (id) => setState(() => _activeSessionIds[ChatMode.smartRouting] = id),
          isDarkMode: themeController.isDark,
          onToggleTheme: themeController.toggle,
        ),
        ComparisonScreen(
          key: _comparisonKey,
          onMenuTap: onMenuTap,
          onSessionChanged: (id) => setState(() => _activeSessionIds[ChatMode.comparison] = id),
        ),
        OfflineModeScreen(
          key: _offlineKey,
          onMenuTap: onMenuTap,
          onSessionChanged: (id) => setState(() => _activeSessionIds[ChatMode.offline] = id),
        ),
      ],
    );
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

  void _openSession(ChatSession session) async {
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

    final hasEmptyMessages = session.messages.isEmpty ||
        session.messages.any((m) => !m.isUser && m.text.trim().isEmpty);
    if (hasEmptyMessages) {
      final targetId = session.backendSessionId ?? session.id;
      final fullData = await ApiService.fetchChatSessionById(targetId);
      if (fullData != null) {
        final fullSession = ChatSession.fromJson(fullData);
        session.messages.clear();
        session.messages.addAll(fullSession.messages);
      }
    }

    if (!mounted) return;
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
  }

  void _logout() {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return LayoutBuilder(builder: (context, constraints) {
          final isMobile = constraints.maxWidth < _mobileBreakpoint;

          final sidebar = Sidebar(
            selectedIndex: _index,
            adminSelected: _adminSelected,
            isDarkMode: themeController.isDark,
            onToggleTheme: themeController.toggle,
            onLogout: _logout,
            onNewChat: _newChat,
            activeSessionId: _activeSessionId,
            onSelectSession: _openSession,
            isDrawer: isMobile,
            onSelect: (i) {
              if (widget.startWithAdmin) {
                context.go('/home');
              } else {
                setState(() {
                  _index = i;
                  _adminSelected = false;
                });
              }
            },
            onAdminTap: () {
              if (!widget.startWithAdmin) {
                context.go('/admin-panel');
              }
            },
            onClose: isMobile ? () => Navigator.of(context).maybePop() : null,
          );

          if (isMobile) {
            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: context.bg,
              drawer: Drawer(
                backgroundColor: context.surface,
                width: constraints.maxWidth < 340 ? constraints.maxWidth * 0.85 : 280,
                child: SafeArea(child: sidebar),
              ),
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
      },
    );
  }
}
