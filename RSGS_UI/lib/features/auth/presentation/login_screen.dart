import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/theme/typography_extensions.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  final _usernameController = TextEditingController(text: 'usama_makhlouf');
  final _passwordController = TextEditingController(text: 'Usama@123456789');
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final error = await ref.read(authProvider.notifier).login(
            _usernameController.text.trim(),
            _passwordController.text,
            rememberMe: _rememberMe,);

      if (!mounted) return;

      if (error != null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.tr(ref)),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'error'.tr(ref)}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    _showGlassDialog(
      title: 'forgot_password'.tr(ref),
      content: 'please_contact_admin_reset'.tr(ref),
      actions: [
        _buildDialogButton(
          label: 'contact_admin'.tr(ref),
          onPressed: () {
            Navigator.pop(context);
            _contactAdmin();
          },
          isPrimary: true,
        ),
        const SizedBox(height: 12),
        _buildDialogButton(
          label: 'close'.tr(ref),
          onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
      ],
    );
  }

  void _showGlassDialog({
    required String title,
    required String content,
    required List<Widget> actions,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLogo(height: 160),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: context.headlineSmall?.white,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      content,
                      style: context.bodyMedium?.withColor(AppColors.white.withValues(alpha: 0.6)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ...actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogButton({
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isPrimary ? AppColors.primaryTeal : AppColors.white.withValues(alpha: 0.08),
        boxShadow: isPrimary ? [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ] : null,
        border: Border.all(
          color: isPrimary ? Colors.transparent : AppColors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              label,
              style: context.labelLarge?.copyWith(
                color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _contactAdmin() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: AppConstants.companyEmail,
      queryParameters: {
        'subject': 'Password Reset / Account Access Request',
      },
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_email_client'.tr(ref))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'error'.tr(ref)}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/login.jpg',
              fit: BoxFit.cover,
            ),
          ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryTeal.withValues(alpha: 0.85),
                    AppColors.black.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.8],
                ),
              ),
            ),
          ),

          _buildDecorativeElements(size),

          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = ResponsiveBreakpoints.of(context).isMobile;
                  final screenWidth = MediaQuery.of(context).size.width;
                  
                  // Use a more robust check for when to show the horizontal layout
                  final showHorizontalLayout = !isMobile && screenWidth > 850;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 40, 
                      vertical: 20
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 40,
                      ),
                      child: Center(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: showHorizontalLayout ? 1100 : 500
                              ),
                              child: showHorizontalLayout ? _buildDesktopLayout() : _buildMobileForm(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(child: _buildLanguageButton()),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageButton() {
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language_rounded,
                size: 18,
                color: AppColors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'English' : 'العربية',
                style: context.labelLarge?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileForm() {
    final screenHeight = MediaQuery.of(context).size.height;
    final logoHeight = (screenHeight * 0.28).clamp(180.0, 320.0);

    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLogo(height: logoHeight),
            const SizedBox(height: 20),
            Text(
              'welcome_back'.tr(ref),
              style: context.headlineSmall?.white,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'sign_in_subtitle'.tr(ref),
              style: context.bodyMedium?.withColor(AppColors.white.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildLoginForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final screenHeight = MediaQuery.of(context).size.height;
    final logoHeight = (screenHeight * 0.4).clamp(300.0, 480.0);

    return _GlassCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(40.0),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.03),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    bottomLeft: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(height: logoHeight),
                    // const SizedBox(height: 32),
                    // Text(
                    //   'Red Sea Green Solutions',
                    //   style: context.headlineSmall?.bold.white,
                    //   textAlign: TextAlign.center,
                    // ),
                  ],
                ),
              ),
            ),
            
            Container(
              width: 1.5,
              color: AppColors.white.withValues(alpha: 0.1),
            ),
  
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'welcome_back'.tr(ref),
                          style: context.headlineLarge?.white,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'sign_in_subtitle'.tr(ref),
                          style: context.bodyLarge?.withColor(AppColors.white.withValues(alpha: 0.6)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        _buildLoginForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo({double height = 220, double glowOpacity = 0.15}) {
    return Hero(
      tag: 'logo',
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryTeal.withValues(alpha: glowOpacity),
              blurRadius: height * 0.5,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/logo.png',
          height: height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    const textColor = AppColors.white;
    final secondaryColor = AppColors.white.withValues(alpha: 0.6);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLabel('username'.tr(ref), textColor),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _usernameController,
            hint: 'username_hint'.tr(ref),
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 20),
          _buildLabel('password'.tr(ref), textColor),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _passwordController,
            hint: 'password_hint'.tr(ref),
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                      side: BorderSide(color: secondaryColor),
                      activeColor: AppColors.primaryTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'remember_me'.tr(ref),
                    style: context.bodySmall?.withColor(textColor.withValues(alpha: 0.8)),
                  ),
                ],
              ),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentGold,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'forgot_password'.tr(ref), 
                  style: context.labelLarge?.withColor(AppColors.accentGold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSubmitButton(),
          const SizedBox(height: 20),
          _buildFooter(secondaryColor),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: context.labelLarge?.withColor(color.withValues(alpha: 0.8)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: context.bodyLarge?.white,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.white.withValues(alpha: 0.05),
        hintText: hint,
        hintStyle: context.bodyMedium?.withColor(AppColors.white.withValues(alpha: 0.3)),
        prefixIcon: Icon(
          icon,
          size: 22,
          color: AppColors.white.withValues(alpha: 0.4),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 18,
                  color: AppColors.white.withValues(alpha: 0.4),
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'required'.tr(ref) : null,
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: _isLoading ? null : _login,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 3),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login_rounded, size: 20, color: AppColors.white),
                  const SizedBox(width: 12),
                  Text(
                    'sign_in'.tr(ref),
                    style: context.labelLarge?.white,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFooter(Color color) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 0,
      children: [
        Text(
          'no_account'.tr(ref),
          style: context.bodySmall?.withColor(color),
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: _contactAdmin,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'contact_admin'.tr(ref),
            style: context.labelLarge?.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildDecorativeElements(Size size) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final circleSizeScale = isMobile ? 0.3 : 1.0;

    return Stack(
      children: [
        Positioned(
          top: -size.height * 0.2,
          right: -size.width * 0.1,
          child: _BlurCircle(
            size: size.height * 0.6 * circleSizeScale, 
            color: AppColors.primaryTeal.withValues(alpha: 0.1)
          ),
        ),
        Positioned(
          bottom: -size.height * 0.1,
          left: -size.width * 0.05,
          child: _BlurCircle(
            size: size.height * 0.4 * circleSizeScale, 
            color: AppColors.accentGold.withValues(alpha: 0.05)
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final radius = ResponsiveBreakpoints.of(context).isMobile ? 24.0 : 32.0;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
