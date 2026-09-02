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
  void _addDummyModel() {
    final n = modelStore.models.length;
    modelStore.add(LlmModel(
      id: 'new_${DateTime.now().microsecondsSinceEpoch}',
      name: 'New Model ${n + 1}',
      provider: 'Custom API',
      modelCode: 'custom-model-${n + 1}',
      badgeLetter: 'N',
      color: AppColors.purple,
      tags: ['general'],
    ));
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
                  onPressed: _addDummyModel,
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
                          onDelete: () => modelStore.remove(m.id),
                          onEdit: () => _showEditDialog(m),
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

  void _showEditDialog(LlmModel m) {
    final nameCtrl = TextEditingController(text: m.name);
    final providerCtrl = TextEditingController(text: m.provider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Edit Model', style: TextStyle(color: context.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: const InputDecoration(labelText: 'Model name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: providerCtrl,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: const InputDecoration(labelText: 'Provider'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              final newProvider = providerCtrl.text.trim();
              if (newName.isNotEmpty) m.name = newName;
              if (newProvider.isNotEmpty) m.provider = newProvider;
              modelStore.refresh();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

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
