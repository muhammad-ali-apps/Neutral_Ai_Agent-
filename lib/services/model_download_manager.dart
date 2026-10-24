import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ollama_service.dart';

/// Global manager for handling offline model downloads.
/// Operates as a persistent application-level singleton so that switching
/// modules, closing modals, or navigating across tabs NEVER interrupts
/// or halts ongoing background downloads.
class ModelDownloadManager extends ChangeNotifier {
  static final ModelDownloadManager instance = ModelDownloadManager._internal();
  ModelDownloadManager._internal();

  // Active downloads mapping: modelId -> PullProgress
  final Map<String, PullProgress> _activeDownloads = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, CatalogModel> _downloadingModels = {};

  final Set<String> _pausedModelIds = {};

  // Event streams for notifications
  final _completedController = StreamController<String>.broadcast();
  Stream<String> get onModelCompleted => _completedController.stream;

  final _errorController = StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get onModelError => _errorController.stream;

  Map<String, PullProgress> get activeDownloads => Map.unmodifiable(_activeDownloads);
  int get activeCount => _activeDownloads.length;
  bool get hasActiveDownloads => _activeDownloads.isNotEmpty;
  List<String> get downloadingModelIds => _activeDownloads.keys.toList();

  bool isDownloading(String modelId) => _activeDownloads.containsKey(modelId);
  bool isPaused(String modelId) => _pausedModelIds.contains(modelId);

  PullProgress? getProgress(String modelId) => _activeDownloads[modelId];

  CatalogModel? getCatalogModel(String modelId) => _downloadingModels[modelId];

  /// Get primary active download summary text (e.g. for banners or badges)
  String? get primaryDownloadSummary {
    if (_activeDownloads.isEmpty) return null;
    final firstId = _activeDownloads.keys.first;
    final progress = _activeDownloads[firstId]!;
    final model = _downloadingModels[firstId];
    final name = model?.name ?? firstId;
    if (_pausedModelIds.contains(firstId)) {
      return '$name: Paused';
    }
    final pct = (progress.percent * 100).toInt();
    return '$name: $pct%';
  }

  void _attachSubscription(String modelId) {
    _subscriptions[modelId]?.cancel();
    final subscription = OllamaService.pullModelStream(modelId).listen(
      (progress) {
        // Protect against temporary 0.0 or lower values during manifest verification on resume
        final prev = _activeDownloads[modelId];
        if (prev != null && progress.percent < prev.percent && !progress.isCompleted) {
          _activeDownloads[modelId] = PullProgress(
            status: progress.status,
            totalBytes: progress.totalBytes > 0 ? progress.totalBytes : prev.totalBytes,
            completedBytes: progress.completedBytes > 0 ? progress.completedBytes : prev.completedBytes,
            percent: prev.percent,
            isCompleted: progress.isCompleted,
            error: progress.error,
          );
        } else {
          _activeDownloads[modelId] = progress;
        }
        notifyListeners();

        if (progress.isCompleted) {
          _activeDownloads.remove(modelId);
          _subscriptions[modelId]?.cancel();
          _subscriptions.remove(modelId);
          _downloadingModels.remove(modelId);
          _pausedModelIds.remove(modelId);
          _completedController.add(modelId);
          notifyListeners();
        }
      },
      onError: (err) {
        if (_pausedModelIds.contains(modelId)) {
          // Stream aborted intentionally for pause; ignore
          return;
        }
        _activeDownloads.remove(modelId);
        _subscriptions[modelId]?.cancel();
        _subscriptions.remove(modelId);
        _downloadingModels.remove(modelId);
        _pausedModelIds.remove(modelId);
        _errorController.add({'modelId': modelId, 'error': err.toString()});
        notifyListeners();
      },
      onDone: () {
        if (_pausedModelIds.contains(modelId)) {
          // Stream completed/closed due to pause; keep state
          return;
        }
        if (_activeDownloads.containsKey(modelId)) {
          _activeDownloads.remove(modelId);
          _subscriptions[modelId]?.cancel();
          _subscriptions.remove(modelId);
          _downloadingModels.remove(modelId);
          _pausedModelIds.remove(modelId);
          notifyListeners();
        }
      },
      cancelOnError: true,
    );

    _subscriptions[modelId] = subscription;
  }

  /// Start pulling a model with resilient background streaming
  void startDownload({required String modelId, CatalogModel? catalogModel}) {
    if (_activeDownloads.containsKey(modelId) && !_pausedModelIds.contains(modelId)) return;

    _pausedModelIds.remove(modelId);

    if (catalogModel != null) {
      _downloadingModels[modelId] = catalogModel;
    }

    if (!_activeDownloads.containsKey(modelId)) {
      _activeDownloads[modelId] = PullProgress(
        status: 'Connecting to registry...',
        totalBytes: 0,
        completedBytes: 0,
        percent: 0.01,
      );
    }
    notifyListeners();

    _attachSubscription(modelId);
  }

  /// Pause an ongoing model download by closing connection so Ollama halts network downloading
  void pauseDownload(String modelId) {
    if (!_activeDownloads.containsKey(modelId)) return;
    _pausedModelIds.add(modelId);

    // Forcefully cancel subscription to close HTTP stream, stopping Ollama background pull
    _subscriptions[modelId]?.cancel();
    _subscriptions.remove(modelId);

    notifyListeners();
  }

  /// Resume a paused model download from where it left off
  void resumeDownload(String modelId) {
    if (!_activeDownloads.containsKey(modelId)) return;
    _pausedModelIds.remove(modelId);

    // Re-connect stream; Ollama automatically resumes from cached layer blobs
    _attachSubscription(modelId);
    notifyListeners();
  }

  /// Toggle pause and resume
  void togglePauseResume(String modelId) {
    if (isPaused(modelId)) {
      resumeDownload(modelId);
    } else {
      pauseDownload(modelId);
    }
  }

  /// Safely abort an ongoing model download
  void cancelDownload(String modelId) {
    _subscriptions[modelId]?.cancel();
    _subscriptions.remove(modelId);
    _activeDownloads.remove(modelId);
    _downloadingModels.remove(modelId);
    _pausedModelIds.remove(modelId);
    notifyListeners();
  }
}

/// Global singleton instance
final modelDownloadManager = ModelDownloadManager.instance;
