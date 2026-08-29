import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/localization/date_formatter.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/theme/typography_extensions.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final horizontalPadding = isMobile ? 12.0 : 16.0;

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(horizontalPadding, 16, horizontalPadding, 0),
                child: const _FiltersBar(),
              ),
              const SizedBox(height: 12),
              const Expanded(
                child: _NotificationsListView(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FiltersBar extends ConsumerWidget {
  const _FiltersBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const _MarkAllReadButton(),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _MarkAllReadButton extends ConsumerWidget {
  const _MarkAllReadButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () async {
        await ref.read(notificationsRepositoryProvider).markAllRead();
        DataRefreshCoordinator.refresh(ref);
        ref.invalidate(notificationsStreamProvider);
        ref.invalidate(unreadCountProvider);
      },
      icon: const Icon(Icons.done_all_rounded, size: 18),
      label: Text('mark_all_read'.tr(ref)),
      style: TextButton.styleFrom(
        foregroundColor: context.primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: context.labelLarge?.extraBold,
      ),
    );
  }
}

class _NotificationsListView extends ConsumerWidget {
  const _NotificationsListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return notificationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${'error'.tr(ref)}: $err', style: context.bodyLarge)),
      data: (notifications) {
        if (notifications.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.notifications_none_rounded,
            title: 'no_notifications',
            message: 'all_caught_up',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final n = notifications[index];
            return _NotificationTile(notification: n);
          },
        );
      },
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});
  final NotificationModel notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isRead = notification.isRead;
    final color = _getTypeColor(notification.type);

    return Container(
      decoration: BoxDecoration(
        color: isRead 
            ? context.surfaceColor.withValues(alpha: 0.6)
            : context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? context.borderColor : color.withValues(alpha: 0.3),
          width: isRead ? 1 : 1.5,
        ),
        boxShadow: isRead ? null : [
          BoxShadow(
            color: color.withValues(alpha: context.theme.brightness == Brightness.dark ? 0.1 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              if (!isRead) {
                await ref.read(notificationsRepositoryProvider).markRead(notification.id);
        DataRefreshCoordinator.refresh(ref);
                ref.invalidate(notificationsStreamProvider);
                ref.invalidate(unreadCountProvider);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTypeIcon(notification.type),
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: context.titleSmall?.copyWith(
                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.w900,
                                  color: isRead ? context.onSurfaceVariant : context.onSurfaceColor,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: context.bodySmall?.medium.withColor(
                            isRead ? context.appTheme.textMuted : context.onSurfaceVariant,
                          ).withHeight(1.4),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 12, color: context.appTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(notification.createdAt, ref),
                              style: context.labelSmall?.extraBold.withColor(context.appTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, size: 20, color: context.appTheme.textMuted),
                    onPressed: () async {
                      await ref.read(notificationsRepositoryProvider).delete(notification.id);
        DataRefreshCoordinator.refresh(ref);
                      ref.invalidate(notificationsStreamProvider);
                      ref.invalidate(unreadCountProvider);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'reminder': return AppColors.primaryTeal;
      case 'warning': return AppColors.warning;
      case 'error': return AppColors.error;
      case 'success': return AppColors.success;
      default: return AppColors.info;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'reminder': return Icons.alarm_rounded;
      case 'warning': return Icons.warning_amber_rounded;
      case 'error': return Icons.error_outline_rounded;
      case 'success': return Icons.check_circle_outline_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  String _formatDate(DateTime? date, WidgetRef ref) {
    if (date == null) return '';
    return date.format('date_time_format'.tr(ref), ref.watch(localeProvider).languageCode);
  }
}
