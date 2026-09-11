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
  });

  /// Create from backend JSON response.
  factory LlmModel.fromJson(Map<String, dynamic> json) {
    final providerStr = (json['provider'] ?? 'custom').toString();
    final providerEnum = LlmProvider.fromString(providerStr);

    // Parse icon_color if present, otherwise use provider default
    Color modelColor = providerEnum.color;
    if (json['icon_color'] != null && json['icon_color'].toString().isNotEmpty) {
      try {
        final hex = json['icon_color'].toString().replaceFirst('#', '');
        modelColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    // Handle MongoDB _id field
    final id = json['_id'] is Map ? json['_id']['\$oid'] ?? json['_id'].toString() : (json['_id'] ?? json['id'] ?? '').toString();

    return LlmModel(
      id: id,
      name: json['name'] ?? '',
      provider: providerStr,
      modelCode: json['model_id'] ?? '',
      badgeLetter: providerEnum.letter,
      color: modelColor,
      tags: json['routing_tags'] != null
          ? List<String>.from(json['routing_tags'])
          : [],
      active: json['is_active'] ?? true,
      apiKey: json['api_key'],
      endpointUrl: json['endpoint_url'],
      description: json['description'],
      iconColor: json['icon_color'],
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
    };
  }
}

List<LlmModel> seedModels() => [
      LlmModel(
        id: 'claude-3-5-sonnet',
        name: 'Claude 3.5 Sonnet',
        provider: 'anthropic',
        modelCode: 'claude-3-5-sonnet-20241022',
        badgeLetter: 'C',
        color: AppColors.anthropicOrange,
        tags: ['reasoning', 'coding', 'writing', 'analysis'],
        active: true,
      ),
      LlmModel(
        id: 'gpt-4o',
        name: 'GPT-4o',
        provider: 'openai',
        modelCode: 'gpt-4o',
        badgeLetter: 'G',
        color: AppColors.openaiGreen,
        tags: ['reasoning', 'general', 'coding'],
        active: true,
      ),
      LlmModel(
        id: 'gemini-1-5-pro',
        name: 'Gemini 1.5 Pro',
        provider: 'gemini',
        modelCode: 'gemini-1.5-pro',
        badgeLetter: 'G',
        color: AppColors.geminiBlue,
        tags: ['reasoning', 'multimodal'],
        active: true,
      ),
      LlmModel(
        id: 'deepseek-v3',
        name: 'DeepSeek V3',
        provider: 'custom',
        modelCode: 'deepseek-chat',
        badgeLetter: 'D',
        color: AppColors.deepseekGray,
        tags: ['coding', 'science', 'math'],
        active: true,
      ),
      LlmModel(
        id: 'gpt-3-5-turbo',
        name: 'GPT-3.5 Turbo',
        provider: 'openai',
        modelCode: 'gpt-3.5-turbo',
        badgeLetter: 'O',
        color: AppColors.openaiGreen,
        tags: ['general', 'creative'],
        active: true,
      ),
    ];

/// Shared model store; Admin mutates via API, other screens listen.
class ModelStore extends ChangeNotifier {
  List<LlmModel> models = seedModels();
  bool isLoading = false;
  String? errorMessage;

  List<LlmModel> get active {
    final act = models.where((m) => m.active).toList();
    return act.isNotEmpty ? act : (models.isNotEmpty ? models : seedModels());
  }

  /// Fetch all models from backend API.
  Future<void> loadFromApi() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await ApiService.fetchLlmModels();
      if (result != null && result.isNotEmpty) {
        models = result.map((json) => LlmModel.fromJson(json)).toList();
        errorMessage = null;
      } else if (models.isEmpty) {
        models = seedModels();
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (models.isEmpty) {
        models = seedModels();
      }
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
  List<ChatAttachment> attachments;

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
