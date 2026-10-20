import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../services/ollama_service.dart';
import '../services/model_download_manager.dart';

/// Modern, responsive dialog for managing offline Ollama AI models.
/// Supports search, category filters, real-time background download progress,
/// activation, and storage management.
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

  /// Opens the dialog responsively (centered Dialog on Desktop/Tablet, ModalBottomSheet on Mobile).
  static Future<void> show({
    required BuildContext context,
    String? selectedModelTag,
    ValueChanged<String>? onModelSelected,
    VoidCallback? onModelsChanged,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 640;
    if (isDesktop) {
      return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: OfflineModelsManagerDialog(
            selectedModelTag: selectedModelTag,
            onModelSelected: onModelSelected,
            onModelsChanged: onModelsChanged,
          ),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => OfflineModelsManagerDialog(
          selectedModelTag: selectedModelTag,
          onModelSelected: onModelSelected,
          onModelsChanged: onModelsChanged,
          isBottomSheet: true,
        ),
      );
    }
  }

  @override
  State<OfflineModelsManagerDialog> createState() => _OfflineModelsManagerDialogState();
}

class _OfflineModelsManagerDialogState extends State<OfflineModelsManagerDialog> {
  int _tabIndex = 0; // 0 = Catalog & Download, 1 = Installed on Disk
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final TextEditingController _searchController = TextEditingController();

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
    _searchController.dispose();
    super.dispose();
  }

  void _onDownloadManagerUpdated() {
    // Re-check installed models if download finished
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
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  List<CatalogModel> get _filteredCatalog {
    return _catalogModels.where((model) {
      // Category filter
      if (_selectedCategory == 'Coding' && !model.routingTags.contains('coding')) return false;
      if (_selectedCategory == 'Reasoning' && !model.routingTags.contains('reasoning') && !model.routingTags.contains('math')) return false;
      if (_selectedCategory == 'General' && !model.routingTags.contains('general') && !model.routingTags.contains('chat')) return false;
      if (_selectedCategory == 'Low RAM' && model.minRamGb > 4) return false;

      // Text query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = model.name.toLowerCase().contains(q);
        final matchId = model.modelId.toLowerCase().contains(q);
        final matchDesc = model.description.toLowerCase().contains(q);
        final matchTags = model.routingTags.any((t) => t.toLowerCase().contains(q));
        if (!matchName && !matchId && !matchDesc && !matchTags) return false;
      }
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
    final isDesktop = media.size.width >= 640;
    final dialogHeight = isDesktop
        ? (media.size.height * 0.85).clamp(560.0, 780.0)
        : media.size.height * 0.88;

    return Container(
      constraints: BoxConstraints(
        maxWidth: 780,
        maxHeight: dialogHeight,
      ),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: widget.isBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(20),
        border: Border.all(
          color: context.borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 36,
            spreadRadius: 6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: widget.isBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(20),
        child: Column(
          children: [
            // Mobile pull handle
            if (widget.isBottomSheet)
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

            // Top Header Bar
            _buildHeader(context),

            // Storage & Local Engine Summary Bar
            _buildEngineSummaryStrip(context),

            // Segmented Tab Bar Switcher
            _buildSegmentedTabBar(context),

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.purple),
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

  /// Modern header with title, subtitle, active downloads indicator, and close button
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.purple.withValues(alpha: 0.22),
                  AppColors.purpleDark.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.purple.withValues(alpha: 0.35)),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: AppColors.purple,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Offline Models Manager',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.purple.withValues(alpha: 0.25)),
                      ),
                      child: const Text(
                        'Ollama Engine',
                        style: TextStyle(
                          color: AppColors.purple,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Run open-weights AI models 100% offline & private on your device',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Active background download badge
          ListenableBuilder(
            listenable: modelDownloadManager,
            builder: (context, _) {
              if (!modelDownloadManager.hasActiveDownloads) return const SizedBox.shrink();
              final count = modelDownloadManager.activeCount;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.purple.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.purple,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$count Downloading',
                      style: const TextStyle(
                        color: AppColors.purple,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Close',
            splashRadius: 18,
            color: context.textSecondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Summary strip showing disk usage and persistent background download indicator
  Widget _buildEngineSummaryStrip(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.surface2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.storage_rounded, size: 14, color: context.textSecondary),
          const SizedBox(width: 6),
          Text(
            'Disk Storage: ',
            style: TextStyle(color: context.textSecondary, fontSize: 11.5),
          ),
          Text(
            '$_totalDiskSpaceFormatted used (${_installedModels.length} models)',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const Icon(Icons.all_inclusive_rounded, size: 14, color: AppColors.purple),
          const SizedBox(width: 5),
          const Text(
            'Downloads continue in background when navigating',
            style: TextStyle(
              color: AppColors.purple,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Segmented pill tabs with badges
  Widget _buildSegmentedTabBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Container(
        height: 40,
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
                title: 'Catalog & Download (${_catalogModels.length})',
                icon: Icons.cloud_download_rounded,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildTabPill(
                index: 1,
                title: 'Installed on Disk (${_installedModels.length})',
                icon: Icons.save_alt_rounded,
              ),
            ),
          ],
        ),
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
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (context.isDark ? const Color(0xFF2B2B2B) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
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
              color: isSelected ? AppColors.purple : context.textSecondary,
            ),
            const SizedBox(width: 7),
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

  /// Available Catalog Tab with search, category chips, and modern model cards
  Widget _buildCatalogView(BuildContext context) {
    final filtered = _filteredCatalog;

    return Column(
      children: [
        // Search & Category Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Column(
            children: [
              // Search input
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: context.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.borderColor),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: context.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search models (e.g. Llama, Coding, 4GB RAM)...',
                    hintStyle: TextStyle(color: context.textSecondary, fontSize: 12.5),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: context.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(height: 8),

              // Filter Chips
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

        const Divider(height: 16, thickness: 1),

        // Models List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 40, color: context.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text(
                        'No matching models found',
                        style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try clearing the search query or selecting "All".',
                        style: TextStyle(color: context.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListenableBuilder(
                  listenable: modelDownloadManager,
                  builder: (context, _) {
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedCategory = category),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.purple.withValues(alpha: 0.18)
                : context.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.purple : context.borderColor,
              width: 1,
            ),
          ),
          child: Text(
            category,
            style: TextStyle(
              color: isSelected ? AppColors.purple : context.textSecondary,
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// Model Card in Catalog Tab
  Widget _buildCatalogCard(BuildContext context, CatalogModel item) {
    final isInstalled = _installedModels.any(
      (m) => m.modelTag == item.modelId || m.name.startsWith(item.modelId),
    );
    final isDownloading = modelDownloadManager.isDownloading(item.modelId);
    final downloadProgress = modelDownloadManager.getProgress(item.modelId);

    // Accent tier color
    Color tierColor = AppColors.purple;
    IconData tierIcon = Icons.bolt_rounded;
    if (item.tier == 'balanced') {
      tierColor = AppColors.geminiBlue;
      tierIcon = Icons.auto_awesome_rounded;
    } else if (item.tier == 'pro') {
      tierColor = const Color(0xFF8B5CF6);
      tierIcon = Icons.psychology_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDownloading
              ? AppColors.purple.withValues(alpha: 0.6)
              : (isInstalled
                  ? AppColors.success.withValues(alpha: 0.4)
                  : context.borderColor),
          width: isDownloading || isInstalled ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon, Title & Specs, Action Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tierColor.withValues(alpha: 0.25)),
                ),
                child: Icon(tierIcon, color: tierColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Copyable tag pill
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: item.modelId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied "${item.modelId}" to clipboard'),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: context.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.modelId,
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(Icons.copy_rounded, size: 9, color: context.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Specs Badges Row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildSpecBadge(context, Icons.storage_rounded, item.size),
                        _buildSpecBadge(context, Icons.memory_rounded, item.parameters),
                        _buildSpecBadge(
                          context,
                          Icons.speed_rounded,
                          'Min ${item.minRamGb}GB RAM',
                          isHighlight: item.minRamGb <= 4,
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
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Ready',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
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
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'Use in Chat',
                          style: TextStyle(
                            color: AppColors.purple,
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
                        color: AppColors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.purple.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.purple,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${((downloadProgress?.percent ?? 0.01) * 100).toInt()}%',
                            style: const TextStyle(
                              color: AppColors.purple,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
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
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text(
                    'Download',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            item.description,
            style: TextStyle(color: context.textSecondary, fontSize: 12.5, height: 1.35),
          ),

          // Routing tags
          if (item.routingTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: item.routingTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(color: context.textSecondary, fontSize: 10.5),
                  ),
                );
              }).toList(),
            ),
          ],

          // Real-Time Background Progress Box
          if (isDownloading && downloadProgress != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sync_rounded, size: 13, color: AppColors.purple),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          downloadProgress.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.purple,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
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
                        style: const TextStyle(
                          color: AppColors.purple,
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
                      value: downloadProgress.isIndeterminate ? null : downloadProgress.percent,
                      minHeight: 5,
                      backgroundColor: context.surface2,
                      color: AppColors.purple,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 11, color: context.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Downloading in background. You can close this dialog or switch chats.',
                        style: TextStyle(color: context.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecBadge(BuildContext context, IconData icon, String text, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppColors.success.withValues(alpha: 0.12)
            : context.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlight
              ? AppColors.success.withValues(alpha: 0.3)
              : context.borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isHighlight ? AppColors.success : context.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: isHighlight ? AppColors.success : context.textSecondary,
              fontSize: 10.5,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
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
              'Switch to the "Catalog & Download" tab to install your first offline AI model.',
              style: TextStyle(color: context.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => _tabIndex = 0),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
              color: isSelected ? AppColors.purple : context.borderColor,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.purple.withValues(alpha: 0.15)
                      : context.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.memory_rounded,
                  color: isSelected ? AppColors.purple : context.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          m.name,
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
                              color: AppColors.purple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Active in Chat',
                              style: TextStyle(
                                color: AppColors.purple,
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
                    foregroundColor: AppColors.purple,
                    side: const BorderSide(color: AppColors.purple),
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
                tooltip: 'Delete from local disk',
                splashRadius: 18,
                onPressed: () => _deleteModel(m.modelTag),
              ),
            ],
          ),
        );
      },
    );
  }
}
