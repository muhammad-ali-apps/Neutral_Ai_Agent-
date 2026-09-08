import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models.dart';
import '../widgets/screen_header.dart';

/// Admin panel for managing LLM model integrations.
class AdminPanelScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  const AdminPanelScreen({super.key, this.onMenuTap});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
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
                    onPressed: () {
                      modelStore.remove(model.id);
                      Navigator.pop(ctx);
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

        return Column(
          children: [
            ScreenHeader(
              icon: Icons.settings_outlined,
              title: 'Admin Panel',
              subtitle: 'Manage LLM integrations',
              onMenuTap: widget.onMenuTap,
              trailing: SizedBox(
                height: 34,
                child: ElevatedButton.icon(
                  onPressed: () => _openModelPanel(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Add Model',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(builder: (context, constraints) {
                      final wide = constraints.maxWidth > 600;
                      final stats = [
                        _StatCard(value: '${models.length}', label: 'Total Models'),
                        _StatCard(value: '$active', label: 'Active'),
                        _StatCard(value: '$providers', label: 'Providers'),
                      ];
                      if (wide) {
                        return Row(
                          children: stats
                              .map((s) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: s,
                                    ),
                                  ))
                              .toList(),
                        );
                      }
                      return Column(
                        children: stats
                            .map((s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: s,
                                ))
                            .toList(),
                      );
                    }),
                    const SizedBox(height: 16),
                    ...models.map((m) => _ModelRow(
                          model: m,
                          onToggle: () => modelStore.toggleActive(m.id),
                          onDelete: () => _confirmDelete(m),
                          onEdit: () => _openModelPanel(existingModel: m),
                        )),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

}

// ─────────────────────────────────────────────────────────────
// Add LLM Integration — Right Slide-In Panel
// ─────────────────────────────────────────────────────────────

class _ProviderOption {
  final String name;
  final String subtitle;
  final String letter;
  final Color color;

  const _ProviderOption({
    required this.name,
    required this.subtitle,
    required this.letter,
    required this.color,
  });
}

const _providers = <_ProviderOption>[
  _ProviderOption(name: 'OpenAI', subtitle: 'GPT-4, GPT-3.5-turbo', letter: 'O', color: AppColors.openaiGreen),
  _ProviderOption(name: 'Google Gemini', subtitle: 'Gemini Pro, Gemini Ultra', letter: 'G', color: AppColors.geminiBlue),
  _ProviderOption(name: 'Anthropic Claude', subtitle: 'Claude 3, Claude 2', letter: 'A', color: AppColors.anthropicOrange),
  _ProviderOption(name: 'Ollama (Local)', subtitle: 'Llama, Mistral, etc.', letter: 'O', color: AppColors.deepseekGray),
  _ProviderOption(name: 'Custom API', subtitle: 'Any OpenAI-compatible API', letter: 'C', color: AppColors.purple),
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
  bool _obscureKey = true;
  final Set<String> _selectedTags = {'coding', 'reasoning', 'creative', 'general'};

  final _displayNameCtrl = TextEditingController();
  final _modelIdCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _endpointCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final m = widget.existingModel;
    if (m != null) {
      _displayNameCtrl.text = m.name;
      _modelIdCtrl.text = m.modelCode;
      _isActive = m.active;
      _selectedTags
        ..clear()
        ..addAll(m.tags);
      // Match provider by name
      final idx = _providers.indexWhere((p) => p.name == m.provider);
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
    super.dispose();
  }

  void _submitModel() {
    final provider = _providers[_selectedProvider];
    final name = _displayNameCtrl.text.trim().isNotEmpty
        ? _displayNameCtrl.text.trim()
        : '${provider.name} Model';
    final modelCode = _modelIdCtrl.text.trim().isNotEmpty
        ? _modelIdCtrl.text.trim()
        : 'custom-${DateTime.now().microsecondsSinceEpoch}';

    if (widget.isEditMode) {
      // Update existing model
      final m = widget.existingModel!;
      m.name = name;
      m.provider = provider.name;
      m.modelCode = modelCode;
      m.badgeLetter = provider.letter;
      m.color = provider.color;
      m.tags = _selectedTags.toList();
      m.active = _isActive;
      modelStore.refresh();
    } else {
      // Add new model
      modelStore.add(LlmModel(
        id: 'model_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        provider: provider.name,
        modelCode: modelCode,
        badgeLetter: provider.letter,
        color: provider.color,
        tags: _selectedTags.toList(),
        active: _isActive,
      ));
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Responsive: full width on small screens, 400px on larger
    final panelWidth = screenWidth < 500 ? screenWidth : 400.0;

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
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ──
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
                      widget.isEditMode ? 'Edit LLM Integration' : 'Add LLM Integration',
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

            // ── Scrollable body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Provider Selection ──
                    _sectionLabel('PROVIDER'),
                    const SizedBox(height: 10),
                    ...List.generate(_providers.length, (i) {
                      final p = _providers[i];
                      final selected = _selectedProvider == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedProvider = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.purple.withValues(alpha: 0.08)
                                : context.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? AppColors.purple : context.borderColor,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: p.color,
                                child: Text(
                                  p.letter,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      p.subtitle,
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 20),

                    // ── Display Name ──
                    _sectionLabel('DISPLAY NAME *'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _displayNameCtrl,
                      hint: 'e.g. GPT-4 Turbo, Claude 3',
                    ),

                    const SizedBox(height: 16),

                    // ── Model ID ──
                    _sectionLabel('MODEL ID *'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _modelIdCtrl,
                      hint: 'e.g. gpt-4o, gemini-1.5-pro',
                    ),

                    const SizedBox(height: 16),

                    // ── API Key ──
                    _sectionLabel('API KEY'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _apiKeyCtrl,
                      hint: 'sk-...',
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

                    const SizedBox(height: 16),

                    // ── Endpoint URL ──
                    _sectionLabel('ENDPOINT URL'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _endpointCtrl,
                      hint: 'https://api.example.com/v1/...',
                    ),

                    const SizedBox(height: 16),

                    // ── Description ──
                    _sectionLabel('DESCRIPTION (optional)'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _descriptionCtrl,
                      hint: 'Brief description of this model\'s strengths',
                      maxLines: 2,
                    ),

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
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.purple.withValues(alpha: 0.15)
                                  : context.surface2,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? AppColors.purple : context.borderColor,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                color: selected ? AppColors.purple : context.textSecondary,
                                fontSize: 12.5,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

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
                              activeThumbColor: AppColors.purple,
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

            // ── Bottom Add Model Button ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: context.surface,
                border: Border(
                  top: BorderSide(color: context.borderColor),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _submitModel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(widget.isEditMode ? Icons.check_rounded : Icons.save_outlined, size: 18),
                  label: Text(
                    widget.isEditMode ? 'Save Changes' : 'Add Model',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
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
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffixIcon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: maxLines,
      style: TextStyle(color: context.textPrimary, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.textSecondary.withValues(alpha: 0.6), fontSize: 13),
        filled: true,
        fillColor: context.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Stat Card
// ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.purple,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Model Row
// ─────────────────────────────────────────────────────────────

class _ModelRow extends StatelessWidget {
  final LlmModel model;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ModelRow({
    required this.model,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: model.color,
            child: Text(
              model.badgeLetter,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
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
                        model.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (model.active ? AppColors.success : context.textSecondary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        model.active ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: model.active ? AppColors.success : context.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${model.provider} · ${model.modelCode}',
                  style: TextStyle(color: context.textSecondary, fontSize: 11.5),
                ),
                if (model.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: model.tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(color: AppColors.purple, fontSize: 10),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: model.active,
              onChanged: (_) => onToggle(),
              activeThumbColor: AppColors.purple,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          IconButton(
            onPressed: onEdit,
            iconSize: 17,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: Icon(Icons.edit_outlined, color: context.textSecondary),
          ),
          IconButton(
            onPressed: onDelete,
            iconSize: 17,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}
