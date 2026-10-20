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

  PullProgress? getProgress(String modelId) => _activeDownloads[modelId];

  CatalogModel? getCatalogModel(String modelId) => _downloadingModels[modelId];

  /// Get primary active download summary text (e.g. for banners or badges)
  String? get primaryDownloadSummary {
    if (_activeDownloads.isEmpty) return null;
    final firstId = _activeDownloads.keys.first;
    final progress = _activeDownloads[firstId]!;
    final model = _downloadingModels[firstId];
    final name = model?.name ?? firstId;
    final pct = (progress.percent * 100).toInt();
    return '$name: $pct%';
  }

  /// Start pulling a model with resilient background streaming
  void startDownload({required String modelId, CatalogModel? catalogModel}) {
    if (_activeDownloads.containsKey(modelId)) return;

    if (catalogModel != null) {
      _downloadingModels[modelId] = catalogModel;
    }

    _activeDownloads[modelId] = PullProgress(
      status: 'Connecting to registry...',
      totalBytes: 0,
      completedBytes: 0,
      percent: 0.01,
    );
    notifyListeners();

    final subscription = OllamaService.pullModelStream(modelId).listen(
      (progress) {
        _activeDownloads[modelId] = progress;
        notifyListeners();

        if (progress.isCompleted) {
          _activeDownloads.remove(modelId);
          _subscriptions[modelId]?.cancel();
          _subscriptions.remove(modelId);
          _downloadingModels.remove(modelId);
          _completedController.add(modelId);
          notifyListeners();
        }
      },
      onError: (err) {
        _activeDownloads.remove(modelId);
        _subscriptions[modelId]?.cancel();
        _subscriptions.remove(modelId);
        _downloadingModels.remove(modelId);
        _errorController.add({'modelId': modelId, 'error': err.toString()});
        notifyListeners();
      },
      onDone: () {
        if (_activeDownloads.containsKey(modelId)) {
          _activeDownloads.remove(modelId);
          _subscriptions[modelId]?.cancel();
          _subscriptions.remove(modelId);
          _downloadingModels.remove(modelId);
          notifyListeners();
        }
      },
      cancelOnError: true,
    );

    _subscriptions[modelId] = subscription;
  }

  /// Safely abort an ongoing model download
  void cancelDownload(String modelId) {
    _subscriptions[modelId]?.cancel();
    _subscriptions.remove(modelId);
    _activeDownloads.remove(modelId);
    _downloadingModels.remove(modelId);
    notifyListeners();
  }
}

/// Global singleton instance
final modelDownloadManager = ModelDownloadManager.instance;
