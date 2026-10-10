// lib/features/shell/presentation/widgets/top_bar.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';

/// Dark premium top header — brand comes from Store Info settings.
class TopBar extends StatelessWidget {
  final VoidCallback onSearchTap;
  final AuthController authController;
  final SettingsController settingsController;

  const TopBar({
    super.key,
    required this.onSearchTap,
    required this.authController,
    required this.settingsController,
  });

  static const Color _headerBg = Color(0xFF1E293B);
  static const Color _headerBgEnd = Color(0xFF0F172A);
  static const Color _searchBg = Color(0xFF334155);
  static const Color _muted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (context, _) {
        final user = authController.currentUser;
        final initials = user != null && user.fullName.length >= 2
            ? user.fullName.substring(0, 2).toUpperCase()
            : 'SY';
        final displayName = user?.fullName.split(' ').first ?? 'System';
        final roleLabel = user == null
            ? 'Administrator'
            : (user.roleName.isNotEmpty ? user.roleName : user.role.label);

        // ── From Store Info settings ──
        final pharmacyName = settingsController.getValue('pharmacy_name').trim();
        final logoPath = settingsController.getValue('pharmacy_logo_path').trim();

        final brandTitle =
        pharmacyName.isEmpty ? 'PHARMASUITE' : pharmacyName.toUpperCase();

        final hasLogo = logoPath.isNotEmpty && File(logoPath).existsSync();

        return Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_headerBg, _headerBgEnd],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              // ── Logo (from Store Info, or default icon) ──
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: hasLogo ? Colors.white : AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  border: hasLogo
                      ? Border.all(color: const Color(0xFF475569), width: 1)
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: hasLogo
                    ? Image.file(
                  File(logoPath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.local_pharmacy_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                )
                    : const Icon(
                  Icons.local_pharmacy_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // ── Pharmacy Name Only ──
              Text(
                brandTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(width: 24),

              // Search Bar (Ctrl + K)
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Material(
                      color: _searchBg,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        onTap: onSearchTap,
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded,
                                  size: 18, color: _muted),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Search medicines, batches, customers...',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                                child: const Text(
                                  'Ctrl + K',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),
              Container(height: 26, width: 1, color: const Color(0xFF475569)),
              const SizedBox(width: 10),

              // User Menu
              PopupMenuButton<String>(
                tooltip: 'Account',
                offset: const Offset(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (action) {
                  if (action == 'logout') authController.logout();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Administrator',
                          style: AppTypography.label,
                        ),
                        Text(
                          user?.email ?? 'admin@pharmasuite.com',
                          style: AppTypography.caption,
                        ),
                        const Divider(height: 14),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(
                          Icons.power_settings_new_rounded,
                          size: 16,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Exit Session',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          roleLabel,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: _muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}