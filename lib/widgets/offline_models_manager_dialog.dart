import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/ollama_service.dart';
import '../services/model_download_manager.dart';

/// Modern popup dialog for managing offline Ollama AI models.
/// Clean minimal design with category filtering, storage indicator, and download progress.
class OfflineModelsManagerDialog extends StatefulWidget {
  final String? selectedModelTag;
  final ValueChanged<String>? onModelSelected;
  final VoidCallback? onModelsChanged;
  final bool isBottomSheet;

  const OfflineModelsManagerDialog({
    super.key,
    this.selectedModelTag,
    this.onModelSelected,
    this.onModelsChanged,
    this.isBottomSheet = false,
  });

  /// Opens the dialog with a sleek pop-up scale and fade animation.
  static Future<void> show({
    required BuildContext context,
    String? selectedModelTag,
    ValueChanged<String>? onModelSelected,
    VoidCallback? onModelsChanged,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Models Manager',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, anim1, anim2) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: OfflineModelsManagerDialog(
          selectedModelTag: selectedModelTag,
          onModelSelected: onModelSelected,
          onModelsChanged: onModelsChanged,
        ),
      ),
    );
  }

  @override
  State<OfflineModelsManagerDialog> createState() => _OfflineModelsManagerDialogState();
}

class _OfflineModelsManagerDialogState extends State<OfflineModelsManagerDialog> {
  int _tabIndex = 0; // 0 = Catalog & Download, 1 = Installed on Disk
  String _selectedCategory = 'All';

  List<InstalledModel> _installedModels = [];
  List<CatalogModel> _catalogModels = [];
  bool _isLoading = true;
  String? _currentSelectedTag;

  @override
  void initState() {
    super.initState();
    _currentSelectedTag = widget.selectedModelTag;
    _loadData();
    modelDownloadManager.addListener(_onDownloadManagerUpdated);
  }

  @override
  void dispose() {
    modelDownloadManager.removeListener(_onDownloadManagerUpdated);
    super.dispose();
  }

  void _onDownloadManagerUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final installed = await OllamaService.getInstalledModels();
    final catalog = await OllamaService.getCatalog();
    if (!mounted) return;
    setState(() {
      _installedModels = installed;
      _catalogModels = catalog;
      _isLoading = false;
      if (_currentSelectedTag == null && _installedModels.isNotEmpty) {
        _currentSelectedTag = _installedModels.first.modelTag;
      }
    });
  }

  Future<void> _deleteModel(String modelId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 8),
            Text('Remove Model?', style: TextStyle(color: ctx.textPrimary, fontSize: 17)),
          ],
        ),
        content: Text(
          'Delete "$modelId" from local storage to free up disk space? You can re-download it anytime.',
          style: TextStyle(color: ctx.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ctx.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await OllamaService.deleteModel(modelId);
      if (success) {
        await _loadData();
        widget.onModelsChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Model "$modelId" removed from disk.'),
              backgroundColor: const Color(0xFF22C55E),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  List<CatalogModel> get _filteredCatalog {
    return _catalogModels.where((model) {
      if (_selectedCategory == 'Coding' && !model.routingTags.contains('coding')) return false;
      if (_selectedCategory == 'Reasoning' && !model.routingTags.contains('reasoning') && !model.routingTags.contains('math')) return false;
      if (_selectedCategory == 'General' && !model.routingTags.contains('general') && !model.routingTags.contains('chat')) return false;
      if (_selectedCategory == 'Low RAM' && model.minRamGb > 4) return false;
      return true;
    }).toList();
  }

  String get _totalDiskSpaceFormatted {
    final totalBytes = _installedModels.fold<int>(0, (sum, m) => sum + m.sizeBytes);
    if (totalBytes <= 0) return '0 GB';
    return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dialogHeight = (media.size.height * 0.82).clamp(480.0, 680.0);

    return Container(
      constraints: BoxConstraints(
        maxWidth: 720,
        maxHeight: dialogHeight,
      ),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 32,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Top Bar: Tabs Switcher + Close Button (replaces the old header row)
            _buildTopBar(context),

            // Content Area
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: context.textPrimary,
                      ),
                    )
                  : (_tabIndex == 0
                      ? _buildCatalogView(context)
                      : _buildInstalledView(context)),
            ),
          ],
        ),
      ),
    );
  }

  /// Clean top bar with tabs switcher and close button
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          // Segmented Tabs
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: context.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabPill(
                      index: 0,
                      title: 'Catalog (${_catalogModels.length})',
                      icon: Icons.cloud_download_rounded,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTabPill(
                      index: 1,
                      title: 'Installed',
                      icon: Icons.save_alt_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Close button
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: '',
            splashRadius: 18,
            color: context.textSecondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required int index,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _tabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (context.isDark ? const Color(0xFF383838) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? context.textPrimary : context.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? context.textPrimary : context.textSecondary,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Catalog View with Storage on the left, Category chips on the right, and no search bar
  Widget _buildCatalogView(BuildContext context) {
    final filtered = _filteredCatalog;

    return Column(
      children: [
        // Category Filters Row with Disk Storage on the Left (No icon, clean typography)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Row(
            children: [
              // Left side: Storage info without icon (updates automatically after download)
              Text(
                'Storage: $_totalDiskSpaceFormatted used',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Right side: Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip('All'),
                    _buildCategoryChip('Coding'),
                    _buildCategoryChip('Reasoning'),
                    _buildCategoryChip('General'),
                    _buildCategoryChip('Low RAM'),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, thickness: 1),

        // Models List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No models found',
                    style: TextStyle(color: context.textSecondary, fontSize: 13),
                  ),
                )
              : ListenableBuilder(
                  listenable: modelDownloadManager,
                  builder: (context, _) {
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => _buildCatalogCard(context, filtered[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedCategory = category),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
          decoration: BoxDecoration(
            color: isSelected
                ? (context.isDark ? Colors.white : Colors.black)
                : context.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.transparent : context.borderColor,
              width: 1,
            ),
          ),
          child: Text(
            category,
            style: TextStyle(
              color: isSelected
                  ? (context.isDark ? Colors.black : Colors.white)
                  : context.textSecondary,
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// Model Card in Catalog Tab (Neutral modern styling, no heavy green theme)
  Widget _buildCatalogCard(BuildContext context, CatalogModel item) {
    final isInstalled = _installedModels.any(
      (m) => m.modelTag == item.modelId || m.name.startsWith(item.modelId),
    );
    final isDownloading = modelDownloadManager.isDownloading(item.modelId);
    final isPaused = modelDownloadManager.isPaused(item.modelId);
    final downloadProgress = modelDownloadManager.getProgress(item.modelId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDownloading
              ? (context.isDark ? Colors.white70 : Colors.black87)
              : context.borderColor,
          width: isDownloading ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title & Specs, Action Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),

                    // Specs Badges Row without icons
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildSpecBadge(context, item.size),
                        _buildSpecBadge(context, item.parameters),
                        _buildSpecBadge(
                          context,
                          'Min ${item.minRamGb}GB RAM',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons on Right
              const SizedBox(width: 8),
              if (isInstalled)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, color: context.textPrimary, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Ready',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        widget.onModelSelected?.call(item.modelId);
                        Navigator.of(context).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'Use in Chat',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else if (isDownloading)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isPaused) ...[
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            isPaused
                                ? 'Paused'
                                : '${((downloadProgress?.percent ?? 0.01) * 100).toInt()}%',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => modelDownloadManager.togglePauseResume(item.modelId),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              isPaused ? 'Resume' : 'Pause',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => modelDownloadManager.cancelDownload(item.modelId),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    modelDownloadManager.startDownload(
                      modelId: item.modelId,
                      catalogModel: item,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.isDark ? Colors.white : const Color(0xFF171717),
                    foregroundColor: context.isDark ? Colors.black : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 15),
                  label: const Text(
                    'Download',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),

          // Real-Time Background Progress Box
          if (isDownloading && downloadProgress != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => modelDownloadManager.togglePauseResume(item.modelId),
                          borderRadius: BorderRadius.circular(4),
                          child: AnimatedDotsText(
                            isPaused: isPaused,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        downloadProgress.progressSummary,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(downloadProgress.percent * 100).toInt()}%',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: isPaused
                          ? downloadProgress.percent
                          : (downloadProgress.isIndeterminate ? null : downloadProgress.percent),
                      minHeight: 4,
                      backgroundColor: context.surface2,
                      color: isPaused
                          ? context.textSecondary.withValues(alpha: 0.5)
                          : (context.isDark ? Colors.white : Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecBadge(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: context.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  /// Installed on Disk Tab
  Widget _buildInstalledView(BuildContext context) {
    if (_installedModels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: context.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No models installed on local disk',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Switch to the "Catalog" tab to install your first offline AI model.',
              style: TextStyle(color: context.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => _tabIndex = 0),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.isDark ? Colors.white : Colors.black,
                foregroundColor: context.isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 15),
              label: const Text('Browse Catalog'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      itemCount: _installedModels.length,
      itemBuilder: (context, i) {
        final m = _installedModels[i];
        final isSelected = m.modelTag == _currentSelectedTag;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? (context.isDark ? Colors.white70 : Colors.black87) : context.borderColor,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getModelDisplayName(m),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Text(
                              'Active in Chat',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Disk Size: ${m.sizeFormatted} • Model Tag: ${m.modelTag}',
                      style: TextStyle(color: context.textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),

              // Actions
              if (isSelected)
                OutlinedButton.icon(
                  onPressed: () {
                    widget.onModelSelected?.call(m.modelTag);
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textPrimary,
                    side: BorderSide(color: context.borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  label: const Text('Chat Now', style: TextStyle(fontSize: 11.5)),
                )
              else
                ElevatedButton(
                  onPressed: () {
                    setState(() => _currentSelectedTag = m.modelTag);
                    widget.onModelSelected?.call(m.modelTag);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.surface,
                    foregroundColor: context.textPrimary,
                    elevation: 0,
                    side: BorderSide(color: context.borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Activate', style: TextStyle(fontSize: 11.5)),
                ),

              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 19),
                tooltip: '',
                splashRadius: 18,
                onPressed: () => _deleteModel(m.modelTag),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getModelDisplayName(InstalledModel m) {
    final tagLower = m.modelTag.toLowerCase().trim();
    // 1. Check exact match in catalog
    for (final c in _catalogModels) {
      if (c.modelId.toLowerCase() == tagLower) {
        return c.name;
      }
    }
    // 2. Check base tag match in catalog (e.g. before colon)
    final baseTag = tagLower.split(':').first;
    for (final c in _catalogModels) {
      if (c.modelId.toLowerCase().split(':').first == baseTag) {
        return c.name;
      }
    }
    // 3. Fallback to friendly formatted name
    return _formatOfflineModelName(m.name);
  }

  String _formatOfflineModelName(String? raw) {
    if (raw == null || raw.isEmpty) return 'Offline AI';
    String clean = raw.trim();
    if (clean.toLowerCase().startsWith('local:')) {
      clean = clean.substring(6).trim();
    }
    final lower = clean.toLowerCase();
    if (lower.startsWith('deepseek-r1') || lower.startsWith('deepseek -r1')) {
      return 'DeepSeek-R1';
    } else if (lower.startsWith('deepseek-coder')) {
      return 'DeepSeek-Coder';
    } else if (lower.startsWith('deepseek')) {
      return 'DeepSeek';
    } else if (lower.startsWith('llama3.2') || lower.startsWith('llama-3.2') || lower.startsWith('llama 3.2')) {
      return 'Llama 3.2';
    } else if (lower.startsWith('llama3.1') || lower.startsWith('llama-3.1') || lower.startsWith('llama 3.1')) {
      return 'Llama 3.1';
    } else if (lower.startsWith('llama3') || lower.startsWith('llama-3')) {
      return 'Llama 3';
    } else if (lower.startsWith('llama2') || lower.startsWith('llama-2')) {
      return 'Llama 2';
    } else if (lower.startsWith('qwen2.5-coder')) {
      return 'Qwen 2.5 Coder';
    } else if (lower.startsWith('qwen2.5') || lower.startsWith('qwen-2.5')) {
      return 'Qwen 2.5';
    } else if (lower.startsWith('qwen')) {
      return 'Qwen';
    } else if (lower.startsWith('mistral')) {
      return 'Mistral';
    } else if (lower.startsWith('phi3') || lower.startsWith('phi-3')) {
      return 'Phi-3';
    } else if (lower.startsWith('gemma2') || lower.startsWith('gemma-2')) {
      return 'Gemma 2';
    } else if (lower.startsWith('gemma')) {
      return 'Gemma';
    } else if (lower.startsWith('moondream')) {
      return 'Moondream';
    } else if (lower.startsWith('llava')) {
      return 'LLaVA';
    } else if (lower.startsWith('tinyllama')) {
      return 'TinyLlama';
    }

    if (clean.contains(':')) {
      clean = clean.split(':').first;
    }
    return clean.split(RegExp(r'[-_ ]')).map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}

/// Animated 'Downloading...' / 'Paused...' text with cycling dots (1 -> 2 -> 3 -> 1)
class AnimatedDotsText extends StatefulWidget {
  final bool isPaused;
  final TextStyle? style;

  const AnimatedDotsText({
    super.key,
    required this.isPaused,
    this.style,
  });

  @override
  State<AnimatedDotsText> createState() => _AnimatedDotsTextState();
}

class _AnimatedDotsTextState extends State<AnimatedDotsText> {
  int _dotCount = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount % 3) + 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    final baseText = widget.isPaused ? 'Paused' : 'Downloading';
    return Text(
      '$baseText$dots',
      style: widget.style,
    );
  }
}
