import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/network/network_config.dart';
import '../../../../core/widgets/components.dart';
import '../controllers/network_controller.dart';

class NetworkSettingsScreen extends StatefulWidget {
  final NetworkController controller;
  const NetworkSettingsScreen({super.key, required this.controller});

  @override
  State<NetworkSettingsScreen> createState() => _NetworkSettingsScreenState();
}

class _NetworkSettingsScreenState extends State<NetworkSettingsScreen> {
  late final TextEditingController _ipCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _pcNameCtrl;

  @override
  void initState() {
    super.initState();
    final cfg = NetworkConfig.instance;
    _ipCtrl = TextEditingController(text: cfg.serverIp);
    _portCtrl = TextEditingController(text: cfg.port.toString());
    _pcNameCtrl = TextEditingController(text: cfg.pcName);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.initialize();
    });
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _pcNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final cfg = ctrl.config;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.huge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.lan_rounded, color: AppColors.primary, size: 28),
                const SizedBox(width: AppSpacing.md),
                Text('Network & LAN Sharing', style: AppTypography.pageTitle),
              ]),
              const SizedBox(height: AppSpacing.xl),

              _buildCard(
                title: 'Operating Mode',
                icon: Icons.computer,
                child: Column(
                  children: AppMode.values.map((mode) {
                    return RadioListTile<AppMode>(
                      title: Text(mode.label, style: AppTypography.subtitle.copyWith(fontSize: 14)),
                      subtitle: Text(_modeDescription(mode), style: AppTypography.caption),
                      value: mode,
                      groupValue: cfg.mode,
                      activeColor: AppColors.primary,
                      onChanged: (v) {
                        if (v != null) {
                          ctrl.saveConfig(mode: v);
                          if (v == AppMode.server) _ipCtrl.text = ctrl.localIp;
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              _buildCard(
                title: 'This PC',
                icon: Icons.badge_outlined,
                child: Column(
                  children: [
                    AppTextField(
                      controller: _pcNameCtrl,
                      label: 'PC Name / Identifier',
                      hint: 'e.g. Counter-1, Main-PC',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Local IP: ${ctrl.localIp}', style: AppTypography.caption),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              if (cfg.isServer) ...[
                _buildCard(
                  title: 'Server Configuration',
                  icon: Icons.dns_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _portCtrl,
                              label: 'Port',
                              hint: '8080',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Auto-start', style: TextStyle(fontSize: 13)),
                              value: cfg.autoStartServer,
                              activeColor: AppColors.primary,
                              onChanged: (v) => ctrl.saveConfig(autoStart: v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: ctrl.isServerRunning ? 'Stop Server' : 'Start Server',
                        icon: ctrl.isServerRunning ? Icons.stop : Icons.play_arrow,
                        variant: ctrl.isServerRunning
                            ? AppButtonVariant.danger
                            : AppButtonVariant.primary,
                        onPressed: () async {
                          if (ctrl.isServerRunning) {
                            await ctrl.stopServer();
                          } else {
                            await ctrl.saveConfig(port: int.tryParse(_portCtrl.text) ?? 8080);
                            await ctrl.startServer();
                          }
                        },
                      ),
                      if (ctrl.statusMessage.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: ctrl.isServerRunning
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                ctrl.isServerRunning ? Icons.check_circle : Icons.info,
                                color: ctrl.isServerRunning ? AppColors.success : AppColors.warning,
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: Text(ctrl.statusMessage, style: AppTypography.caption)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                _buildCard(
                  title: 'Connected PCs (${ctrl.connectedClients.length})',
                  icon: Icons.devices_rounded,
                  child: ctrl.connectedClients.isEmpty
                      ? const AppEmptyState(
                    icon: Icons.devices_other_outlined,
                    title: 'No clients connected',
                    subtitle: 'Client PCs will appear here when they connect.',
                  )
                      : Column(
                    children: ctrl.connectedClients.map((c) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(Icons.computer, color: AppColors.primary, size: 18),
                        ),
                        title: Text(c['pcName'] ?? 'Unknown',
                            style: AppTypography.subtitle.copyWith(fontSize: 14)),
                        subtitle: Text(
                          '${c['ipAddress']}  •  Connected: ${_formatTime(c['connectedAt'])}',
                          style: AppTypography.caption,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Online',
                              style: TextStyle(fontSize: 11, color: AppColors.success)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              if (cfg.isClient) ...[
                _buildCard(
                  title: 'Server Connection',
                  icon: Icons.cloud_outlined,
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _ipCtrl,
                        label: 'Server IP Address',
                        hint: 'e.g. 192.168.1.100',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _portCtrl,
                        label: 'Server Port',
                        hint: '8080',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Test Connection',
                              icon: Icons.wifi_find,
                              variant: AppButtonVariant.primary, // Fixed from secondary to primary
                              isLoading: ctrl.isTesting,
                              onPressed: () async {
                                await ctrl.saveConfig(
                                  serverIp: _ipCtrl.text.trim(),
                                  port: int.tryParse(_portCtrl.text) ?? 8080,
                                );
                                await ctrl.testClientConnection();
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppButton(
                              label: 'Save & Connect',
                              icon: Icons.save_outlined,
                              variant: AppButtonVariant.primary,
                              onPressed: () async {
                                await ctrl.saveConfig(
                                  serverIp: _ipCtrl.text.trim(),
                                  port: int.tryParse(_portCtrl.text) ?? 8080,
                                  pcName: _pcNameCtrl.text.trim(),
                                );
                                if (context.mounted) {
                                  AppToast.success(context, 'Client config saved. Restart app to connect.');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (ctrl.statusMessage.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: ctrl.isConnected
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                ctrl.isConnected ? Icons.check_circle : Icons.error,
                                color: ctrl.isConnected ? AppColors.success : AppColors.error,
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: Text(ctrl.statusMessage, style: AppTypography.caption)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: 'Save PC Name',
                  icon: Icons.save_outlined,
                  variant: AppButtonVariant.primary,
                  onPressed: () => ctrl.saveConfig(pcName: _pcNameCtrl.text.trim()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTypography.sectionTitle.copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }

  String _modeDescription(AppMode mode) {
    switch (mode) {
      case AppMode.standalone:
        return 'Single PC, no network. Database stored locally.';
      case AppMode.server:
        return 'This PC hosts the database. Other PCs connect to it.';
      case AppMode.client:
        return 'This PC connects to the Main PC over LAN cable/WiFi.';
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}