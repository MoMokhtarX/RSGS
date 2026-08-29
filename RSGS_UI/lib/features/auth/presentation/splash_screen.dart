import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/typography_extensions.dart';
import '../data/auth_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _bgController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bgScaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Main Entry Animations
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
    ));

    // Subtle Background Zoom
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _bgScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeInOut),
    );

    // Pulse Animation for Logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mainController.forward().then((_) {
      _pulseController.repeat(reverse: true);
    });

    // Navigation logic
    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        final authState = ref.read(authProvider);
        if (authState.isAuthenticated) {
          context.go('/dashboard');
        } else {
          context.go('/login');
        }
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background with Zoom Effect
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgScaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _bgScaleAnimation.value,
                  child: Image.asset(
                    'assets/images/login.jpg',
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),

          // Gradient Overlay
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
              child: Stack(
                children: [
                  Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: _GlassCard(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _pulseAnimation.value,
                                        child: _buildLogo(
                                          height: 260,
                                          glowOpacity: 0.15 + (_pulseAnimation.value - 1.0) * 2,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 48),
                                  const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      color: AppColors.white,
                                      strokeWidth: 2.5,
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
                  
                  // Version Info at Bottom
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: 0.4,
                      child: Text(
                        'Version 1.0.0',
                        style: context.bodySmall?.white,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo({double height = 220, double glowOpacity = 0.2}) {
    return Hero(
      tag: 'logo',
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryTeal.withValues(alpha: glowOpacity),
              blurRadius: height * 0.6,
              spreadRadius: 4,
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
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.3),
                blurRadius: 50,
                offset: const Offset(0, 25),
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
