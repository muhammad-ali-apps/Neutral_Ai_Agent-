import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models.dart';
import '../widgets/moving_red_border_painter.dart';

/// Admin panel for managing LLM models with a modern, responsive layout,
/// animated laser borders for active models, and clean animated-line inputs.
class AdminPanelScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  const AdminPanelScreen({super.key, this.onMenuTap});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  @override
  void initState() {
    super.initState();
    // Load models from API on first open
    if (modelStore.models.isEmpty && !modelStore.isLoading) {
      modelStore.loadFromApi();
    }
  }

  void _openModelPanel({LlmModel? existingModel}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedAnim = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curvedAnim),
            child: _AddModelPanel(existingModel: existingModel),
          ),
        );
      },
    );
  }

  Future<void> _toggleModel(LlmModel model) async {
    final success = await modelStore.toggleActiveViaApi(model.id);
    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Failed to toggle model status'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  void _confirmDelete(LlmModel model) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Model',
                style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: TextStyle(color: context.textSecondary, fontSize: 13.5, height: 1.5),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: model.name,
                style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600),
              ),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.textPrimary,
                      side: BorderSide(color: context.borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final success = await modelStore.deleteViaApi(model.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(success ? '${model.name} deleted' : 'Failed to delete model'),
                          backgroundColor: success ? AppColors.success : Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Delete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: modelStore,
      builder: (context, _) {
        final models = modelStore.models;
        final active = models.where((m) => m.active).length;
        final providers = models.map((m) => m.provider).toSet().length;

        return Scaffold(
          backgroundColor: context.bg,
          body: Column(
            children: [
              // ── Modern Responsive Top Bar (Matching Smart Routing & Offline) ──
              _buildTopBar(context, active, models.length),

              // ── Main Dashboard Body ──
              Expanded(
                child: modelStore.isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFEF4444)),
                            SizedBox(height: 16),
                            Text(
                              'Loading models...',
                              style: TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : modelStore.errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_off_rounded, color: context.textSecondary, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  modelStore.errorMessage!,
                                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => modelStore.loadFromApi(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Responsive Quantity / Metric Cards ──
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final width = constraints.maxWidth;
                                    final statCards = [
                                      _StatCard(
                                        value: '${models.length}',
                                        label: 'Total Models',
                                        icon: Icons.layers_outlined,
                                        accentColor: context.textPrimary,
                                      ),
                                      _StatCard(
                                        value: '$active',
                                        label: 'Active Models',
                                        icon: Icons.bolt_rounded,
                                        accentColor: const Color(0xFF10A37F),
                                        isPulsing: true,
                                      ),
                                      _StatCard(
                                        value: '$providers',
                                        label: 'Providers',
                                        icon: Icons.hub_outlined,
                                        accentColor: const Color(0xFFEF4444),
                                      ),
                                    ];

                                    if (width < 550) {
                                      // Mobile layout
                                      return Row(
                                        children: statCards
                                            .map((s) => Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                                    child: s,
                                                  ),
                                                ))
                                            .toList(),
                                      );
                                    }

                                    return Row(
                                      children: statCards
                                          .map((s) => Expanded(
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                                  child: s,
                                                ),
                                              ))
                                          .toList(),
                                    );
                                  },
                                ),

                                const SizedBox(height: 24),

                                // ── Section Header ──
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'CONFIGURED MODELS',
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      '${models.length} Total',
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // ── Empty State or Equal-Sized Model Cards ──
                                if (models.isEmpty)
                                  _EmptyState(onAdd: () => _openModelPanel())
                                else
                                  Column(
                                    children: models.map((m) {
                                      return _ModelCard(
                                        model: m,
                                        onToggle: () => _toggleModel(m),
                                        onDelete: () => _confirmDelete(m),
                                        onEdit: () => _openModelPanel(existingModel: m),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Appbar matching Smart Routing & Offline screens:
  /// - Removed + sign
  /// - Removed green container
  /// - Clean animated line / border interactive Add Model button
  Widget _buildTopBar(BuildContext context, int active, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.bg,
        border: Border(bottom: BorderSide(color: context.borderColor, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (widget.onMenuTap != null)
              IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: widget.onMenuTap,
                color: context.textPrimary,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune_rounded, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10A37F),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$active Models Active · $total Total',
                      style: TextStyle(color: context.textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),

            // Add Model button in Appbar (No '+' icon, No green container)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openModelPanel(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Add Model',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Responsive Modern Stat Card
// ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color accentColor;
  final bool isPulsing;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.accentColor,
    this.isPulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: accentColor, size: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (isPulsing) ...[
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10A37F),
                  ),
                ),
              ],
              Text(
                value,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Equal-Sized Model Card with Animated Laser Line on Active
// ─────────────────────────────────────────────────────────────

class _ModelCard extends StatefulWidget {
  final LlmModel model;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ModelCard({
    required this.model,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_ModelCard> createState() => _ModelCardState();
}

class _ModelCardState extends State<_ModelCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _laserCtrl;

  @override
  void initState() {
    super.initState();
    _laserCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.model.active) {
      _laserCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ModelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model.active != oldWidget.model.active) {
      if (widget.model.active) {
        _laserCtrl.repeat();
      } else {
        _laserCtrl.stop();
        _laserCtrl.reset();
      }
    }
  }

  @override
  void dispose() {
    _laserCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final isDark = context.isDark;
    final providerDisplay = LlmProvider.fromString(model.provider).displayName;

    return Container(
      // STRICT UNIFORM EQUAL HEIGHT AND WIDTH FOR ALL MODEL CARDS
      height: 118,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: AnimatedBuilder(
        animation: _laserCtrl,
        builder: (context, child) {
          return CustomPaint(
            painter: model.active
                ? MovingRedBorderPainter(
                    progress: _laserCtrl.value,
                    borderRadius: 12,
                    isDark: isDark,
                  )
                : null,
            child: Container(
              decoration: BoxDecoration(
                color: context.surface2,
                borderRadius: BorderRadius.circular(12),
                border: model.active
                    ? null
                    : Border.all(color: context.borderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: child,
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Avatar + Name + Status + Router + Action buttons
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: model.color,
                  child: Text(
                    model.badgeLetter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          model.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Active/Inactive badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (model.active
                                  ? const Color(0xFF10A37F)
                                  : context.textSecondary)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: model.active
                                    ? const Color(0xFF10A37F)
                                    : context.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              model.active ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: model.active
                                    ? const Color(0xFF10A37F)
                                    : context.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (model.isRouter) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Router',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Actions
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: model.active,
                    onChanged: (_) => widget.onToggle(),
                    activeThumbColor: const Color(0xFFEF4444),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                IconButton(
                  onPressed: widget.onEdit,
                  iconSize: 16,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(Icons.edit_outlined, color: context.textSecondary),
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  iconSize: 16,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  tooltip: 'Delete',
                ),
              ],
            ),

            // Middle Row: Provider · Model code
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Text(
                '$providerDisplay · ${model.modelCode}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ),

            // Bottom Row: Tags (Horizontal list with fixed height so height never varies)
            SizedBox(
              height: 22,
              child: Padding(
                padding: const EdgeInsets.only(left: 38),
                child: model.tags.isEmpty
                    ? Text(
                        'No routing tags',
                        style: TextStyle(
                          color: context.textSecondary.withValues(alpha: 0.5),
                          fontSize: 10.5,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: model.tags.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, i) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                width: 0.8,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              model.tags[i],
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.hub_outlined, color: context.textSecondary, size: 48),
          const SizedBox(height: 12),
          Text(
            'No models configured yet',
            style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your first LLM to get started',
            style: TextStyle(color: context.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 180,
            child: _AnimatedLineButton(
              text: 'Add Model',
              onPressed: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Add / Edit LLM Slide-In Panel
// ─────────────────────────────────────────────────────────────

class _ProviderOption {
  final String name;        // UI display name
  final String backendKey;  // backend enum value
  final String subtitle;
  final String letter;
  final Color color;

  const _ProviderOption({
    required this.name,
    required this.backendKey,
    this.subtitle = '',
    required this.letter,
    required this.color,
  });
}

// Clean providers list without the subtitle model names on top
const _providers = <_ProviderOption>[
  _ProviderOption(name: 'OpenAI', backendKey: 'openai', subtitle: '', letter: 'O', color: AppColors.openaiGreen),
  _ProviderOption(name: 'Google Gemini', backendKey: 'gemini', subtitle: '', letter: 'G', color: AppColors.geminiBlue),
  _ProviderOption(name: 'Anthropic Claude', backendKey: 'anthropic', subtitle: '', letter: 'A', color: AppColors.anthropicOrange),
  _ProviderOption(name: 'Ollama (Local)', backendKey: 'ollama', subtitle: '', letter: 'O', color: AppColors.deepseekGray),
  _ProviderOption(name: 'Custom API', backendKey: 'custom', subtitle: '', letter: 'C', color: AppColors.purple),
];

const _allRoutingTags = ['coding', 'reasoning', 'creative', 'general', 'math', 'science'];

class _AddModelPanel extends StatefulWidget {
  final LlmModel? existingModel;
  const _AddModelPanel({this.existingModel});

  bool get isEditMode => existingModel != null;

  @override
  State<_AddModelPanel> createState() => _AddModelPanelState();
}

class _AddModelPanelState extends State<_AddModelPanel> {
  int _selectedProvider = 0;
  bool _isActive = true;
  bool _isRouter = false;
  bool _obscureKey = true;
  bool _isSubmitting = false;
  final Set<String> _selectedTags = {'coding', 'reasoning', 'creative', 'general'};

  String? _displayNameError;
  String? _modelIdError;
  String? _routingTagsError;
  String? _temperatureError;
  String? _maxTokensError;

  final _displayNameCtrl = TextEditingController();
  final _modelIdCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _endpointCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _temperatureCtrl = TextEditingController();
  final _maxTokensCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _displayNameCtrl.addListener(() {
      if (_displayNameError != null) setState(() => _displayNameError = null);
    });
    _modelIdCtrl.addListener(() {
      if (_modelIdError != null) setState(() => _modelIdError = null);
    });
    _temperatureCtrl.addListener(() {
      if (_temperatureError != null) setState(() => _temperatureError = null);
    });
    _maxTokensCtrl.addListener(() {
      if (_maxTokensError != null) setState(() => _maxTokensError = null);
    });

    final m = widget.existingModel;
    if (m != null) {
      _displayNameCtrl.text = m.name;
      _modelIdCtrl.text = m.modelCode;
      _isActive = m.active;
      _isRouter = m.isRouter;
      if (m.temperature != null) {
        _temperatureCtrl.text = m.temperature.toString();
      }
      if (m.maxTokens != null) {
        _maxTokensCtrl.text = m.maxTokens.toString();
      }
      _endpointCtrl.text = m.endpointUrl ?? '';
      _descriptionCtrl.text = m.description ?? '';
      _selectedTags
        ..clear()
        ..addAll(m.tags);
      final idx = _providers.indexWhere((p) => p.backendKey == m.provider);
      if (idx >= 0) _selectedProvider = idx;
    }
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _modelIdCtrl.dispose();
    _apiKeyCtrl.dispose();
    _endpointCtrl.dispose();
    _descriptionCtrl.dispose();
    _temperatureCtrl.dispose();
    _maxTokensCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitModel() async {
    final provider = _providers[_selectedProvider];
    final name = _displayNameCtrl.text.trim();
    final modelId = _modelIdCtrl.text.trim();

    String? nameErr;
    String? idErr;
    String? tagsErr;
    String? tempErr;
    String? maxTokensErr;

    if (name.isEmpty) {
      nameErr = 'Display name is required';
    }
    if (modelId.isEmpty) {
      idErr = 'Model ID is required';
    }
    if (!_isRouter && _selectedTags.isEmpty) {
      tagsErr = 'Please select at least one routing tag';
    }

    final tempStr = _temperatureCtrl.text.trim();
    if (tempStr.isNotEmpty && double.tryParse(tempStr) == null) {
      tempErr = 'Enter a valid decimal number (e.g. 0.7)';
    }

    final maxTokensStr = _maxTokensCtrl.text.trim();
    if (maxTokensStr.isNotEmpty && int.tryParse(maxTokensStr) == null) {
      maxTokensErr = 'Enter a valid integer (e.g. 2048)';
    }

    setState(() {
      _displayNameError = nameErr;
      _modelIdError = idErr;
      _routingTagsError = tagsErr;
      _temperatureError = tempErr;
      _maxTokensError = maxTokensErr;
    });

    if (nameErr != null || idErr != null || tagsErr != null || tempErr != null || maxTokensErr != null) {
      return;
    }

    setState(() => _isSubmitting = true);

    final data = <String, dynamic>{
      'name': name,
      'provider': provider.backendKey,
      'model_id': modelId,
      'routing_tags': _isRouter ? [] : _selectedTags.toList(),
      'is_active': _isActive,
      'is_router': _isRouter,
    };

    if (tempStr.isNotEmpty) {
      final parsedTemp = double.tryParse(tempStr);
      if (parsedTemp != null) {
        data['temperature'] = parsedTemp;
      }
    }

    if (maxTokensStr.isNotEmpty) {
      final parsedTokens = int.tryParse(maxTokensStr);
      if (parsedTokens != null) {
        data['max_tokens'] = parsedTokens;
      }
    }

    final apiKey = _apiKeyCtrl.text.trim();
    if (apiKey.isNotEmpty) data['api_key'] = apiKey;

    final endpoint = _endpointCtrl.text.trim();
    if (endpoint.isNotEmpty) data['endpoint_url'] = endpoint;

    final description = _descriptionCtrl.text.trim();
    if (description.isNotEmpty) data['description'] = description;

    bool success;
    if (widget.isEditMode) {
      success = await modelStore.updateViaApi(widget.existingModel!.id, data);
    } else {
      success = await modelStore.addViaApi(data);
    }

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isEditMode ? 'Model updated successfully' : 'Model added successfully'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    } else {
      _showError(widget.isEditMode ? 'Failed to update model' : 'Failed to add model');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Completely responsive panel: full width on mobile (<500px), 420px on desktop
    final panelWidth = screenWidth < 500 ? screenWidth : math.min(440.0, screenWidth * 0.9);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: panelWidth,
        height: double.infinity,
        decoration: BoxDecoration(
          color: context.surface,
          border: Border(
            left: BorderSide(color: context.borderColor, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 28,
              offset: const Offset(-6, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header (Title changed from "Add LLM Integration" to "Add LLM") ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.borderColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isEditMode ? 'Edit LLM' : 'Add LLM',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: context.textSecondary, size: 20),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // ── Scrollable Form Body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Provider Selector (Clean dropdown without the top model list) ──
                    _sectionLabel('PROVIDER'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedProvider,
                          isExpanded: true,
                          dropdownColor: context.surface,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.textSecondary),
                          items: List.generate(_providers.length, (i) {
                            final p = _providers[i];
                            return DropdownMenuItem<int>(
                              value: i,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 11,
                                    backgroundColor: p.color,
                                    child: Text(
                                      p.letter,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    p.name,
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedProvider = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Display Name with Animated Line ──
                    _sectionLabel('DISPLAY NAME *'),
                    const SizedBox(height: 4),
                    _AnimatedLineTextField(
                      controller: _displayNameCtrl,
                      hint: 'e.g. GPT-4 Turbo, Claude 3',
                      errorText: _displayNameError,
                    ),

                    const SizedBox(height: 20),

                    // ── Model ID with Animated Line ──
                    _sectionLabel('MODEL ID *'),
                    const SizedBox(height: 4),
                    _AnimatedLineTextField(
                      controller: _modelIdCtrl,
                      hint: 'e.g. gpt-4o, gemini-1.5-pro',
                      errorText: _modelIdError,
                    ),

                    const SizedBox(height: 20),

                    // ── API Key with Animated Line ──
                    _sectionLabel('API KEY'),
                    const SizedBox(height: 4),
                    _AnimatedLineTextField(
                      controller: _apiKeyCtrl,
                      hint: widget.isEditMode ? '••••••••  (leave empty to keep current)' : 'sk-...',
                      obscure: _obscureKey,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                        icon: Icon(
                          _obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: context.textSecondary,
                          size: 18,
                        ),
                        splashRadius: 16,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Endpoint URL with Animated Line ──
                    _sectionLabel('ENDPOINT URL'),
                    const SizedBox(height: 4),
                    _AnimatedLineTextField(
                      controller: _endpointCtrl,
                      hint: 'https://api.example.com/v1/...',
                    ),

                    const SizedBox(height: 20),

                    // ── Description with Animated Line ──
                    _sectionLabel('DESCRIPTION (optional)'),
                    const SizedBox(height: 4),
                    _AnimatedLineTextField(
                      controller: _descriptionCtrl,
                      hint: 'Brief description of this model\'s strengths',
                      maxLines: 2,
                    ),

                    const SizedBox(height: 20),

                    // ── Temperature with Animated Line ──
                    _sectionLabel('TEMPERATURE'),
                    const SizedBox(height: 4),
                    _AnimatedLineTextField(
                      controller: _temperatureCtrl,
                      hint: 'e.g. 0.7',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      errorText: _temperatureError,
                    ),

                    const SizedBox(height: 20),

                    // ── Max Tokens with Animated Line ──
                    _sectionLabel('MAX TOKENS'),
                    const SizedBox(height: 4),
                    _AnimatedLineTextField(
                      controller: _maxTokensCtrl,
                      hint: 'e.g. 2048',
                      keyboardType: TextInputType.number,
                      errorText: _maxTokensError,
                    ),

                    const SizedBox(height: 20),

                    // ── Routing Checkbox ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Is this for Routing purpose?',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Enable if this model is used for routing decisions',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: _isRouter,
                            onChanged: (v) => setState(() {
                              _isRouter = v ?? false;
                              if (_isRouter) _routingTagsError = null;
                            }),
                            activeColor: const Color(0xFFEF4444),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ],
                      ),
                    ),

                    if (!_isRouter) ...[
                      const SizedBox(height: 20),

                      // ── Routing Tags ──
                      _sectionLabel('ROUTING TAGS (best suited for)'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allRoutingTags.map((tag) {
                          final selected = _selectedTags.contains(tag);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selectedTags.remove(tag);
                                } else {
                                  _selectedTags.add(tag);
                                }
                                if (_routingTagsError != null) {
                                  _routingTagsError = null;
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                    : context.surface2,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected ? const Color(0xFFEF4444) : context.borderColor,
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: selected ? const Color(0xFFEF4444) : context.textSecondary,
                                  fontSize: 12.5,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_routingTagsError != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _routingTagsError!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 20),

                    // ── Active Toggle ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Make available for routing & comparison',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          Transform.scale(
                            scale: 0.85,
                            child: Switch(
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v),
                              activeThumbColor: const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Bottom Action Button ──
            // User: "add model hai usmai bhi icons ko remove kro just add model ho and container bhi remove kro green just animated line mai add model write ho"
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              decoration: BoxDecoration(
                color: context.surface,
                border: Border(
                  top: BorderSide(color: context.borderColor),
                ),
              ),
              child: _AnimatedLineButton(
                text: widget.isEditMode ? 'Save Changes' : 'Add Model',
                isLoading: _isSubmitting,
                onPressed: _submitModel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: context.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Animated Line Text Field (Only animates on focus/click)
// ─────────────────────────────────────────────────────────────

class _AnimatedLineTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffixIcon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? errorText;

  const _AnimatedLineTextField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.suffixIcon,
    this.maxLines = 1,
    this.keyboardType,
    this.errorText,
  });

  @override
  State<_AnimatedLineTextField> createState() => _AnimatedLineTextFieldState();
}

class _AnimatedLineTextFieldState extends State<_AnimatedLineTextField>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode;
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _animCtrl.repeat();
      } else {
        _animCtrl.stop();
        _animCtrl.reset();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final isFocused = _focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animCtrl,
          builder: (context, child) {
            return CustomPaint(
              painter: _UnderlineBeamPainter(
                progress: _animCtrl.value,
                isFocused: isFocused,
                hasError: hasError,
                baseColor: context.borderColor,
                beamColor: const Color(0xFFEF4444),
              ),
              child: child,
            );
          },
          child: TextField(
            focusNode: _focusNode,
            controller: widget.controller,
            obscureText: widget.obscure,
            maxLines: widget.maxLines,
            keyboardType: widget.keyboardType,
            style: TextStyle(color: context.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: context.textSecondary.withValues(alpha: 0.5),
                fontSize: 13,
              ),
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              suffixIcon: widget.suffixIcon,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 13),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.errorText!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Custom painter for the animated underline laser beam on text field focus
class _UnderlineBeamPainter extends CustomPainter {
  final double progress;
  final bool isFocused;
  final bool hasError;
  final Color baseColor;
  final Color beamColor;

  const _UnderlineBeamPainter({
    required this.progress,
    required this.isFocused,
    required this.hasError,
    required this.baseColor,
    required this.beamColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height;

    // 1. Static base track
    final trackPaint = Paint()
      ..color = hasError ? Colors.redAccent.withValues(alpha: 0.6) : baseColor
      ..strokeWidth = hasError ? 1.5 : 1.0;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), trackPaint);

    if (hasError) return;

    // 2. Animated glowing laser beam only when field has focus
    if (isFocused && size.width > 0) {
      final beamLength = size.width * 0.45;
      final startX = (size.width + beamLength) * progress - beamLength;
      final endX = (startX + beamLength).clamp(0.0, size.width);
      final clampedStartX = startX.clamp(0.0, size.width);

      if (endX > clampedStartX) {
        final shader = LinearGradient(
          colors: [
            Colors.transparent,
            beamColor.withValues(alpha: 0.3),
            beamColor,
            const Color(0xFFFF8888),
            beamColor,
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.5, 0.65, 0.85, 1.0],
        ).createShader(Rect.fromLTWH(clampedStartX, y - 2, endX - clampedStartX, 4));

        // Glow halo
        final glowPaint = Paint()
          ..shader = shader
          ..strokeWidth = 3.6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
        canvas.drawLine(Offset(clampedStartX, y), Offset(endX, y), glowPaint);

        // Sharp beam line
        final beamPaint = Paint()
          ..shader = shader
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(clampedStartX, y), Offset(endX, y), beamPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_UnderlineBeamPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isFocused != isFocused ||
        oldDelegate.hasError != hasError ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.beamColor != beamColor;
  }
}

// ─────────────────────────────────────────────────────────────
// Animated Line Button (No icons, no solid green container,
// just animated line and bold text)
// ─────────────────────────────────────────────────────────────

class _AnimatedLineButton extends StatefulWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _AnimatedLineButton({
    required this.text,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  State<_AnimatedLineButton> createState() => _AnimatedLineButtonState();
}

class _AnimatedLineButtonState extends State<_AnimatedLineButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return SizedBox(
      height: 46,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return CustomPaint(
            painter: MovingRedBorderPainter(
              progress: _ctrl.value,
              borderRadius: 10,
              isDark: isDark,
            ),
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent, // Removed green container / solid fill
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.isLoading ? null : widget.onPressed,
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFEF4444),
                      ),
                    )
                  : Text(
                      widget.text, // Just "Add Model" / text, no icon!
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
