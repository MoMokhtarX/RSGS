import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../constants/app_colors.dart';
import '../localization/app_strings.dart';
import '../localization/date_formatter.dart';
import '../theme/typography_extensions.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.borderOpacity = 0.1,
    this.blur = 10,
    this.color,
    this.padding,
    this.margin,
    this.hasShadow = true,
  });

  final Widget child;
  final double borderRadius;
  final double borderOpacity;
  final double blur;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool hasShadow;

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final effectiveColor = color ?? appTheme.glassBackground;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasShadow ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.theme.brightness == Brightness.dark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: appTheme.glassBorder,
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}



class StatCard extends ConsumerStatefulWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.color,
    this.trend,
    this.trendLabel,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color? color;
  final String? trend;
  final String? trendLabel;

  final VoidCallback? onTap;

  @override
  ConsumerState<StatCard> createState() => _StatCardState();
}

class _StatCardState extends ConsumerState<StatCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primaryTeal;
    final hasTap = widget.onTap != null;

    return MouseRegion(
      cursor: hasTap ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (!hasTap) return;
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        if (!hasTap) return;
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _isHovered ? color.withValues(alpha: 0.4) : context.borderColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered 
                    ? color.withValues(alpha: 0.1) 
                    : AppColors.black.withValues(alpha: context.theme.brightness == Brightness.dark ? 0.2 : 0.02),
                  blurRadius: _isHovered ? 40 : 20,
                  offset: _isHovered ? const Offset(0, 20) : const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(
                    widget.icon,
                    size: 100,
                    color: color.withValues(alpha: 0.03),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(widget.icon, color: color, size: 20),
                          ),
                          if (hasTap)
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: _isHovered ? color : context.appTheme.textMuted
                            ),
                        ],
                      ),
                      const Flexible(child: Spacer()),
                      Text(
                        widget.title,
                        style: context.labelMedium?.extraBold.withColor(context.appTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          widget.value,
                          style: context.headlineLarge?.black.withSize(26).withHeight(1.1),
                        ),
                      ),
                      if (widget.trend != null) ...[
                        const SizedBox(height: 12),
                        _buildTrend(widget.trend!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrend(String trend) {
    final isPositive = trend.contains('+');
    final isNegative = trend.contains('-');
    final color = isPositive
        ? AppColors.success
        : isNegative
            ? AppColors.error
            : context.onSurfaceVariant;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive
                    ? Icons.trending_up_rounded
                    : isNegative
                        ? Icons.trending_down_rounded
                        : Icons.trending_flat_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                trend,
                style: context.labelMedium?.bold.withColor(color),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.trendLabel ?? 'vs_last_month'.tr(ref),
            style: context.bodySmall?.semiBold,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}




class SectionHeader extends ConsumerWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.actionLabel,
  });

  final String title;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            title.tr(ref), 
            style: context.headlineSmall?.black.withHeight(1.1),
          ),
          const Spacer(),
          if (action != null)
            Container(
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: action, 
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel ?? 'view_all'.tr(ref),
                      style: context.labelLarge?.bold.primary,
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 14),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}



class EmptyStateWidget extends ConsumerWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: AppColors.primaryTeal.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(title.tr(ref), style: context.titleLarge?.black),
            const SizedBox(height: 12),
            Text(
              message.tr(ref),
              style: context.bodyMedium?.medium.withColor(context.onSurfaceVariant), 
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 32),
              FilledButton(
                onPressed: action, 
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  actionLabel ?? 'get_started'.tr(ref), 
                  style: context.labelLarge?.extraBold.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}



class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, this.message, this.isFullPage = false});

  final String? message;
  final bool isFullPage;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primaryTeal, strokeWidth: 3),
          if (message != null) ...[
            const SizedBox(height: 24),
            Text(
              message!, 
              style: context.bodyMedium?.bold,
            ),
          ],
        ],
      ),
    );

    if (isFullPage) {
      return Container(
        color: context.theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
        child: content,
      );
    }
    return content;
  }
}


class StatusChip extends ConsumerWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  Color _getColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'won':
      case 'approved':
        return AppColors.success;
      case 'in progress':
      case 'installation':
        return AppColors.info;
      case 'contacted':
        return AppColors.indigo;
      case 'visited':
        return AppColors.pink;
      case 'pending':
      case 'quotation':
      case 'quotation sent':
        return AppColors.info;
      case 'negotiation':
        return AppColors.warning;
      case 'new':
        return AppColors.primaryTeal;
      case 'cancelled':
      case 'lost':
        return AppColors.error;
      case 'draft':
      case 'deferred':
        return AppColors.textMuted;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _getColor(status);
    String translated = status.tr(ref);
    if (translated == status) {
      translated = status.toLowerCase().replaceAll(' ', '_').tr(ref);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            translated.toUpperCase(),
            style: context.labelSmall?.extraBold.withColor(color).withLetterSpacing(1.2),
          ),
        ],
      ),
    );
  }
}



class ChannelChip extends ConsumerWidget {
  const ChannelChip({super.key, required this.channel});

  final String channel;

  static (Color, String?, IconData?) getChannelData(String channel) {
    switch (channel.toLowerCase()) {
      case 'facebook':
        return (AppColors.socialFacebook, 'assets/svg/Facebook.svg', null);
      case 'whatsapp':
        return (AppColors.socialWhatsapp, 'assets/svg/WhatsApp.svg', null);
      case 'website':
        return (AppColors.primaryTeal, null, Icons.language_rounded);
      case 'call':
        return (AppColors.indigo, null, Icons.phone);
      case 'organic lead':
        return (AppColors.primaryTeal, null, Icons.auto_graph_rounded);
      case 'referral':
        return (AppColors.violet, null, Icons.group_rounded);
      case 'walk-in':
        return (AppColors.orange, null, Icons.directions_walk_rounded);
      case 'exhibition':
        return (AppColors.pink, null, Icons.storefront_rounded);
      default:
        return (AppColors.textSecondary, null, Icons.campaign_rounded);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (channel.isEmpty || channel == '-') {
      return Text(
        channel.isEmpty ? '-' : channel,
        style: context.labelSmall?.semiBold.withColor(context.onSurfaceVariant),
      );
    }

    final (color, svgPath, icon) = getChannelData(channel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (svgPath != null)
            SvgPicture.asset(
              svgPath,
              width: 12,
              height: 12,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            )
          else if (icon != null)
            Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            channel.tr(ref).toUpperCase(),
            style: context.labelSmall?.bold.withColor(color).withLetterSpacing(0.5).withSize(9),
          ),
        ],
      ),
    );
  }
}



class ResultTile extends StatelessWidget {
  const ResultTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.color,
    this.icon,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? AppColors.primaryTeal;
    
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: context.theme.brightness == Brightness.dark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: context.labelMedium?.extraBold.withColor(context.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: displayColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 16, color: displayColor),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.bottomStart,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: context.displaySmall?.black.withSize(28).withHeight(1.1),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit!,
                      style: context.titleSmall?.bold.withColor(context.appTheme.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



InputDecoration customInputDecoration(BuildContext context, String label, {String? suffix, IconData? icon, bool isRequired = false}) {
  final borderRadius = BorderRadius.circular(28);
  
  Widget? labelWidget;
  if (label.isNotEmpty) {
    if (isRequired) {
      labelWidget = Text.rich(
        TextSpan(
          text: label.replaceAll(' *', '').replaceAll('*', '').trim(),
          children: [
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else {
      labelWidget = Text(label);
    }
  }

  return InputDecoration(
    label: labelWidget,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    suffixText: suffix,
    prefixIcon: icon != null ? Icon(icon, size: 20) : null,
    filled: true,
    fillColor: context.onSurfaceColor.withValues(alpha: 0.05),
    isDense: true,
    constraints: const BoxConstraints(minHeight: 48),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: context.borderColor, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: context.borderColor, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    labelStyle: context.labelMedium?.medium.withColor(context.onSurfaceVariant),
    floatingLabelStyle: context.labelSmall?.extraBold.primary,
    errorStyle: context.labelSmall?.bold.withColor(context.errorColor),
    suffixStyle: context.labelMedium?.bold.withColor(context.onSurfaceVariant),
  );
}

class PaginationFooter extends ConsumerWidget {
  const PaginationFooter({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final displayPage = currentPage.clamp(1, totalPages);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isUltraCompact = width < 350;
        final isCompact = width >= 350 && width < 500;

        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.borderColor),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: context.theme.brightness == Brightness.dark ? 0.2 : 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isUltraCompact && !isCompact) ...[
                  _PageArrow(
                    icon: Icons.keyboard_double_arrow_left_rounded,
                    enabled: displayPage > 1,
                    onPressed: displayPage > 1 ? () => onPageChanged(1) : null,
                  ),
                  const SizedBox(width: 4),
                ],
                _PageArrow(
                  icon: Icons.chevron_left_rounded,
                  enabled: displayPage > 1,
                  onPressed: displayPage > 1 ? () => onPageChanged(displayPage - 1) : null,
                ),
                const SizedBox(width: 8),

                if (isUltraCompact)
                  _PageIndicator(current: displayPage, total: totalPages)
                else
                  ..._buildPageNumbers(context, displayPage, totalPages, isCompact: isCompact),

                const SizedBox(width: 8),
                _PageArrow(
                  icon: Icons.chevron_right_rounded,
                  enabled: displayPage < totalPages,
                  onPressed: displayPage < totalPages ? () => onPageChanged(displayPage + 1) : null,
                ),
                if (!isUltraCompact && !isCompact) ...[
                  const SizedBox(width: 4),
                  _PageArrow(
                    icon: Icons.keyboard_double_arrow_right_rounded,
                    enabled: displayPage < totalPages,
                    onPressed: displayPage < totalPages ? () => onPageChanged(totalPages) : null,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildPageNumbers(BuildContext context, int current, int total, {bool isCompact = false}) {
    List<Widget> items = [];
    
    // In compact mode, we strictly limit to 3 buttons: 1, Current, Total
    if (isCompact) {
       items.add(_PageNumberButton(page: 1, active: current == 1, onPressed: () => onPageChanged(1)));
       
       if (current > 2 && current < total - 1) {
          items.add(_PageEllipsis());
          items.add(_PageNumberButton(page: current, active: true, onPressed: () {}));
          items.add(_PageEllipsis());
       } else if (current == 2 && total > 2) {
          items.add(_PageNumberButton(page: 2, active: true, onPressed: () {}));
          if (total > 3) items.add(_PageEllipsis());
       } else if (current == total - 1 && total > 2) {
          if (total > 3) items.add(_PageEllipsis());
          items.add(_PageNumberButton(page: total - 1, active: true, onPressed: () {}));
       } else if (total > 2 && current != 1 && current != total) {
          // Fallback for cases like current=3 when total=5
          items.add(_PageEllipsis());
          items.add(_PageNumberButton(page: current, active: true, onPressed: () {}));
          items.add(_PageEllipsis());
       } else if (total > 1) {
          if (total > 2) items.add(_PageEllipsis());
       }

       if (total > 1) {
         items.add(_PageNumberButton(page: total, active: current == total, onPressed: () => onPageChanged(total)));
       }
       return items;
    }

    if (total <= 5) {
      for (int i = 1; i <= total; i++) {
        items.add(_PageNumberButton(page: i, active: current == i, onPressed: () => onPageChanged(i)));
      }
    } else {
      items.add(_PageNumberButton(page: 1, active: current == 1, onPressed: () => onPageChanged(1)));
      
      if (current > 3) {
        items.add(_PageEllipsis());
      }
      
      int start = (current - 1).clamp(2, total - 1);
      int end = (current + 1).clamp(2, total - 1);
      
      if (current <= 3) {
        start = 2;
        end = 3;
      } else if (current >= total - 2) {
        start = total - 2;
        end = total - 1;
      } else {
        start = current;
        end = current;
      }
      
      for (int i = start; i <= end; i++) {
        if (i > 1 && i < total) {
          items.add(_PageNumberButton(page: i, active: current == i, onPressed: () => onPageChanged(i)));
        }
      }
      
      if (current < total - 2) {
        items.add(_PageEllipsis());
      }
      
      items.add(_PageNumberButton(page: total, active: current == total, onPressed: () => onPageChanged(total)));
    }
    
    return items;
  }
}


class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        '$current / $total',
        style: context.labelMedium?.bold.withColor(AppColors.primaryTeal),
      ),
    );
  }
}



class _PageNumberButton extends StatelessWidget {
  const _PageNumberButton({required this.page, required this.active, required this.onPressed});
  final int page;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: active ? null : onPressed,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: active ? AppColors.primaryTeal : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? AppColors.primaryTeal : Colors.transparent,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$page',
              style: context.labelMedium?.extraBold.withColor(
                active ? AppColors.white : context.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class _PageEllipsis extends StatelessWidget {
  const _PageEllipsis();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '...',
        style: context.labelMedium?.black.withColor(context.appTheme.textMuted).withLetterSpacing(1),
      ),
    );
  }
}



class _PageArrow extends StatelessWidget {
  const _PageArrow({required this.icon, required this.enabled, this.onPressed});
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled ? AppColors.primaryTeal.withValues(alpha: 0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon, 
            size: 20, 
            color: enabled ? AppColors.primaryTeal : context.appTheme.textMuted.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}



String formatCurrency(num value, {String symbol = 'EGP', String? locale}) {
  final formattedValue = NumberFormat('#,##0', locale).format(value);
  if (locale == 'ar') {
    return '$formattedValue ${symbol == 'EGP' ? 'ج.م' : symbol}';
  }
  return '$symbol $formattedValue';
}

String formatNumber(num value, {int decimals = 1, String? locale}) {
  if (value == value.toInt()) {
    return NumberFormat('#,##0', locale).format(value);
  }
  final pattern = decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0';
  return NumberFormat(pattern, locale).format(value);
}

String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return '-';
  final date = dateTime.format('dd/MM/yyyy');
  if (dateTime.hour == 0 && dateTime.minute == 0 && dateTime.second == 0) {
    return date;
  }
  return '$date ${dateTime.format('HH:mm')}';
}

class ProjectStatusBadge extends ConsumerWidget {
  const ProjectStatusBadge({required this.status, super.key});
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color color = context.appTheme.textMuted;
    if (status == 'Completed') color = AppColors.success;
    if (status == 'In Progress' || status == 'Installation') color = AppColors.info;
    if (status == 'Quotation' || status == 'Approved') color = AppColors.warning;
    if (status == 'Cancelled') color = AppColors.error;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseDot(color: color),
          const SizedBox(width: 8),
          Text(
            status.tr(ref),
            style: context.labelSmall?.extraBold.withColor(color),
          ),
        ],
      ),
    );
  }
}



class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color});
  final Color color;
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.4 + (0.6 * _controller.value)),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4 * _controller.value),
                blurRadius: 6 * _controller.value,
                spreadRadius: 2 * _controller.value,
              )
            ],
          ),
        );
      },
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.color,
    this.onPressed,
    this.tooltip,
    this.size = 18,
    this.padding = 8,
    this.borderRadius = 10,
    this.alpha = 0.06,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double padding;
  final double borderRadius;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: color.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: child,
      );
    }
    return child;
  }
}

class QuickActionButton extends StatefulWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const QuickActionButton({
    super.key,
    this.icon,
    this.iconWidget,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  State<QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<QuickActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isHovered ? widget.color.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: _isHovered ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: widget.iconWidget ?? Icon(widget.icon, color: widget.color, size: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: context.labelSmall?.extraBold.withColor(
                    _isHovered ? widget.color : context.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



