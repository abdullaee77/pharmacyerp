import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../domain/category.dart';
import '../../domain/manufacturer.dart';
import '../controllers/category_controller.dart';

/// Categories & Manufacturers master data management workspace.
class CategoriesScreen extends StatefulWidget {
  final CategoryController controller;

  const CategoriesScreen({super.key, required this.controller});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addEditCategory({Category? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Category' : 'Edit Category'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: nameCtrl,
                label: 'Name',
                isRequired: true,
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: descCtrl,
                label: 'Description',
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final c = Category(
        id: existing?.id ?? CategoryId.generate(),
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
        createdAt: existing?.createdAt ?? DateTime.now(),
      );
      final error = await widget.controller.saveCategory(
        c,
        isNew: existing == null,
      );
      if (!mounted) return;
      if (error != null) {
        AppToast.error(context, error);
      } else {
        AppToast.success(context, 'Category saved.');
      }
    }
  }

  Future<void> _addEditManufacturer({Manufacturer? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final contactCtrl = TextEditingController(text: existing?.contact ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing == null ? 'Add Manufacturer' : 'Edit Manufacturer',
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: nameCtrl,
                label: 'Name',
                isRequired: true,
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: contactCtrl,
                label: 'Contact',
                prefixIcon: Icons.phone_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: addressCtrl,
                label: 'Address',
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final m = Manufacturer(
        id: existing?.id ?? ManufacturerId.generate(),
        name: nameCtrl.text.trim(),
        contact: contactCtrl.text.trim(),
        address: addressCtrl.text.trim(),
        createdAt: existing?.createdAt ?? DateTime.now(),
      );
      final error = await widget.controller.saveManufacturer(
        m,
        isNew: existing == null,
      );
      if (!mounted) return;
      if (error != null) {
        AppToast.error(context, error);
      } else {
        AppToast.success(context, 'Manufacturer saved.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.category_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Classification Master Data',
                      style: AppTypography.pageTitle,
                    ),
                    Text(
                      'Manage categories and manufacturers used across all medicines.',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Categories'),
                Tab(text: 'Manufacturers'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCategoriesTab(ctrl),
                  _buildManufacturersTab(ctrl),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoriesTab(CategoryController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${ctrl.categories.length} categories',
              style: AppTypography.subtitle,
            ),
            const Spacer(),
            AppButton(
              label: 'Add Category',
              icon: Icons.add_rounded,
              variant: AppButtonVariant.primary,
              onPressed: () => _addEditCategory(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ctrl.isLoading
              ? const AppLoading()
              : ctrl.categories.isEmpty
              ? AppEmptyState(
                  icon: Icons.category_outlined,
                  title: 'No categories added',
                  subtitle: 'Create your first category to classify medicines.',
                  actionLabel: 'Add Category',
                  onAction: () => _addEditCategory(),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: ListView.separated(
                      itemCount: ctrl.categories.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final c = ctrl.categories[i];
                        return ListTile(
                          leading: const Icon(
                            Icons.label_outline_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            c.name,
                            style: AppTypography.subtitle.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          subtitle: c.description.isEmpty
                              ? null
                              : Text(
                                  c.description,
                                  style: AppTypography.caption,
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                splashRadius: 16,
                                onPressed: () => _addEditCategory(existing: c),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                splashRadius: 16,
                                onPressed: () async {
                                  final ok = await AppDialog.warning(
                                    context,
                                    title: 'Delete Category?',
                                    message: '"${c.name}" will be removed.',
                                    confirmLabel: 'Delete',
                                  );
                                  if (ok && mounted) {
                                    final err = await widget.controller
                                        .deleteCategory(c.id);
                                    if (mounted && err != null)
                                      AppToast.error(context, err);
                                    else if (mounted)
                                      AppToast.success(context, 'Deleted.');
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildManufacturersTab(CategoryController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${ctrl.manufacturers.length} manufacturers',
              style: AppTypography.subtitle,
            ),
            const Spacer(),
            AppButton(
              label: 'Add Manufacturer',
              icon: Icons.add_rounded,
              variant: AppButtonVariant.primary,
              onPressed: () => _addEditManufacturer(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ctrl.isLoading
              ? const AppLoading()
              : ctrl.manufacturers.isEmpty
              ? AppEmptyState(
                  icon: Icons.business_outlined,
                  title: 'No manufacturers added',
                  subtitle: 'Create your first manufacturer entry.',
                  actionLabel: 'Add Manufacturer',
                  onAction: () => _addEditManufacturer(),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: ListView.separated(
                      itemCount: ctrl.manufacturers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final m = ctrl.manufacturers[i];
                        return ListTile(
                          leading: const Icon(
                            Icons.business_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            m.name,
                            style: AppTypography.subtitle.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (m.contact.isNotEmpty)
                                Text(
                                  'Contact: ${m.contact}',
                                  style: AppTypography.caption,
                                ),
                              if (m.address.isNotEmpty)
                                Text(m.address, style: AppTypography.caption),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                splashRadius: 16,
                                onPressed: () =>
                                    _addEditManufacturer(existing: m),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                splashRadius: 16,
                                onPressed: () async {
                                  final ok = await AppDialog.warning(
                                    context,
                                    title: 'Delete Manufacturer?',
                                    message: '"${m.name}" will be removed.',
                                    confirmLabel: 'Delete',
                                  );
                                  if (ok && mounted) {
                                    final err = await widget.controller
                                        .deleteManufacturer(m.id);
                                    if (mounted && err != null)
                                      AppToast.error(context, err);
                                    else if (mounted)
                                      AppToast.success(context, 'Deleted.');
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
