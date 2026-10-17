// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import '../../../../core/theme/app_colors.dart';
// import '../../../../core/theme/app_spacing.dart';
// import '../../../../core/theme/app_radius.dart';
// import '../../../../core/theme/app_typography.dart';
// import '../controllers/auth_controller.dart';
// import '../../../licensing/data/mock_license_repository.dart';
// import '../../../licensing/domain/license.dart';
//
// enum AuthStep { welcome, activation, accountCreation, login, renewal }
//
// class OnboardingScreen extends StatefulWidget {
//   final AuthController authController;
//   final VoidCallback onLoginSuccess;
//
//   const OnboardingScreen({
//     super.key,
//     required this.authController,
//     required this.onLoginSuccess,
//   });
//
//   @override
//   State<OnboardingScreen> createState() => _OnboardingScreenState();
// }
//
// class _OnboardingScreenState extends State<OnboardingScreen> {
//   final MockLicenseRepository _licenseRepo = MockLicenseRepository();
//   AuthStep _currentStep = AuthStep.welcome;
//
//   bool? _hasAdmin; // Tracks whether an admin account exists in local database
//
//   final _keyController = TextEditingController();
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
//   final List<Map<String, String>> _testKeys = const [
//     {
//       'title': 'Lifetime Partner',
//       'key': 'TEST-LIFETIME-KEY',
//       'desc': 'Never expires, unlocks all features',
//     },
//     {
//       'title': '1 Year Subscription',
//       'key': 'TEST-ACTIVE-YEARLY',
//       'desc': 'Valid for 365 days',
//     },
//     {
//       'title': '2 Days Trial',
//       'key': 'TEST-2DAYS-TRIAL',
//       'desc': 'Expires in 48 hours',
//     },
//     {
//       'title': 'Expired License',
//       'key': 'TEST-EXPIRED-DEMO',
//       'desc': 'Triggers expired block immediately',
//     },
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _checkAdminStatus();
//   }
//
//   /// Checks if any admin is registered in SQLite
//   Future<void> _checkAdminStatus() async {
//     final hasAdmin = await widget.authController.hasAnyAdminRegistered();
//     if (mounted) {
//       setState(() {
//         _hasAdmin = hasAdmin;
//       });
//     }
//   }
//
//   @override
//   void dispose() {
//     _keyController.dispose();
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
//       _keyController.clear();
//       _passwordController.clear();
//       _confirmPasswordController.clear();
//     });
//   }
//
//   /// 1. Handle License Activation (First time or Renewal)
//   Future<void> _handleActivation() async {
//     final key = _keyController.text.trim();
//     if (key.isEmpty) {
//       setState(() => _errorMessage = 'Please enter a license key.');
//       return;
//     }
//
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     final result = await _licenseRepo.activateLicense(key);
//     if (!mounted) return;
//
//     result.fold(
//       onSuccess: (info) {
//         if (info.status == LicenseStatus.active ||
//             info.status == LicenseStatus.trial) {
//           if (_currentStep == AuthStep.renewal) {
//             // Renewal successful -> Proceed into app
//             widget.onLoginSuccess();
//           } else {
//             // Fresh installation -> Proceed to Account Creation
//             _setStep(AuthStep.accountCreation);
//           }
//         } else if (info.status == LicenseStatus.expired) {
//           setState(() => _errorMessage =
//           'This license key is already expired. Please enter an active key.');
//         } else {
//           setState(() =>
//           _errorMessage = 'Invalid or unrecognized license key.');
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
//   /// 2. Handle Master Account Creation
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
//       await _checkAdminStatus(); // Refresh admin status (now true)
//       _setStep(AuthStep.welcome); // Go back to welcome screen (shows Terminal Login)
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
//   /// 3. Handle Terminal Login
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
//     if (success && mounted) {
//       final licResult = await _licenseRepo.getLicenseInfo();
//       if (!mounted) return;
//
//       licResult.fold(
//         onSuccess: (info) {
//           if (info.status == LicenseStatus.expired) {
//             _errorMessage = 'Your license has expired. Please enter a valid activation key to unlock workspace.';
//             _setStep(AuthStep.renewal);
//           } else if (info.status == LicenseStatus.active ||
//               info.status == LicenseStatus.trial) {
//             widget.onLoginSuccess();
//           } else {
//             _setStep(AuthStep.activation);
//           }
//         },
//         onFailure: (_) {
//           widget.onLoginSuccess();
//         },
//       );
//     } else if (mounted) {
//       setState(() => _errorMessage =
//           widget.authController.errorMessage ?? 'Invalid username or password.');
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
//       case AuthStep.renewal:
//         return _buildRenewalView();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Row(
//         children: [
//           // ════════════════════════════════════════════════════
//           // LEFT HALF — Solid Green Branding
//           // ════════════════════════════════════════════════════
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
//                         child: const Icon(
//                           Icons.local_pharmacy_rounded,
//                           color: Colors.white,
//                           size: 72,
//                         ),
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
//                             'Offline-first  •  SQLite Encrypted',
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
//           // ════════════════════════════════════════════════════
//           // RIGHT HALF — Pure White Forms
//           // ════════════════════════════════════════════════════
//           Expanded(
//             flex: 1,
//             child: Container(
//               color: Colors.white,
//               child: Center(
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
//                   child: ConstrainedBox(
//                     constraints: const BoxConstraints(maxWidth: 440),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       crossAxisAlignment: CrossAxisAlignment.stretch,
//                       children: [
//                         if (_errorMessage != null)
//                           Container(
//                             margin: const EdgeInsets.only(bottom: AppSpacing.lg),
//                             padding: const EdgeInsets.all(AppSpacing.md),
//                             decoration: BoxDecoration(
//                               color: AppColors.errorSurface,
//                               borderRadius: BorderRadius.circular(AppRadius.md),
//                               border: Border.all(
//                                 color: AppColors.errorLight.withValues(alpha: 0.4),
//                               ),
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
//   // ── 1. WELCOME VIEW ──────────────────────────────────────────
//   Widget _buildWelcomeView() {
//     if (_hasAdmin == null) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     final isFreshInstall = !_hasAdmin!;
//
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Text(
//           isFreshInstall ? 'System Setup' : 'Terminal Portal',
//           style: AppTypography.display.copyWith(fontSize: 28),
//         ),
//         const SizedBox(height: 10),
//         Text(
//           isFreshInstall
//               ? 'Welcome! Click below to activate your license and set up your pharmacy account.'
//               : 'Welcome back! Click below to sign in to your pharmacy terminal.',
//           textAlign: TextAlign.center,
//           style: AppTypography.bodySmall
//               .copyWith(color: AppColors.textSecondary, height: 1.5),
//         ),
//         const SizedBox(height: 36),
//
//         // Show ONLY "Create Account" on Fresh Install
//         if (isFreshInstall)
//           _SelectionCard(
//             icon: Icons.person_add_alt_1_rounded,
//             title: 'Create Account',
//             subtitle: 'First time installation? Activate license & set up.',
//             onTap: () => _setStep(AuthStep.activation),
//           ),
//
//         // Show ONLY "Terminal Login" if an Account Exists
//         if (!isFreshInstall)
//           _SelectionCard(
//             icon: Icons.login_rounded,
//             title: 'Terminal Login',
//             subtitle: 'Sign in to access sales, inventory, and accounts.',
//             onTap: () => _setStep(AuthStep.login),
//           ),
//       ],
//     );
//   }
//
//   // ── 2. ACTIVATION VIEW ───────────────────────────────────────
//   Widget _buildActivationView() {
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
//           'Enter your activation key to unlock the system.',
//           style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
//         ),
//         const SizedBox(height: 24),
//         _buildTextField(
//           controller: _keyController,
//           label: 'License Key',
//           icon: Icons.key_rounded,
//           hint: 'e.g. TEST-LIFETIME-KEY',
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
//             child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
//           )
//               : const Text('Verify & Activate Key',
//               style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
//         ),
//         const SizedBox(height: 28),
//
//         // Test Keys Helper Box
//         Container(
//           padding: const EdgeInsets.all(AppSpacing.md),
//           decoration: BoxDecoration(
//             color: Colors.grey.shade50,
//             borderRadius: BorderRadius.circular(AppRadius.md),
//             border: Border.all(color: Colors.grey.shade300),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Test Keys (tap to fill)',
//                 style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, fontSize: 11),
//               ),
//               const SizedBox(height: 10),
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: _testKeys.map((tk) {
//                   return ActionChip(
//                     backgroundColor: AppColors.primary.withValues(alpha: 0.1),
//                     side: BorderSide.none,
//                     label: Text(tk['key']!,
//                         style: TextStyle(
//                             fontSize: 11,
//                             color: AppColors.primary.withValues(alpha: 0.9),
//                             fontWeight: FontWeight.bold)),
//                     onPressed: () {
//                       _keyController.text = tk['key']!;
//                       Clipboard.setData(ClipboardData(text: tk['key']!));
//                     },
//                   );
//                 }).toList(),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   // ── 3. ACCOUNT CREATION VIEW ─────────────────────────────────
//   Widget _buildAccountCreationView() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Text('Create Master Account', style: AppTypography.pageTitle),
//         const SizedBox(height: 8),
//         Text(
//           'License verified! Set up your pharmacy and admin login.',
//           style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
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
//           onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
//         ),
//         const SizedBox(height: 14),
//         _buildTextField(
//           controller: _confirmPasswordController,
//           label: 'Confirm Password',
//           icon: Icons.lock_reset_rounded,
//           isPassword: true,
//           obscureState: _obscureConfirmPassword,
//           onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
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
//             child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
//           )
//               : const Text('Complete Setup',
//               style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
//         ),
//       ],
//     );
//   }
//
//   // ── 4. LOGIN VIEW ────────────────────────────────────────────
//   Widget _buildLoginView() {
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
//           style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
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
//           onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
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
//             child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
//           )
//               : const Text('Sign In to Terminal',
//               style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
//         ),
//       ],
//     );
//   }
//
//   // ── 5. RENEWAL VIEW ──────────────────────────────────────────
//   Widget _buildRenewalView() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Row(
//           children: [
//             IconButton(
//               icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
//               onPressed: () {
//                 widget.authController.logout();
//                 _setStep(AuthStep.welcome);
//               },
//               padding: EdgeInsets.zero,
//               constraints: const BoxConstraints(),
//               tooltip: 'Sign Out',
//             ),
//             const SizedBox(width: 8),
//             Text('License Renewal', style: AppTypography.pageTitle),
//           ],
//         ),
//         const SizedBox(height: 16),
//         Container(
//           padding: const EdgeInsets.all(AppSpacing.md),
//           decoration: BoxDecoration(
//             color: Colors.red.shade50,
//             borderRadius: BorderRadius.circular(AppRadius.md),
//             border: Border.all(color: Colors.red.shade200),
//           ),
//           child: Row(
//             children: [
//               const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Text(
//                   'Your license has expired. Enter a new key to renew and unlock workspace access.',
//                   style: AppTypography.bodySmall.copyWith(
//                     color: Colors.red.shade900,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 24),
//         _buildTextField(
//           controller: _keyController,
//           label: 'Renewal Key',
//           icon: Icons.autorenew_rounded,
//           hint: 'Enter new activation key',
//         ),
//         const SizedBox(height: 20),
//         Wrap(
//           spacing: 8,
//           runSpacing: 8,
//           children: _testKeys.map((tk) {
//             return ActionChip(
//               backgroundColor: AppColors.primary.withValues(alpha: 0.1),
//               side: BorderSide.none,
//               label: Text(tk['key']!, style: const TextStyle(fontSize: 11)),
//               onPressed: () {
//                 _keyController.text = tk['key']!;
//                 Clipboard.setData(ClipboardData(text: tk['key']!));
//               },
//             );
//           }).toList(),
//         ),
//         const SizedBox(height: 24),
//         ElevatedButton(
//           onPressed: _isLoading ? null : _handleActivation,
//           style: ElevatedButton.styleFrom(
//             minimumSize: const Size.fromHeight(48),
//             backgroundColor: AppColors.error,
//             foregroundColor: Colors.white,
//           ),
//           child: _isLoading
//               ? const SizedBox(
//             width: 22,
//             height: 22,
//             child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
//           )
//               : const Text('Renew License & Open Workspace',
//               style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
//         ),
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
//         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
//             obscureState ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
//               const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
// lib/features/authentication/presentation/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/auth_controller.dart';
import '../../../licensing/data/sqlite_license_repository.dart';
import '../../../licensing/domain/device_fingerprint.dart';
import '../../../licensing/domain/license.dart';

enum AuthStep { welcome, activation, accountCreation, login, renewal }

class OnboardingScreen extends StatefulWidget {
  final AuthController authController;
  final VoidCallback onLoginSuccess;

  const OnboardingScreen({
    super.key,
    required this.authController,
    required this.onLoginSuccess,
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

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final hasAdmin = await widget.authController.hasAnyAdminRegistered();
    if (mounted) {
      setState(() {
        _hasAdmin = hasAdmin;
      });
    }
  }

  @override
  void dispose() {
    _payloadController.dispose();
    _pharmacyNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
        // info.isValid handles 'active', 'trial', 'expiringSoon', and 'offlineGrace'
        if (info.isValid) {
          if (info.businessName.isNotEmpty) {
            _pharmacyNameController.text = info.businessName;
          }
          if (_currentStep == AuthStep.renewal) {
            widget.onLoginSuccess();
          } else {
            _setStep(AuthStep.accountCreation);
          }
        } else if (info.status == LicenseStatus.expired) {
          setState(() => _errorMessage = 'This license has expired. Enter a valid key.');
        } else {
          setState(() => _errorMessage = 'Invalid license key or machine mismatch.');
        }
      },
      onFailure: (f) {
        setState(() => _errorMessage = f.message);
      },
    );

    if (mounted) setState(() => _isLoading = false);
  }

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

    if (success && mounted) {
      final licResult = await _licenseRepo.getLicenseInfo();
      if (!mounted) return;

      licResult.fold(
        onSuccess: (info) {
          if (info.status == LicenseStatus.expired) {
            _errorMessage = 'Your license has expired. Please enter a new payload to unlock.';
            _setStep(AuthStep.renewal);
          } else if (info.isValid) {
            widget.onLoginSuccess();
          } else {
            _setStep(AuthStep.activation);
          }
        },
        onFailure: (_) {
          widget.onLoginSuccess();
        },
      );
    } else if (mounted) {
      setState(() => _errorMessage =
          widget.authController.errorMessage ?? 'Invalid username or password.');
    }

    if (mounted) setState(() => _isLoading = false);
  }

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
          content: Text('Account created successfully! Please sign in to continue.'),
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
      case AuthStep.renewal:
        return _buildRenewalView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // LEFT HALF — Green Branding
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
                        child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 72),
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
                          Icon(Icons.shield_rounded, size: 16, color: Colors.white.withValues(alpha: 0.65)),
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

          // RIGHT HALF — White Forms
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.errorSurface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.errorLight.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 18),
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

    final isFreshInstall = !_hasAdmin!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isFreshInstall ? 'System Setup' : 'Terminal Portal',
          style: AppTypography.display.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 10),
        Text(
          isFreshInstall
              ? 'Welcome! Activate your signed license payload to set up your pharmacy account.'
              : 'Welcome back! Sign in to access your pharmacy workspace.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 36),

        if (isFreshInstall)
          _SelectionCard(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Create Account',
            subtitle: 'First time installation? Activate license & set up.',
            onTap: () => _setStep(AuthStep.activation),
          ),

        if (!isFreshInstall)
          _SelectionCard(
            icon: Icons.login_rounded,
            title: 'Terminal Login',
            subtitle: 'Sign in to access sales, inventory, and accounts.',
            onTap: () => _setStep(AuthStep.login),
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
              icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
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
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),

        // Machine ID Display Card
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
              Text('Your Machine ID (send to Admin):', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      machineId,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                    tooltip: 'Copy Machine ID',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: machineId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Machine ID copied to clipboard!')),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
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
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          )
              : const Text('Verify Digital Signature', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
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
          onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_reset_rounded,
          isPassword: true,
          obscureState: _obscureConfirmPassword,
          onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
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
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          )
              : const Text('Complete Setup', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildLoginView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
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
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
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
          onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
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
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          )
              : const Text('Sign In to Terminal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildRenewalView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
              onPressed: () {
                widget.authController.logout();
                _setStep(AuthStep.welcome);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Sign Out',
            ),
            const SizedBox(width: 8),
            Text('License Renewal', style: AppTypography.pageTitle),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your license has expired. Enter a new payload to renew and unlock workspace access.',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _payloadController,
          maxLines: 5,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            labelText: 'Renewal License Payload',
            hintText: 'Paste new JSON payload',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleActivation,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          )
              : const Text('Renew License & Open Workspace', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            obscureState ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
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
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}