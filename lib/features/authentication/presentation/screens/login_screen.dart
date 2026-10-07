import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_elevation.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  final AuthController controller;

  const LoginScreen({
    super.key,
    required this.controller,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    widget.controller.clearError();
    if (_formKey.currentState?.validate() ?? false) {
      final success = await widget.controller.login(
        _usernameController.text,
        _passwordController.text,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Welcome back, ${widget.controller.currentUser!.fullName}',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 820,
            height: 520,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppElevation.shadowLg,
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 11,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.xl - 1),
                        bottomLeft: Radius.circular(AppRadius.xl - 1),
                      ),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withValues(alpha: 0.15),
                                borderRadius:
                                BorderRadius.circular(AppRadius.md),
                              ),
                              child: const Icon(
                                Icons.local_pharmacy_rounded,
                                color: AppColors.textInverse,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              'PHARMASUITE',
                              style: AppTypography.sectionTitle.copyWith(
                                color: AppColors.textInverse,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'Comprehensive Pharmacy Information System',
                          style: AppTypography.display.copyWith(
                            fontSize: 26,
                            color: AppColors.textInverse,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Secure offline-first database. Manage stock, sales, purchases, and accounts.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textInverse.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              size: 14,
                              color: AppColors.accentLight,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Local SQLite authentication',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textInverse.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 12,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.xl,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Terminal Access Portal',
                            style: AppTypography.pageTitle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sign in with your assigned username and password.',
                            style: AppTypography.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          ListenableBuilder(
                            listenable: widget.controller,
                            builder: (context, _) {
                              if (widget.controller.errorMessage == null) {
                                return const SizedBox.shrink();
                              }
                              return Container(
                                margin: const EdgeInsets.only(
                                  bottom: AppSpacing.lg,
                                ),
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.errorSurface,
                                  borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: AppColors.errorLight
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: AppColors.error,
                                      size: 18,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        widget.controller.errorMessage!,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          TextFormField(
                            controller: _usernameController,
                            focusNode: _usernameFocus,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              hintText: 'e.g. admin',
                            ),
                            onChanged: (_) => widget.controller.clearError(),
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Username required.'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon:
                              const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(
                                        () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                            ),
                            onChanged: (_) => widget.controller.clearError(),
                            onFieldSubmitted: (_) => _submit(),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Password required.'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          ListenableBuilder(
                            listenable: widget.controller,
                            builder: (context, _) {
                              final isLoading = widget.controller.isLoading;
                              return ElevatedButton(
                                onPressed: isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                      AppColors.textInverse,
                                    ),
                                  ),
                                )
                                    : const Text('Unlock Workspace'),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Default admin (first install): admin / admin123\n'
                                'Create more users from More → Users after login.',
                            style: AppTypography.caption,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}