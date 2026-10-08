import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../users/domain/role.dart';
import '../../domain/setting.dart';
import '../controllers/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsController controller;
  final AuthController authController;

  const SettingsScreen({
    super.key,
    required this.controller,
    required this.authController,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: SettingCategory.values.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadSettings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  bool get _canManage => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.settings, PermissionAction.manage);

  TextEditingController _ctrl(String key, String initial) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initial);
    }
    return _controllers[key]!;
  }

  Future<void> _saveCategory(SettingCategory cat) async {
    final catSettings =
    widget.controller.settings.where((s) => s.category == cat).toList();
    final values = <String, String>{};
    for (final s in catSettings) {
      final ctrl = _controllers[s.key];
      if (ctrl != null) values[s.key] = ctrl.text;
    }
    final error = await widget.controller.saveSettings(values);
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
    } else {
      AppToast.success(context, 'Settings saved.');
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
            Row(children: [
              const Icon(Icons.settings_rounded,
                  color: AppColors.primary, size: 28),
              const SizedBox(width: AppSpacing.md),
              Text('Settings', style: AppTypography.pageTitle),
            ]),
            const SizedBox(height: AppSpacing.lg),

            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs:
              SettingCategory.values.map((c) => Tab(text: c.label)).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            Expanded(
              child: ctrl.isLoading
                  ? const AppLoading()
                  : TabBarView(
                controller: _tabController,
                children: SettingCategory.values.map((cat) {
                  final catSettings =
                  ctrl.settings.where((s) => s.category == cat).toList();
                  return _buildCategoryTab(cat, catSettings);
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryTab(SettingCategory cat, List<Setting> settings) {
    if (settings.isEmpty) {
      return const AppEmptyState(
        icon: Icons.settings_outlined,
        title: 'No settings in this category',
        subtitle: 'Settings will appear here as they are configured.',
      );
    }

    final readOnly = !_canManage;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.huge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.label,
                    style: AppTypography.sectionTitle
                        .copyWith(color: AppColors.primary)),
                const SizedBox(height: AppSpacing.lg),
                ...settings.map((s) {
                  final isBool = s.value == 'true' || s.value == 'false';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: isBool
                        ? SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.label,
                          style: AppTypography.subtitle
                              .copyWith(fontSize: 14)),
                      subtitle: s.description != null
                          ? Text(s.description!,
                          style: AppTypography.caption)
                          : null,
                      value: s.value == 'true',
                      onChanged: readOnly
                          ? null
                          : (v) {
                        _ctrl(s.key, s.value).text = v.toString();
                        setState(() {});
                      },
                    )
                        : IgnorePointer(
                      ignoring: readOnly,
                      child: Opacity(
                        opacity: readOnly ? 0.6 : 1.0,
                        child: AppTextField(
                          controller: _ctrl(s.key, s.value),
                          label: s.label,
                          hint: s.description ?? '',
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_canManage)
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: 'Save ${cat.label}',
                icon: Icons.save_outlined,
                variant: AppButtonVariant.primary,
                onPressed: () => _saveCategory(cat),
              ),
            ),
        ],
      ),
    );
  }
}