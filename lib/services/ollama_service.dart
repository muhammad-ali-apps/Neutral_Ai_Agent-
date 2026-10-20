import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Data class representing an Ollama model already downloaded and installed locally.
class InstalledModel {
  final String name;
  final String modelTag;
  final int sizeBytes;
  final String sizeFormatted;
  final DateTime? modifiedAt;
  final String? parameterSize;
  final String? quantizationLevel;

  InstalledModel({
    required this.name,
    required this.modelTag,
    required this.sizeBytes,
    required this.sizeFormatted,
    this.modifiedAt,
    this.parameterSize,
    this.quantizationLevel,
  });

  factory InstalledModel.fromJson(Map<String, dynamic> json) {
    final rawSize = json['size'] ?? 0;
    final sizeBytes = rawSize is int ? rawSize : int.tryParse(rawSize.toString()) ?? 0;
    final sizeGb = (sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
    final sizeFormatted = sizeBytes > 0 ? '$sizeGb GB' : 'Unknown';

    final details = json['details'] as Map<String, dynamic>? ?? {};
    final modifiedStr = json['modified_at']?.toString();
    DateTime? modifiedDate;
    if (modifiedStr != null) {
      modifiedDate = DateTime.tryParse(modifiedStr);
    }

    final rawName = (json['name'] ?? json['model'] ?? '').toString();

    return InstalledModel(
      name: rawName,
      modelTag: rawName,
      sizeBytes: sizeBytes,
      sizeFormatted: sizeFormatted,
      modifiedAt: modifiedDate,
      parameterSize: details['parameter_size']?.toString(),
      quantizationLevel: details['quantization_level']?.toString(),
    );
  }
}

/// Catalog entry for offline models available to download.
class CatalogModel {
  final String name;
  final String modelId;
  final String size;
  final String parameters;
  final String description;
  final List<String> routingTags;
  final int minRamGb;
  final String tier;

  CatalogModel({
    required this.name,
    required this.modelId,
    required this.size,
    required this.parameters,
    required this.description,
    required this.routingTags,
    required this.minRamGb,
    required this.tier,
  });

  factory CatalogModel.fromJson(Map<String, dynamic> json, {String tier = 'balanced', int minRam = 8}) {
    List<String> tags = [];
    if (json['routing_tags'] is List) {
      tags = (json['routing_tags'] as List).map((e) => e.toString()).toList();
    }
    return CatalogModel(
      name: (json['name'] ?? '').toString(),
      modelId: (json['model_id'] ?? '').toString(),
      size: (json['size'] ?? '').toString(),
      parameters: (json['parameters'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      routingTags: tags,
      minRamGb: json['min_ram_gb'] ?? minRam,
      tier: tier,
    );
  }
}

/// Status payload emitted during `ollama pull` streaming.
class PullProgress {
  final String status;
  final int totalBytes;
  final int completedBytes;
  final double percent;
  final bool isCompleted;
  final String? error;

  PullProgress({
    required this.status,
    required this.totalBytes,
    required this.completedBytes,
    required this.percent,
    this.isCompleted = false,
    this.error,
  });

  String get formattedTotal {
    if (totalBytes <= 0) return '';
    if (totalBytes >= 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedCompleted {
    if (completedBytes <= 0) return '0 MB';
    if (completedBytes >= 1024 * 1024 * 1024) {
      return '${(completedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(completedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get progressSummary {
    if (totalBytes > 0) {
      return '$formattedCompleted / $formattedTotal';
    }
    return formattedCompleted;
  }

  bool get isIndeterminate => (totalBytes <= 0 || percent <= 0.01) && !isCompleted && error == null;
}

class OllamaService {
  static const String baseUrl = 'http://127.0.0.1:11434';
  static const String backendUrl = 'http://127.0.0.1:8000/api';

  /// Ping Ollama to verify if engine is responsive
  static Future<bool> isOllamaRunning() async {
    try {
      final res = await http.get(Uri.parse(baseUrl)).timeout(const Duration(milliseconds: 1800));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Locate ollama binary on Windows system
  static Future<String?> findOllamaBinary() async {
    if (!Platform.isWindows) return 'ollama';

    // 1. Try PATH
    try {
      final res = await Process.run('where.exe', ['ollama']);
      if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
        final path = res.stdout.toString().trim().split('\r\n').first.trim();
        if (File(path).existsSync()) return path;
      }
    } catch (_) {}

    // 2. Check standard Windows AppData location
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null) {
      final stdPath = '$localAppData\\Programs\\Ollama\\ollama.exe';
      if (File(stdPath).existsSync()) return stdPath;
    }

    // 3. Check Program Files
    const pFiles = 'C:\\Program Files\\Ollama\\ollama.exe';
    if (File(pFiles).existsSync()) return pFiles;

    return null;
  }

  /// Ensure Ollama engine is started in background
  static Future<bool> ensureOllamaRunning() async {
    if (await isOllamaRunning()) return true;

    final exePath = await findOllamaBinary();
    if (exePath == null) return false;

    try {
      await Process.start(
        exePath,
        ['serve'],
        mode: ProcessStartMode.detached,
      );

      // Poll until responsive (up to 4 seconds)
      for (int i = 0; i < 8; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await isOllamaRunning()) return true;
      }
    } catch (e) {
      print('Failed to start Ollama background service: $e');
    }
    return false;
  }

  /// One-Click Silent Installer for Windows
  /// Downloads official OllamaSetup.exe silently and executes with /VERYSILENT /NORESTART
  static Stream<double> autoInstallOllamaOnWindows({Function(String status)? onStatus}) async* {
    if (!Platform.isWindows) {
      throw UnsupportedError('Auto-install is currently supported on Windows.');
    }

    onStatus?.call('Preparing installation environment...');
    yield 0.05;

    final tempDir = Directory.systemTemp.path;
    final installerPath = '$tempDir\\OllamaSetup.exe';
    const downloadUrl = 'https://ollama.com/download/OllamaSetup.exe';

    onStatus?.call('Downloading Ollama Engine (around 65MB)...');
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed with status ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? (65 * 1024 * 1024);
      int received = 0;
      final file = File(installerPath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        final progress = (received / contentLength).clamp(0.0, 1.0);
        // Map download progress from 0.05 to 0.85
        yield 0.05 + (progress * 0.80);
      }
      await sink.flush();
      await sink.close();

      onStatus?.call('Installing Ollama silently in background...');
      yield 0.90;

      final installRes = await Process.run(installerPath, ['/VERYSILENT', '/NORESTART']);
      if (installRes.exitCode != 0) {
        print('Installer finished with code ${installRes.exitCode}: ${installRes.stderr}');
      }

      onStatus?.call('Starting Ollama background engine...');
      yield 0.95;

      await ensureOllamaRunning();
      onStatus?.call('Installation complete! Engine is active.');
      yield 1.0;
    } finally {
      client.close();
    }
  }

  /// Fetch list of models already installed on user's machine
  static Future<List<InstalledModel>> getInstalledModels() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/tags')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final modelsList = data['models'] as List<dynamic>? ?? [];
        return modelsList.map((m) => InstalledModel.fromJson(m as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      print('Error fetching local models: $e');
    }
    return [];
  }

  /// Fetch recommended offline models catalog (from Laravel backend or offline fallback)
  static Future<List<CatalogModel>> getCatalog() async {
    // 1. Attempt to fetch from backend
    try {
      final res = await http.get(Uri.parse('$backendUrl/offline/catalog')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final categories = data['categories'] as List<dynamic>? ?? [];
        final List<CatalogModel> models = [];
        for (final cat in categories) {
          final tier = cat['tier']?.toString() ?? 'balanced';
          final minRam = cat['min_ram_gb'] ?? 8;
          final catModels = cat['models'] as List<dynamic>? ?? [];
          for (final m in catModels) {
            models.add(CatalogModel.fromJson(m as Map<String, dynamic>, tier: tier, minRam: minRam));
          }
        }
        if (models.isNotEmpty) return models;
      }
    } catch (_) {
      // Backend unreachable or offline - use curated static fallback below
    }

    // 2. Built-in Offline Fallback Catalog
    return [
      CatalogModel(
        name: 'Llama 3.2 (1B)',
        modelId: 'llama3.2:1b',
        size: '1.3 GB',
        parameters: '1.23B',
        description: 'Ultra-fast model for basic Q&A, formatting, and quick answers.',
        routingTags: ['general', 'quick', 'chat'],
        minRamGb: 4,
        tier: 'entry_level',
      ),
      CatalogModel(
        name: 'Qwen 2.5 Coder (1.5B)',
        modelId: 'qwen2.5-coder:1.5b',
        size: '1.6 GB',
        parameters: '1.54B',
        description: 'Fast code generation and debugging for lightweight machines.',
        routingTags: ['coding', 'quick'],
        minRamGb: 4,
        tier: 'entry_level',
      ),
      CatalogModel(
        name: 'DeepSeek-R1 (1.5B Distilled)',
        modelId: 'deepseek-r1:1.5b',
        size: '1.1 GB',
        parameters: '1.5B',
        description: 'Compact reasoning model capable of step-by-step thinking.',
        routingTags: ['reasoning', 'math'],
        minRamGb: 4,
        tier: 'entry_level',
      ),
      CatalogModel(
        name: 'Llama 3.2 (3B)',
        modelId: 'llama3.2:3b',
        size: '2.0 GB',
        parameters: '3.21B',
        description: 'Superior balance between speed and intelligence. Highly recommended.',
        routingTags: ['general', 'reasoning', 'creative'],
        minRamGb: 8,
        tier: 'balanced',
      ),
      CatalogModel(
        name: 'Phi-3 Mini (3.8B)',
        modelId: 'phi3:mini',
        size: '2.3 GB',
        parameters: '3.8B',
        description: 'Microsoft state-of-the-art small model with strong reasoning.',
        routingTags: ['reasoning', 'general'],
        minRamGb: 8,
        tier: 'balanced',
      ),
      CatalogModel(
        name: 'DeepSeek-R1 (8B Distilled)',
        modelId: 'deepseek-r1:8b',
        size: '4.9 GB',
        parameters: '8B',
        description: 'Advanced reasoning & step-by-step logic solver.',
        routingTags: ['reasoning', 'math', 'coding'],
        minRamGb: 8,
        tier: 'balanced',
      ),
      CatalogModel(
        name: 'Qwen 2.5 Coder (7B)',
        modelId: 'qwen2.5-coder:7b',
        size: '4.7 GB',
        parameters: '7.6B',
        description: 'State-of-the-art coding and architectural model.',
        routingTags: ['coding', 'architecture'],
        minRamGb: 16,
        tier: 'pro',
      ),
      CatalogModel(
        name: 'Moondream 2 (Vision 1.8B)',
        modelId: 'moondream:latest',
        size: '1.7 GB',
        parameters: '1.86B',
        description: 'Lightweight vision AI model capable of analyzing images and screenshots.',
        routingTags: ['vision', 'image', 'multimodal'],
        minRamGb: 4,
        tier: 'entry_level',
      ),
      CatalogModel(
        name: 'LLaVA (Vision 7B)',
        modelId: 'llava:7b',
        size: '4.7 GB',
        parameters: '7B',
        description: 'High-accuracy visual reasoning model for in-depth image Q&A.',
        routingTags: ['vision', 'image', 'multimodal'],
        minRamGb: 8,
        tier: 'balanced',
      ),
    ];
  }

  /// Pull a model from Ollama with real-time download percentage stream
  static Stream<PullProgress> pullModelStream(String modelId) async* {
    final client = http.Client();
    try {
      final req = http.Request('POST', Uri.parse('$baseUrl/api/pull'));
      req.headers['Content-Type'] = 'application/json';
      req.body = json.encode({'name': modelId, 'stream': true});

      final response = await client.send(req);

      if (response.statusCode != 200) {
        yield PullProgress(
          status: 'Failed to initiate pull (HTTP ${response.statusCode})',
          totalBytes: 0,
          completedBytes: 0,
          percent: 0.0,
          error: 'HTTP ${response.statusCode}',
        );
        return;
      }

      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        while (buffer.contains('\n')) {
          final lineEnd = buffer.indexOf('\n');
          final line = buffer.substring(0, lineEnd).trim();
          buffer = buffer.substring(lineEnd + 1);

          if (line.isEmpty) continue;
          try {
            final jsonMap = json.decode(line) as Map<String, dynamic>;
            final status = jsonMap['status']?.toString() ?? 'downloading';
            final total = jsonMap['total'] is int ? jsonMap['total'] as int : 0;
            final completed = jsonMap['completed'] is int ? jsonMap['completed'] as int : 0;

            double percent = 0.0;
            if (total > 0) {
              percent = (completed / total).clamp(0.0, 1.0);
            }

            final isDone = status.toLowerCase().contains('success');

            yield PullProgress(
              status: status,
              totalBytes: total,
              completedBytes: completed,
              percent: isDone ? 1.0 : percent,
              isCompleted: isDone,
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      yield PullProgress(
        status: 'Error: $e',
        totalBytes: 0,
        completedBytes: 0,
        percent: 0.0,
        error: e.toString(),
      );
    } finally {
      client.close();
    }
  }

  /// Delete an installed model to reclaim storage
  static Future<bool> deleteModel(String modelId) async {
    try {
      final req = http.Request('DELETE', Uri.parse('$baseUrl/api/delete'));
      req.headers['Content-Type'] = 'application/json';
      req.body = json.encode({'name': modelId});
      final res = await req.send();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Generate chat completion stream from local Ollama model (supports multimodal images)
  static Stream<String> chatStream({
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async* {
    final client = http.Client();
    try {
      final req = http.Request('POST', Uri.parse('$baseUrl/api/chat'));
      req.headers['Content-Type'] = 'application/json';
      req.body = json.encode({
        'model': model,
        'messages': messages,
        'stream': true,
      });

      final response = await client.send(req);

      if (response.statusCode != 200) {
        String errDetail = '';
        try {
          final errBody = await response.stream.bytesToString();
          final errJson = json.decode(errBody);
          errDetail = errJson['error']?.toString() ?? errBody;
        } catch (_) {}
        yield '\n[Ollama Error: Status ${response.statusCode}${errDetail.isNotEmpty ? " - $errDetail" : ""}]';
        return;
      }

      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        while (buffer.contains('\n')) {
          final lineEnd = buffer.indexOf('\n');
          final line = buffer.substring(0, lineEnd).trim();
          buffer = buffer.substring(lineEnd + 1);

          if (line.isEmpty) continue;
          try {
            final jsonMap = json.decode(line) as Map<String, dynamic>;
            final message = jsonMap['message'] as Map<String, dynamic>?;
            if (message != null && message['content'] != null) {
              final content = message['content'].toString();
              if (content.isNotEmpty) {
                yield content;
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      yield '\n[Offline Chat Error: $e]';
    } finally {
      client.close();
    }
  }
}
