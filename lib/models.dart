import 'package:flutter/material.dart';
import 'app_theme.dart';

/// LLM model entry used across Comparison, Admin, and Smart Routing.
class LlmModel {
  final String id;
  String name;
  String provider;
  String modelCode;
  String badgeLetter;
  Color color;
  List<String> tags;
  bool active;

  LlmModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.modelCode,
    required this.badgeLetter,
    required this.color,
    required this.tags,
    this.active = true,
  });
}

List<LlmModel> _seedModels() => [
      LlmModel(
        id: 'deepseek',
        name: 'Deep Seek',
        provider: 'Custom API',
        modelCode: 'Deepseek3.0',
        badgeLetter: 'D',
        color: AppColors.deepseekGray,
        tags: ['science'],
        active: false,
      ),
      LlmModel(
        id: 'gpt4o',
        name: 'GPT-4o',
        provider: 'OpenAI',
        modelCode: 'gpt-4o',
        badgeLetter: 'G',
        color: AppColors.openaiGreen,
        tags: ['reasoning', 'general', 'coding'],
      ),
      LlmModel(
        id: 'gpt35',
        name: 'GPT-3.5 Turbo',
        provider: 'OpenAI',
        modelCode: 'gpt-3.5-turbo',
        badgeLetter: 'G',
        color: AppColors.openaiGreen,
        tags: ['general', 'creative'],
      ),
      LlmModel(
        id: 'gemini',
        name: 'Gemini 1.5 Pro',
        provider: 'Gemini',
        modelCode: 'gemini-1.5-pro',
        badgeLetter: 'G',
        color: AppColors.geminiBlue,
        tags: ['reasoning', 'multimodal'],
      ),
      LlmModel(
        id: 'claude',
        name: 'Claude 3.5 Sonnet',
        provider: 'Anthropic',
        modelCode: 'claude-3.5-sonnet',
        badgeLetter: 'C',
        color: AppColors.anthropicOrange,
        tags: ['reasoning', 'coding', 'writing'],
      ),
    ];

/// Shared model store; Admin mutates, other screens listen.
class ModelStore extends ChangeNotifier {
  final List<LlmModel> models = _seedModels();

  List<LlmModel> get active => models.where((m) => m.active).toList();

  void add(LlmModel model) {
    models.add(model);
    notifyListeners();
  }

  void remove(String id) {
    models.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  void toggleActive(String id) {
    final m = models.where((e) => e.id == id).cast<LlmModel?>().firstOrNull;
    if (m == null) return;
    m.active = !m.active;
    notifyListeners();
  }

  void refresh() => notifyListeners();
}

final modelStore = ModelStore();

enum ChatMode { smartRouting, comparison, offline }

extension ChatModeX on ChatMode {
  String get label {
    switch (this) {
      case ChatMode.smartRouting:
        return 'Smart Routing';
      case ChatMode.comparison:
        return 'Comparison';
      case ChatMode.offline:
        return 'Offline Mode';
    }
  }

  IconData get icon {
    switch (this) {
      case ChatMode.smartRouting:
        return Icons.bolt_rounded;
      case ChatMode.comparison:
        return Icons.grid_view_rounded;
      case ChatMode.offline:
        return Icons.wifi_off_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ChatMode.smartRouting:
        return AppColors.purple;
      case ChatMode.comparison:
        return AppColors.geminiBlue;
      case ChatMode.offline:
        return AppColors.deepseekGray;
    }
  }
}

class ChatMessage {
  bool isUser;
  String text;
  String? modelName;
  List<String> attachments;

  ChatMessage({
    required this.isUser,
    required this.text,
    this.modelName,
    this.attachments = const [],
  });
}

class ChatSession {
  final String id;
  String title;
  final ChatMode mode;
  final List<ChatMessage> messages;
  DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.mode,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  })  : messages = messages ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  String get preview => messages.isEmpty ? 'New conversation' : messages.first.text;
}

/// In-memory chat history store across all modes.
class HistoryStore extends ChangeNotifier {
  final List<ChatSession> sessions = [];

  void addSession(ChatSession session) {
    sessions.insert(0, session);
    notifyListeners();
  }

  void touch(ChatSession session) {
    session.updatedAt = DateTime.now();
    sessions.remove(session);
    sessions.insert(0, session);
    notifyListeners();
  }

  void rename(String id, String newTitle) {
    final s = sessions.where((e) => e.id == id).cast<ChatSession?>().firstOrNull;
    if (s == null) return;
    s.title = newTitle;
    notifyListeners();
  }

  void delete(String id) {
    sessions.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  List<ChatSession> forMode(ChatMode mode) =>
      sessions.where((s) => s.mode == mode).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

extension FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

final historyStore = HistoryStore();
