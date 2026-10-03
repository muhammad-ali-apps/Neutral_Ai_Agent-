import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'services/api_services.dart';

/// Provider enum matching backend values.
enum LlmProvider {
  openai,
  gemini,
  anthropic,
  ollama,
  custom;

  /// Display name for the UI.
  String get displayName {
    switch (this) {
      case LlmProvider.openai:
        return 'OpenAI';
      case LlmProvider.gemini:
        return 'Google Gemini';
      case LlmProvider.anthropic:
        return 'Anthropic Claude';
      case LlmProvider.ollama:
        return 'Ollama (Local)';
      case LlmProvider.custom:
        return 'Custom API';
    }
  }

  /// Badge letter for circle avatar.
  String get letter {
    switch (this) {
      case LlmProvider.openai:
        return 'O';
      case LlmProvider.gemini:
        return 'G';
      case LlmProvider.anthropic:
        return 'A';
      case LlmProvider.ollama:
        return 'O';
      case LlmProvider.custom:
        return 'C';
    }
  }

  /// Default color for the provider badge.
  Color get color {
    switch (this) {
      case LlmProvider.openai:
        return AppColors.openaiGreen;
      case LlmProvider.gemini:
        return AppColors.geminiBlue;
      case LlmProvider.anthropic:
        return AppColors.anthropicOrange;
      case LlmProvider.ollama:
        return AppColors.deepseekGray;
      case LlmProvider.custom:
        return AppColors.purple;
    }
  }

  /// Convert from backend string (e.g. "openai") to enum.
  static LlmProvider fromString(String value) {
    return LlmProvider.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => LlmProvider.custom,
    );
  }
}

/// LLM model entry used across Comparison, Admin, and Smart Routing.
class LlmModel {
  final String id;
  String name;
  String provider;       // backend enum string: openai, gemini, etc.
  String modelCode;      // model_id in backend
  String badgeLetter;
  Color color;
  List<String> tags;     // routing_tags in backend
  bool active;           // is_active in backend
  String? apiKey;
  String? endpointUrl;
  String? description;
  String? iconColor;
  bool isRouter;         // is_router in backend
  double? temperature;   // temperature in backend
  int? maxTokens;        // max_tokens in backend

  LlmModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.modelCode,
    required this.badgeLetter,
    required this.color,
    required this.tags,
    this.active = true,
    this.apiKey,
    this.endpointUrl,
    this.description,
    this.iconColor,
    this.isRouter = false,
    this.temperature,
    this.maxTokens,
  });

  /// Create from backend JSON response.
  factory LlmModel.fromJson(Map<String, dynamic> json) {
    final providerStr = (json['provider'] ?? 'custom').toString();
    final providerEnum = LlmProvider.fromString(providerStr);

    Color modelColor = providerEnum.color;
    if (json['icon_color'] != null && json['icon_color'].toString().isNotEmpty) {
      try {
        final hex = json['icon_color'].toString().replaceFirst('#', '');
        modelColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    final id = json['_id'] is Map
        ? (json['_id']['\$oid'] ?? json['_id'].toString())
        : (json['_id'] ?? json['id'] ?? '').toString();

    bool parseBool(dynamic val, {bool defaultValue = true}) {
      if (val == null) return defaultValue;
      if (val is bool) return val;
      if (val is num) return val != 0;
      if (val is String) {
        final s = val.trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'yes';
      }
      return defaultValue;
    }

    List<String> parseTags(dynamic tagsVal) {
      if (tagsVal == null) return [];
      if (tagsVal is List) return tagsVal.map((e) => e.toString()).toList();
      if (tagsVal is String) return tagsVal.split(',').map((e) => e.trim()).toList();
      return [];
    }

    return LlmModel(
      id: id,
      name: (json['name'] ?? json['model_name'] ?? '').toString(),
      provider: providerStr,
      modelCode: (json['model_id'] ?? json['model_code'] ?? '').toString(),
      badgeLetter: providerEnum.letter,
      color: modelColor,
      tags: parseTags(json['routing_tags'] ?? json['tags']),
      active: parseBool(json['is_active'], defaultValue: true),
      apiKey: json['api_key']?.toString(),
      endpointUrl: json['endpoint_url']?.toString(),
      description: json['description']?.toString(),
      iconColor: json['icon_color']?.toString(),
      isRouter: parseBool(json['is_router'], defaultValue: false),
      temperature: json['temperature'] != null ? double.tryParse(json['temperature'].toString()) : null,
      maxTokens: json['max_tokens'] != null ? int.tryParse(json['max_tokens'].toString()) : null,
    );
  }

  /// Convert to JSON for API requests.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'provider': provider,
      'model_id': modelCode,
      if (apiKey != null && apiKey!.isNotEmpty) 'api_key': apiKey,
      if (endpointUrl != null) 'endpoint_url': endpointUrl,
      'routing_tags': tags,
      'is_active': active,
      if (description != null) 'description': description,
      if (iconColor != null) 'icon_color': iconColor,
      'is_router': isRouter,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
    };
  }
}

/// Shared model store; Admin mutates via API, other screens listen.
class ModelStore extends ChangeNotifier {
  List<LlmModel> models = [];
  bool isLoading = false;
  String? errorMessage;

  List<LlmModel> get active {
    final act = models.where((m) => m.active).toList();
    return act.isNotEmpty ? act : models;
  }

  /// Fetch all models from backend API.
  Future<void> loadFromApi() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await ApiService.fetchLlmModels();
      if (result != null) {
        models = result.map((json) => LlmModel.fromJson(json)).toList();
        errorMessage = null;
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      print('ModelStore.loadFromApi error: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  /// Add a new model via API.
  Future<bool> addViaApi(Map<String, dynamic> data) async {
    try {
      final result = await ApiService.createLlmModel(data);
      if (result != null) {
        models.insert(0, LlmModel.fromJson(result));
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('ModelStore.addViaApi error: $e');
    }
    return false;
  }

  /// Update an existing model via API.
  Future<bool> updateViaApi(String id, Map<String, dynamic> data) async {
    try {
      final result = await ApiService.updateLlmModel(id, data);
      if (result != null) {
        final idx = models.indexWhere((m) => m.id == id);
        if (idx >= 0) {
          models[idx] = LlmModel.fromJson(result);
        }
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('ModelStore.updateViaApi error: $e');
    }
    return false;
  }

  /// Toggle active status via API.
  Future<bool> toggleActiveViaApi(String id) async {
    final model = models.where((m) => m.id == id).cast<LlmModel?>().firstOrNull;
    if (model == null) return false;

    final newActive = !model.active;

    // Optimistic update
    model.active = newActive;
    notifyListeners();

    try {
      final result = await ApiService.updateLlmModel(id, {'is_active': newActive});
      if (result != null) {
        return true;
      } else {
        // Revert on failure
        model.active = !newActive;
        notifyListeners();
      }
    } catch (e) {
      // Revert on error
      model.active = !newActive;
      notifyListeners();
      print('ModelStore.toggleActiveViaApi error: $e');
    }
    return false;
  }

  /// Delete a model via API.
  Future<bool> deleteViaApi(String id) async {
    try {
      final success = await ApiService.deleteLlmModel(id);
      if (success) {
        models.removeWhere((m) => m.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('ModelStore.deleteViaApi error: $e');
    }
    return false;
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

/// Attachment metadata for chat messages (screenshots, images, or project files).
class ChatAttachment {
  final String name;
  final String? path;
  final Uint8List? bytes;
  final bool isImage;
  final String? fileType; // 'screenshot', 'camera', 'project'
  final int? sizeInBytes;

  ChatAttachment({
    required this.name,
    this.path,
    this.bytes,
    this.isImage = false,
    this.fileType,
    this.sizeInBytes,
  });

  String get formattedSize {
    int count = sizeInBytes ?? bytes?.length ?? 0;
    if (count == 0) {
      return isImage ? 'Image File' : 'Project File';
    }
    final kb = count / 1024;
    if (kb >= 1024) {
      return '${(kb / 1024).toStringAsFixed(1)} MB';
    }
    return '${kb.toStringAsFixed(0)} KB';
  }

  String get extensionLabel {
    final idx = name.lastIndexOf('.');
    if (idx != -1 && idx < name.length - 1) {
      final ext = name.substring(idx + 1).toUpperCase();
      if (ext.length <= 5) return ext;
    }
    return isImage ? 'IMG' : 'FILE';
  }

  String get typeSubtitle {
    final ext = extensionLabel;
    final size = formattedSize;
    if (fileType == 'screenshot') return 'Screenshot • $size';
    if (fileType == 'camera') return 'Photo • $size';
    if (fileType == 'project') return '$ext File • $size';
    return isImage ? 'Image • $size' : '$ext Document • $size';
  }
}

class ChatMessage {
  bool isUser;
  String text;
  String? modelName;
  String? category;
  String? routingMethod;
  List<ChatAttachment> attachments;
  double? latencyMs;
  Map<String, dynamic>? tokenUsage;
  String? status;

  ChatMessage({
    required this.isUser,
    required this.text,
    this.modelName,
    this.category,
    this.routingMethod,
    this.attachments = const [],
    this.latencyMs,
    this.tokenUsage,
    this.status,
  });
}

class ChatSession {
  final String id;
  String title;
  final ChatMode mode;
  final List<ChatMessage> messages;
  DateTime updatedAt;
  String? backendSessionId;

  ChatSession({
    required this.id,
    required this.title,
    required this.mode,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
    this.backendSessionId,
  })  : messages = messages ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  String get preview => messages.isEmpty ? 'New conversation' : messages.first.text;

  /// Create ChatSession from backend JSON response.
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawId = json['_id'] is Map
        ? (json['_id']['\$oid'] ?? json['_id'].toString())
        : (json['_id'] ?? json['id'] ?? json['session_id'] ?? '').toString();

    final backendId = (json['session_id'] ?? rawId).toString();

    final modeStr = (json['mode'] ?? 'smart').toString().toLowerCase();
    ChatMode chatMode;
    if (modeStr == 'compare' || modeStr == 'comparison') {
      chatMode = ChatMode.comparison;
    } else if (modeStr == 'offline') {
      chatMode = ChatMode.offline;
    } else {
      chatMode = ChatMode.smartRouting;
    }

    final parsedMessages = <ChatMessage>[];
    if (json['messages'] is List) {
      for (final msg in (json['messages'] as List)) {
        if (msg is Map<String, dynamic>) {
          final isUser = msg['is_user'] == true ||
              msg['role'] == 'user' ||
              msg['isUser'] == true;
          final text = (msg['text'] ?? msg['content'] ?? msg['message'] ?? '').toString();
          final modelName = msg['model_name'] ?? msg['model'] ?? msg['routed_model'];
          parsedMessages.add(ChatMessage(
            isUser: isUser,
            text: text,
            modelName: modelName?.toString(),
            category: msg['category']?.toString(),
            routingMethod: msg['routing_method']?.toString(),
            latencyMs: msg['latency_ms'] != null ? double.tryParse(msg['latency_ms'].toString()) : null,
            tokenUsage: msg['token_usage'] is Map ? Map<String, dynamic>.from(msg['token_usage']) : null,
            status: msg['status']?.toString(),
          ));
        }
      }
    }

    DateTime updated = DateTime.now();
    if (json['updated_at'] != null) {
      updated = DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now();
    } else if (json['created_at'] != null) {
      updated = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    }

    return ChatSession(
      id: rawId.isNotEmpty ? rawId : backendId,
      title: (json['title'] ?? 'New Chat').toString(),
      mode: chatMode,
      messages: parsedMessages,
      updatedAt: updated,
      backendSessionId: backendId,
    );
  }
}

/// Chat history store backed by backend REST API and in-memory caching.
class HistoryStore extends ChangeNotifier {
  final List<ChatSession> sessions = [];
  bool isLoading = false;

  /// Fetch all sessions from backend API.
  Future<void> loadFromApi() async {
    isLoading = true;
    notifyListeners();

    try {
      final data = await ApiService.fetchChatSessions();
      if (data != null) {
        sessions.clear();
        for (final item in data) {
          sessions.add(ChatSession.fromJson(item));
        }
      }
    } catch (e) {
      print('HistoryStore.loadFromApi error: $e');
    }

    isLoading = false;
    notifyListeners();
  }

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

  Future<void> rename(String id, String newTitle) async {
    final s = sessions.where((e) => e.id == id || e.backendSessionId == id).cast<ChatSession?>().firstOrNull;
    if (s != null) {
      s.title = newTitle;
      notifyListeners();
      final targetId = s.backendSessionId ?? s.id;
      await ApiService.renameChatSession(targetId, newTitle);
    }
  }

  Future<void> delete(String id) async {
    final s = sessions.where((e) => e.id == id || e.backendSessionId == id).cast<ChatSession?>().firstOrNull;
    final targetId = s?.backendSessionId ?? id;
    sessions.removeWhere((e) => e.id == id || e.backendSessionId == id);
    notifyListeners();
    await ApiService.deleteChatSession(targetId);
  }

  List<ChatSession> forMode(ChatMode mode) =>
      sessions.where((s) => s.mode == mode).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

extension FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

final historyStore = HistoryStore();
