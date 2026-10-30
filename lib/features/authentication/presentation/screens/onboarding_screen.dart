// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import '../../../../core/theme/app_colors.dart';
// import '../../../../core/theme/app_spacing.dart';
// import '../../../../core/theme/app_radius.dart';
// import '../../../../core/theme/app_typography.dart';
// import '../controllers/auth_controller.dart';
// import '../../../licensing/data/sqlite_license_repository.dart';
// import '../../../licensing/domain/device_fingerprint.dart';
// import '../../../licensing/domain/license.dart';
// import '../../../licensing/presentation/controllers/license_controller.dart';
// import '../../../licensing/presentation/screens/license_screen.dart';
//
// enum AuthStep { welcome, activation, accountCreation, login }
//
// class OnboardingScreen extends StatefulWidget {
//   final AuthController authController;
//   final LicenseController? licenseController;
//   final VoidCallback onLoginSuccess;
//
//   const OnboardingScreen({
//     super.key,
//     required this.authController,
//     required this.onLoginSuccess,
//     this.licenseController,
//   });
//
//   @override
//   State<OnboardingScreen> createState() => _OnboardingScreenState();
// }
//
// class _OnboardingScreenState extends State<OnboardingScreen> {
//   final SqliteLicenseRepository _licenseRepo = SqliteLicenseRepository();
//   AuthStep _currentStep = AuthStep.welcome;
//
//   bool? _hasAdmin;
//
//   final _payloadController = TextEditingController();
//   final _pharmacyNameController = TextEditingController();
//   final _usernameController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _confirmPasswordController = TextEditingController();
//
//   bool _isLoading = false;
//   String? _errorMessage;
//   bool _obscurePassword = true;
//   bool _obscureConfirmPassword = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _checkAdminStatus();
//   }
//
//   Future<void> _checkAdminStatus() async {
//     final hasAdmin = await widget.authController.hasAnyAdminRegistered();
//     if (mounted) {
//       setState(() => _hasAdmin = hasAdmin);
//     }
//   }
//
//   @override
//   void dispose() {
//     _payloadController.dispose();
//     _pharmacyNameController.dispose();
//     _usernameController.dispose();
//     _passwordController.dispose();
//     _confirmPasswordController.dispose();
//     super.dispose();
//   }
//
//   void _setStep(AuthStep step) {
//     setState(() {
//       _currentStep = step;
//       _errorMessage = null;
//       _payloadController.clear();
//       _passwordController.clear();
//       _confirmPasswordController.clear();
//     });
//   }
//
//   /// Opens the License Manager directly when requested from the login screen
//   Future<void> _openLicenseScreen() async {
//     final controller = widget.licenseController ??
//         LicenseController(repository: _licenseRepo);
//
//     await Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (ctx) => Scaffold(
//           backgroundColor: AppColors.surface,
//           appBar: AppBar(
//             backgroundColor: AppColors.primary,
//             foregroundColor: Colors.white,
//             title: const Text('License Management'),
//             leading: IconButton(
//               icon: const Icon(Icons.arrow_back_rounded),
//               onPressed: () => Navigator.of(ctx).pop(),
//             ),
//           ),
//           body: SafeArea(
//             child: LicenseScreen(
//               controller: controller,
//               onLicenseActivated: () {
//                 Navigator.of(ctx).pop();
//               },
//             ),
//           ),
//         ),
//       ),
//     );
//
//     if (!mounted) return;
//
//     // After returning from License Manager, clear the previous error
//     widget.authController.clearError();
//     setState(() {
//       _errorMessage = null;
//     });
//   }
//
//   /// Initial License Activation (First-Time Setup)
//   Future<void> _handleActivation() async {
//     final payload = _payloadController.text.trim();
//     if (payload.isEmpty) {
//       setState(() => _errorMessage = 'Please paste the license JSON payload.');
//       return;
//     }
//
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     final result = await _licenseRepo.activateLicense(payload);
//     if (!mounted) return;
//
//     result.fold(
//       onSuccess: (info) {
//         if (info.isValid) {
//           if (info.businessName.isNotEmpty) {
//             _pharmacyNameController.text = info.businessName;
//           }
//           _setStep(AuthStep.accountCreation);
//         } else if (info.status == LicenseStatus.expired) {
//           setState(() =>
//           _errorMessage = 'This license has expired. Enter a valid key.');
//         } else {
//           setState(() => _errorMessage =
//           'Invalid license key or machine mismatch.');
//         }
//       },
//       onFailure: (f) {
//         setState(() => _errorMessage = f.message);
//       },
//     );
//
//     if (mounted) setState(() => _isLoading = false);
//   }
//
//   /// Direct Login Attempt
//   Future<void> _handleLogin() async {
//     final username = _usernameController.text.trim();
//     final password = _passwordController.text;
//
//     if (username.isEmpty || password.isEmpty) {
//       setState(() => _errorMessage = 'Username and password are required.');
//       return;
//     }
//
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     final success = await widget.authController.login(username, password);
//
//     if (!mounted) return;
//
//     if (success) {
//       widget.onLoginSuccess();
//     } else {
//       // Stay on the login screen and show the error from AuthController
//       setState(() {
//         _errorMessage = widget.authController.errorMessage ??
//             'Invalid username or password.';
//         _isLoading = false;
//       });
//     }
//   }
//
//   /// Master Account Creation (First-Time Setup)
//   Future<void> _handleAccountCreation() async {
//     final pharmacyName = _pharmacyNameController.text.trim();
//     final username = _usernameController.text.trim();
//     final password = _passwordController.text;
//     final confirm = _confirmPasswordController.text;
//
//     if (pharmacyName.isEmpty || username.isEmpty || password.isEmpty) {
//       setState(() => _errorMessage = 'All fields are required.');
//       return;
//     }
//
//     if (password != confirm) {
//       setState(() => _errorMessage = 'Passwords do not match.');
//       return;
//     }
//
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     final success = await widget.authController.registerMasterAdmin(
//       pharmacyName,
//       username,
//       password,
//     );
//
//     if (success && mounted) {
//       await _checkAdminStatus();
//       _setStep(AuthStep.welcome);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Account created successfully! Please sign in to continue.'),
//           backgroundColor: AppColors.success,
//         ),
//       );
//     } else if (mounted) {
//       setState(() => _errorMessage =
//           widget.authController.errorMessage ?? 'Failed to create account.');
//     }
//
//     if (mounted) setState(() => _isLoading = false);
//   }
//
//   Widget _buildCurrentStep() {
//     switch (_currentStep) {
//       case AuthStep.welcome:
//         return _buildWelcomeView();
//       case AuthStep.activation:
//         return _buildActivationView();
//       case AuthStep.accountCreation:
//         return _buildAccountCreationView();
//       case AuthStep.login:
//         return _buildLoginView();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Row(
//         children: [
//           // LEFT PANEL — Branding
//           Expanded(
//             flex: 1,
//             child: Container(
//               color: AppColors.primary,
//               child: Center(
//                 child: Padding(
//                   padding: const EdgeInsets.all(AppSpacing.xxl),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(AppSpacing.lg),
//                         decoration: BoxDecoration(
//                           color: Colors.white.withValues(alpha: 0.15),
//                           shape: BoxShape.circle,
//                         ),
//                         child: const Icon(Icons.local_pharmacy_rounded,
//                             color: Colors.white, size: 72),
//                       ),
//                       const SizedBox(height: AppSpacing.xxl),
//                       Text(
//                         'WELCOME TO',
//                         style: AppTypography.caption.copyWith(
//                           color: Colors.white.withValues(alpha: 0.8),
//                           fontSize: 16,
//                           letterSpacing: 3,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       const SizedBox(height: 10),
//                       Text(
//                         'PHARMASUITE ERP',
//                         textAlign: TextAlign.center,
//                         style: AppTypography.display.copyWith(
//                           color: Colors.white,
//                           fontSize: 36,
//                           fontWeight: FontWeight.w900,
//                           letterSpacing: 1.5,
//                         ),
//                       ),
//                       const SizedBox(height: AppSpacing.lg),
//                       Text(
//                         'Comprehensive Pharmacy\nManagement System',
//                         textAlign: TextAlign.center,
//                         style: AppTypography.body.copyWith(
//                           color: Colors.white.withValues(alpha: 0.9),
//                           fontSize: 15,
//                           height: 1.5,
//                         ),
//                       ),
//                       const SizedBox(height: 60),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(Icons.shield_rounded,
//                               size: 16,
//                               color: Colors.white.withValues(alpha: 0.65)),
//                           const SizedBox(width: 8),
//                           Text(
//                             'Offline Ed25519 Verified  •  SQLite Encrypted',
//                             style: AppTypography.caption.copyWith(
//                               color: Colors.white.withValues(alpha: 0.65),
//                               fontSize: 13,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//
//           // RIGHT PANEL — Forms
//           Expanded(
//             flex: 1,
//             child: Container(
//               color: Colors.white,
//               child: Center(
//                 child: SingleChildScrollView(
//                   padding:
//                   const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
//                   child: ConstrainedBox(
//                     constraints: const BoxConstraints(maxWidth: 440),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       crossAxisAlignment: CrossAxisAlignment.stretch,
//                       children: [
//                         if (_errorMessage != null)
//                           Container(
//                             margin:
//                             const EdgeInsets.only(bottom: AppSpacing.lg),
//                             padding: const EdgeInsets.all(AppSpacing.md),
//                             decoration: BoxDecoration(
//                               color: AppColors.errorSurface,
//                               borderRadius:
//                               BorderRadius.circular(AppRadius.md),
//                               border: Border.all(
//                                   color: AppColors.errorLight
//                                       .withValues(alpha: 0.4)),
//                             ),
//                             child: Row(
//                               children: [
//                                 const Icon(Icons.error_outline,
//                                     color: AppColors.error, size: 18),
//                                 const SizedBox(width: 10),
//                                 Expanded(
//                                   child: Text(
//                                     _errorMessage!,
//                                     style: AppTypography.bodySmall.copyWith(
//                                       color: AppColors.error,
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         _buildCurrentStep(),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildWelcomeView() {
//     if (_hasAdmin == null) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Text(
//           'PharmaSuite ERP',
//           style: AppTypography.display.copyWith(fontSize: 28),
//         ),
//         const SizedBox(height: 10),
//         Text(
//           'Sign in with your existing account or set up a new installation.',
//           textAlign: TextAlign.center,
//           style: AppTypography.bodySmall
//               .copyWith(color: AppColors.textSecondary, height: 1.5),
//         ),
//         const SizedBox(height: 36),
//
//         // ── ALWAYS show Login ──
//         _SelectionCard(
//           icon: Icons.login_rounded,
//           title: 'Login',
//           subtitle: 'Sign in with your username and password.',
//           onTap: () => _setStep(AuthStep.login),
//         ),
//         const SizedBox(height: 16),
//
//         // ── ALWAYS show Create Account ──
//         _SelectionCard(
//           icon: Icons.person_add_alt_1_rounded,
//           title: 'Create Account',
//           subtitle: 'First time? Activate your license and set up admin.',
//           onTap: () => _setStep(AuthStep.activation),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildActivationView() {
//     final machineId = DeviceFingerprint.generate();
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Row(
//           children: [
//             IconButton(
//               icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
//               onPressed: () => _setStep(AuthStep.welcome),
//               padding: EdgeInsets.zero,
//               constraints: const BoxConstraints(),
//             ),
//             const SizedBox(width: 8),
//             Text('Activate License', style: AppTypography.pageTitle),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Text(
//           'Paste your signed license JSON payload below.',
//           style: AppTypography.bodySmall
//               .copyWith(color: AppColors.textSecondary),
//         ),
//         const SizedBox(height: 16),
//         Container(
//           padding: const EdgeInsets.all(AppSpacing.md),
//           decoration: BoxDecoration(
//             color: AppColors.primary.withValues(alpha: 0.05),
//             borderRadius: BorderRadius.circular(AppRadius.md),
//             border:
//             Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Your Machine ID (send to Admin):',
//                   style: AppTypography.caption
//                       .copyWith(fontWeight: FontWeight.bold)),
//               const SizedBox(height: 4),
//               Row(
//                 children: [
//                   Expanded(
//                     child: SelectableText(
//                       machineId,
//                       style: const TextStyle(
//                         fontFamily: 'monospace',
//                         fontWeight: FontWeight.bold,
//                         color: AppColors.primary,
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.copy_rounded,
//                         size: 18, color: AppColors.primary),
//                     tooltip: 'Copy Machine ID',
//                     onPressed: () {
//                       Clipboard.setData(ClipboardData(text: machineId));
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(
//                             content: Text('Machine ID copied to clipboard!')),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         TextField(
//           controller: _payloadController,
//           maxLines: 5,
//           style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
//           decoration: InputDecoration(
//             labelText: 'License Payload (JSON or Base64)',
//             hintText: '{\n  "licenseVersion": 1,\n  "signature": "..."\n}',
//             filled: true,
//             fillColor: Colors.grey.shade50,
//             border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(AppRadius.md)),
//           ),
//         ),
//         const SizedBox(height: 20),
//         ElevatedButton(
//           onPressed: _isLoading ? null : _handleActivation,
//           style: ElevatedButton.styleFrom(
//             minimumSize: const Size.fromHeight(48),
//             backgroundColor: AppColors.primary,
//             foregroundColor: Colors.white,
//           ),
//           child: _isLoading
//               ? const SizedBox(
//             width: 22,
//             height: 22,
//             child: CircularProgressIndicator(
//                 strokeWidth: 2.5, color: Colors.white),
//           )
//               : const Text('Verify Digital Signature',
//               style:
//               TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildAccountCreationView() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Text('Create Master Account', style: AppTypography.pageTitle),
//         const SizedBox(height: 8),
//         Text(
//           'License verified! Set up your pharmacy and admin login.',
//           style: AppTypography.bodySmall
//               .copyWith(color: AppColors.textSecondary),
//         ),
//         const SizedBox(height: 24),
//         _buildTextField(
//           controller: _pharmacyNameController,
//           label: 'Pharmacy Name',
//           icon: Icons.store_rounded,
//           hint: 'e.g. HealthCare Pharmacy',
//         ),
//         const SizedBox(height: 14),
//         _buildTextField(
//           controller: _usernameController,
//           label: 'Admin Username',
//           icon: Icons.person_outline,
//           hint: 'e.g. admin',
//         ),
//         const SizedBox(height: 14),
//         _buildTextField(
//           controller: _passwordController,
//           label: 'Password',
//           icon: Icons.lock_outline,
//           isPassword: true,
//           obscureState: _obscurePassword,
//           onToggleObscure: () =>
//               setState(() => _obscurePassword = !_obscurePassword),
//         ),
//         const SizedBox(height: 14),
//         _buildTextField(
//           controller: _confirmPasswordController,
//           label: 'Confirm Password',
//           icon: Icons.lock_reset_rounded,
//           isPassword: true,
//           obscureState: _obscureConfirmPassword,
//           onToggleObscure: () => setState(
//                   () => _obscureConfirmPassword = !_obscureConfirmPassword),
//         ),
//         const SizedBox(height: 28),
//         ElevatedButton(
//           onPressed: _isLoading ? null : _handleAccountCreation,
//           style: ElevatedButton.styleFrom(
//             minimumSize: const Size.fromHeight(48),
//             backgroundColor: AppColors.primary,
//             foregroundColor: Colors.white,
//           ),
//           child: _isLoading
//               ? const SizedBox(
//             width: 22,
//             height: 22,
//             child: CircularProgressIndicator(
//                 strokeWidth: 2.5, color: Colors.white),
//           )
//               : const Text('Complete Setup',
//               style:
//               TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
//         ),
//       ],
//     );
//   }
//
//   // ── TERMINAL LOGIN VIEW ──────────────────────────────────────────
//   Widget _buildLoginView() {
//     final isLicenseError = widget.authController.isLicenseError;
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Row(
//           children: [
//             IconButton(
//               icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
//               onPressed: () => _setStep(AuthStep.welcome),
//               padding: EdgeInsets.zero,
//               constraints: const BoxConstraints(),
//             ),
//             const SizedBox(width: 8),
//             Text('Terminal Sign In', style: AppTypography.pageTitle),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Text(
//           'Enter your credentials to open the workspace.',
//           style: AppTypography.bodySmall
//               .copyWith(color: AppColors.textSecondary),
//         ),
//         const SizedBox(height: 28),
//         _buildTextField(
//           controller: _usernameController,
//           label: 'Username',
//           icon: Icons.person_outline,
//         ),
//         const SizedBox(height: 14),
//         _buildTextField(
//           controller: _passwordController,
//           label: 'Password',
//           icon: Icons.lock_outline,
//           isPassword: true,
//           obscureState: _obscurePassword,
//           onToggleObscure: () =>
//               setState(() => _obscurePassword = !_obscurePassword),
//           onSubmitted: (_) => _handleLogin(),
//         ),
//         const SizedBox(height: 28),
//         ElevatedButton(
//           onPressed: _isLoading ? null : _handleLogin,
//           style: ElevatedButton.styleFrom(
//             minimumSize: const Size.fromHeight(48),
//             backgroundColor: AppColors.primary,
//             foregroundColor: Colors.white,
//           ),
//           child: _isLoading
//               ? const SizedBox(
//             width: 22,
//             height: 22,
//             child: CircularProgressIndicator(
//                 strokeWidth: 2.5, color: Colors.white),
//           )
//               : const Text('Sign In to Terminal',
//               style:
//               TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
//         ),
//
//         // ── Direct "Go to License Manager" Card on Login Failure ──
//         if (isLicenseError) ...[
//           const SizedBox(height: 20),
//           Container(
//             padding: const EdgeInsets.all(AppSpacing.md),
//             decoration: BoxDecoration(
//               color: Colors.red.shade50,
//               borderRadius: BorderRadius.circular(AppRadius.md),
//               border: Border.all(color: Colors.red.shade200),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 Row(
//                   children: [
//                     const Icon(Icons.warning_amber_rounded,
//                         color: Colors.red, size: 22),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: Text(
//                         'Your license has expired or is invalid.',
//                         style: AppTypography.bodySmall.copyWith(
//                           color: Colors.red.shade900,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 12),
//                 ElevatedButton.icon(
//                   onPressed: _openLicenseScreen,
//                   icon: const Icon(Icons.verified_user_rounded, size: 18),
//                   label: const Text('Go to License Manager'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.error,
//                     foregroundColor: Colors.white,
//                     minimumSize: const Size.fromHeight(42),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ],
//     );
//   }
//
//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     required IconData icon,
//     String? hint,
//     bool isPassword = false,
//     bool obscureState = false,
//     VoidCallback? onToggleObscure,
//     ValueChanged<String>? onSubmitted,
//   }) {
//     return TextField(
//       controller: controller,
//       obscureText: isPassword ? obscureState : false,
//       onSubmitted: onSubmitted,
//       style: AppTypography.body,
//       decoration: InputDecoration(
//         labelText: label,
//         hintText: hint,
//         prefixIcon: Icon(icon, size: 20),
//         filled: true,
//         fillColor: Colors.grey.shade50,
//         contentPadding:
//         const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(AppRadius.md),
//           borderSide: BorderSide(color: Colors.grey.shade300),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(AppRadius.md),
//           borderSide: BorderSide(color: Colors.grey.shade300),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(AppRadius.md),
//           borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
//         ),
//         suffixIcon: isPassword
//             ? IconButton(
//           icon: Icon(
//             obscureState
//                 ? Icons.visibility_outlined
//                 : Icons.visibility_off_outlined,
//             size: 18,
//           ),
//           onPressed: onToggleObscure,
//         )
//             : null,
//       ),
//     );
//   }
// }
//
// class _SelectionCard extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final String subtitle;
//   final VoidCallback onTap;
//
//   const _SelectionCard({
//     required this.icon,
//     required this.title,
//     required this.subtitle,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.white,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(AppRadius.lg),
//         side: BorderSide(color: Colors.grey.shade300),
//       ),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(AppRadius.lg),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(
//               horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
//           child: Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: AppColors.primary.withValues(alpha: 0.1),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(icon, color: AppColors.primary, size: 26),
//               ),
//               const SizedBox(width: AppSpacing.md),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       style: AppTypography.sectionTitle.copyWith(
//                         color: AppColors.primary,
//                         fontSize: 16,
//                       ),
//                     ),
//                     const SizedBox(height: 3),
//                     Text(
//                       subtitle,
//                       style: AppTypography.caption.copyWith(
//                         color: AppColors.textSecondary,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const Icon(Icons.chevron_right_rounded,
//                   color: AppColors.textSecondary),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/network/network_config.dart';
import '../../../settings/data/sqlite_settings_repository.dart';
import '../../../network/presentation/controllers/network_controller.dart';
import '../../../network/presentation/screens/network_settings_screen.dart';
import '../controllers/auth_controller.dart';
import '../../../licensing/data/sqlite_license_repository.dart';
import '../../../licensing/domain/device_fingerprint.dart';
import '../../../licensing/domain/license.dart';
import '../../../licensing/presentation/controllers/license_controller.dart';
import '../../../licensing/presentation/screens/license_screen.dart';

enum AuthStep { welcome, activation, accountCreation, login }

class OnboardingScreen extends StatefulWidget {
  final AuthController authController;
  final LicenseController? licenseController;
  final VoidCallback onLoginSuccess;

  /// Called when the network mode / server IP / port changed, so app.dart can
  /// rebuild the auth repository (SQLite <-> HTTP).
  final VoidCallback? onServerConfigured;

  const OnboardingScreen({
    super.key,
    required this.authController,
    required this.onLoginSuccess,
    this.licenseController,
    this.onServerConfigured,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final SqliteLicenseRepository _licenseRepo = SqliteLicenseRepository();
  AuthStep _currentStep = AuthStep.welcome;

  bool? _hasAdmin;

  final _payloadController = TextEditingController();
  final _pharmacyNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  NetworkController? _networkController;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final hasAdmin = await widget.authController.hasAnyAdminRegistered();
    if (mounted) {
      setState(() => _hasAdmin = hasAdmin);
    }
  }

  @override
  void dispose() {
    _payloadController.dispose();
    _pharmacyNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _networkController?.dispose();
    super.dispose();
  }

  void _setStep(AuthStep step) {
    setState(() {
      _currentStep = step;
      _errorMessage = null;
      _payloadController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  /// Login on the welcome screen goes straight to the login form.
  void _handleLoginTap() {
    _setStep(AuthStep.login);
  }

  /// Opens the same Network & LAN page that exists in Settings.
  Future<void> _openNetworkSettings() async {
    _networkController ??=
        NetworkController(settingsRepo: SqliteSettingsRepository());

    final cfg = NetworkConfig.instance;
    final modeBefore = cfg.mode;
    final ipBefore = cfg.serverIp;
    final portBefore = cfg.port;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: const Text('LAN & Network Connection'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child:
                  NetworkSettingsScreen(controller: _networkController!),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!mounted) return;

    // If mode / IP / port changed, let app.dart rebuild the auth repository.
    final c = NetworkConfig.instance;
    if (c.mode != modeBefore ||
        c.serverIp != ipBefore ||
        c.port != portBefore) {
      widget.onServerConfigured?.call();
    }

    widget.authController.clearError();
    setState(() => _errorMessage = null);
  }

  /// Opens the License Manager directly when requested from the login screen
  Future<void> _openLicenseScreen() async {
    final controller = widget.licenseController ??
        LicenseController(repository: _licenseRepo);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: const Text('License Management'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          body: SafeArea(
            child: LicenseScreen(
              controller: controller,
              onLicenseActivated: () {
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ),
      ),
    );

    if (!mounted) return;

    widget.authController.clearError();
    setState(() {
      _errorMessage = null;
    });
  }

  /// Initial License Activation (First-Time Setup)
  Future<void> _handleActivation() async {
    final payload = _payloadController.text.trim();
    if (payload.isEmpty) {
      setState(() => _errorMessage = 'Please paste the license JSON payload.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _licenseRepo.activateLicense(payload);
    if (!mounted) return;

    result.fold(
      onSuccess: (info) {
        if (info.isValid) {
          if (info.businessName.isNotEmpty) {
            _pharmacyNameController.text = info.businessName;
          }
          _setStep(AuthStep.accountCreation);
        } else if (info.status == LicenseStatus.expired) {
          setState(() =>
          _errorMessage = 'This license has expired. Enter a valid key.');
        } else {
          setState(
                  () => _errorMessage = 'Invalid license key or machine mismatch.');
        }
      },
      onFailure: (f) {
        setState(() => _errorMessage = f.message);
      },
    );

    if (mounted) setState(() => _isLoading = false);
  }

  /// Direct Login Attempt
  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Username and password are required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await widget.authController.login(username, password);

    if (!mounted) return;

    if (success) {
      widget.onLoginSuccess();
    } else {
      setState(() {
        _errorMessage = widget.authController.errorMessage ??
            'Invalid username or password.';
        _isLoading = false;
      });
    }
  }

  /// Master Account Creation (First-Time Setup)
  Future<void> _handleAccountCreation() async {
    final pharmacyName = _pharmacyNameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (pharmacyName.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'All fields are required.');
      return;
    }

    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await widget.authController.registerMasterAdmin(
      pharmacyName,
      username,
      password,
    );

    if (success && mounted) {
      await _checkAdminStatus();
      _setStep(AuthStep.welcome);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text('Account created successfully! Please sign in to continue.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      setState(() => _errorMessage =
          widget.authController.errorMessage ?? 'Failed to create account.');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case AuthStep.welcome:
        return _buildWelcomeView();
      case AuthStep.activation:
        return _buildActivationView();
      case AuthStep.accountCreation:
        return _buildAccountCreationView();
      case AuthStep.login:
        return _buildLoginView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // LEFT PANEL — Branding
          Expanded(
            flex: 1,
            child: Container(
              color: AppColors.primary,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_pharmacy_rounded,
                            color: Colors.white, size: 72),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'WELCOME TO',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 16,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'PHARMASUITE ERP',
                        textAlign: TextAlign.center,
                        style: AppTypography.display.copyWith(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Comprehensive Pharmacy\nManagement System',
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 60),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.65)),
                          const SizedBox(width: 8),
                          Text(
                            'Offline Ed25519 Verified  •  SQLite Encrypted',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // RIGHT PANEL — Forms
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null)
                          Container(
                            margin:
                            const EdgeInsets.only(bottom: AppSpacing.lg),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.errorSurface,
                              borderRadius:
                              BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                  color: AppColors.errorLight
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.error, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _buildCurrentStep(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeView() {
    if (_hasAdmin == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'PharmaSuite ERP',
          style: AppTypography.display.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 10),
        Text(
          'Sign in with your existing account or set up a new installation.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 36),

        // ── Login ──
        _SelectionCard(
          icon: Icons.login_rounded,
          title: 'Login',
          subtitle: 'Sign in with your username and password.',
          onTap: _handleLoginTap,
        ),
        const SizedBox(height: 16),

        // ── Create Account ──
        _SelectionCard(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Create Account',
          subtitle: 'First time? Activate your license and set up admin.',
          onTap: () => _setStep(AuthStep.activation),
        ),
      ],
    );
  }

  Widget _buildActivationView() {
    final machineId = DeviceFingerprint.generate();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon:
              const Icon(Icons.arrow_back, color: AppColors.textSecondary),
              onPressed: () => _setStep(AuthStep.welcome),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Text('Activate License', style: AppTypography.pageTitle),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Paste your signed license JSON payload below.',
          style:
          AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Machine ID (send to Admin):',
                  style: AppTypography.caption
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      machineId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        size: 18, color: AppColors.primary),
                    tooltip: 'Copy Machine ID',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: machineId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Machine ID copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _payloadController,
          maxLines: 5,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            labelText: 'License Payload (JSON or Base64)',
            hintText: '{\n  "licenseVersion": 1,\n  "signature": "..."\n}',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleActivation,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          )
              : const Text('Verify Digital Signature',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildAccountCreationView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Create Master Account', style: AppTypography.pageTitle),
        const SizedBox(height: 8),
        Text(
          'License verified! Set up your pharmacy and admin login.',
          style:
          AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _pharmacyNameController,
          label: 'Pharmacy Name',
          icon: Icons.store_rounded,
          hint: 'e.g. HealthCare Pharmacy',
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _usernameController,
          label: 'Admin Username',
          icon: Icons.person_outline,
          hint: 'e.g. admin',
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          isPassword: true,
          obscureState: _obscurePassword,
          onToggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_reset_rounded,
          isPassword: true,
          obscureState: _obscureConfirmPassword,
          onToggleObscure: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleAccountCreation,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          )
              : const Text('Complete Setup',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ── TERMINAL LOGIN VIEW ────────────────────────────────────────────
  Widget _buildLoginView() {
    final isLicenseError = widget.authController.isLicenseError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon:
              const Icon(Icons.arrow_back, color: AppColors.textSecondary),
              onPressed: () => _setStep(AuthStep.welcome),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Text('Terminal Sign In', style: AppTypography.pageTitle),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your credentials to open the workspace.',
          style:
          AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),

        // Show which server we're connected to (client mode only)
        if (NetworkConfig.instance.isClient) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border:
              Border.all(color: AppColors.success.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_done_rounded,
                    color: AppColors.success, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Connected to server: ${NetworkConfig.instance.baseUrl}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),
        _buildTextField(
          controller: _usernameController,
          label: 'Username',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          isPassword: true,
          obscureState: _obscurePassword,
          onToggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          )
              : const Text('Sign In to Terminal',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),

        // ── License error card ──
        if (isLicenseError) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your license has expired or is invalid.',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _openLicenseScreen,
                  icon: const Icon(Icons.verified_user_rounded, size: 18),
                  label: const Text('Go to License Manager'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── LAN & Network Connection option ──
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        _SelectionCard(
          icon: Icons.lan_rounded,
          title: 'LAN & Network Connection',
          subtitle: 'Set up server / client mode and connect over your network.',
          onTap: _openNetworkSettings,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isPassword = false,
    bool obscureState = false,
    VoidCallback? onToggleObscure,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? obscureState : false,
      onSubmitted: onSubmitted,
      style: AppTypography.body,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            obscureState
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
          ),
          onPressed: onToggleObscure,
        )
            : null,
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.sectionTitle.copyWith(
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}