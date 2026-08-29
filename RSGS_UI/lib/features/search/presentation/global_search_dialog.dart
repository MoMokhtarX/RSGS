import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../search/data/global_search_service.dart';
import '../../../core/theme/typography_extensions.dart';

class GlobalSearchDialog extends ConsumerStatefulWidget {
  const GlobalSearchDialog({super.key});

  @override
  ConsumerState<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends ConsumerState<GlobalSearchDialog> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(globalSearchProvider(_query));
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: EdgeInsets.all(isMobile ? 16 : 40),
      child: Container(
        width: isMobile ? double.infinity : 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: theme.textTheme.bodyLarge?.bold,
                    decoration: InputDecoration(
                      hintText: 'search_hint'.tr(ref),
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                if (isMobile)
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  minHeight: 100,
                ),
                child: resultsAsync.when(
                  data: (results) {
                    if (_query.length < 2) {
                      return SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_rounded, size: 48, color: context.appTheme.textMuted.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'search_query_hint'.tr(ref),
                                textAlign: TextAlign.center,
                                style: context.bodyMedium?.withColor(context.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (results.isEmpty) {
                      return SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: AppColors.error.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'no_results'.tr(ref),
                                style: context.titleMedium?.withColor(context.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: results.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: context.borderColor.withValues(alpha: 0.5)),
                      itemBuilder: (context, index) {
                        final r = results[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getTypeColor(r.type).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_getTypeIcon(r.type), color: _getTypeColor(r.type), size: 20),
                          ),
                          title: Text(r.title, style: context.titleSmall?.bold),
                          subtitle: Text(
                            '${r.type.toLowerCase().tr(ref)} • ${r.subtitle}',
                            style: context.labelSmall?.withColor(context.onSurfaceVariant),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onTap: () {
                            Navigator.pop(context);
                            context.go(r.route);
                          },
                        );
                      },
                    );
                  },
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primaryTeal),
                    ),
                  ),
                  error: (e, _) => SizedBox(
                    height: 200,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '${'error'.tr(ref)}: $e',
                          textAlign: TextAlign.center,
                          style: context.bodyMedium?.bold.withColor(context.errorColor),
                        ),
                      ),
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

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'customer': return AppColors.primaryTeal;
      case 'project': return AppColors.primaryTeal;
      default: return AppColors.textSecondary;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'customer': return Icons.person_rounded;
      case 'project': return Icons.folder_copy_rounded;
      default: return Icons.info_outline_rounded;
    }
  }
}
