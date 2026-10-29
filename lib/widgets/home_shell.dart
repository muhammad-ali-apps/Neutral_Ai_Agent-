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
import 'package:shared_preferences/shared_preferences.dart';

/// Root shell with responsive sidebar and mode navigation.
class HomeShell extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final bool startWithAdmin;
  final int initialIndex;
  const HomeShell({
    super.key, 
    required this.isDarkMode, 
    required this.onToggleTheme,
    this.startWithAdmin = false,
    this.initialIndex = 0,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;
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
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startWithAdmin != oldWidget.startWithAdmin) {
      setState(() {
        _adminSelected = widget.startWithAdmin;
      });
    }
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _index = widget.initialIndex;
        if (!widget.startWithAdmin) {
          _adminSelected = false;
        }
      });
    }
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

  void _closeDrawerIfOpen() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  Widget _currentScreen({VoidCallback? onMenuTap}) {
    final activeIndex = _adminSelected ? 3 : _index.clamp(0, 2);
    return FadeIndexedStack(
      index: activeIndex,
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
        AdminPanelScreen(onMenuTap: onMenuTap),
      ],
    );
  }

  void _newChat() {
    if (_adminSelected) {
      setState(() {
        _adminSelected = false;
        _index = 0;
      });
    }
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

  void _selectMode(int i) {
    if (_index == i && !_adminSelected) return;
    setState(() {
      _index = i;
      _adminSelected = false;
    });
  }

  void _selectAdmin() {
    if (_adminSelected) return;
    setState(() {
      _adminSelected = true;
    });
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('userRole');
    unawaited(ApiService.logoutUser());
    if (mounted) {
      context.go('/login');
    }
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
            onSelect: _selectMode,
            onAdminTap: _selectAdmin,
            onClose: isMobile ? _closeDrawerIfOpen : null,
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

/// Animated indexed stack that smoothly fades between screens.
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      setState(() {
        _currentIndex = widget.index;
      });
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      child: IndexedStack(
        index: _currentIndex,
        children: widget.children,
      ),
    );
  }
}
