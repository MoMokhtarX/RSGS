import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../models/quotation_models.dart';

class QuotationStatusActions extends ConsumerWidget {
  const QuotationStatusActions({
    super.key,
    required this.status,
    required this.onStatusChanged,
    this.loading = false,
  });

  final QuotationStatus status;
  final ValueChanged<QuotationStatus> onStatusChanged;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    switch (status) {
      case QuotationStatus.draft:
        return QuickActionButton(
          onPressed: () => onStatusChanged(QuotationStatus.sent),
          icon: Icons.send_rounded,
          label: 'action_send'.tr(ref).toUpperCase(),
          color: AppColors.primaryTeal,
        );

      case QuotationStatus.sent:
        return Row(
          children: [
            Expanded(
              child: QuickActionButton(
                onPressed: () => onStatusChanged(QuotationStatus.approved),
                icon: Icons.check_circle_outline,
                label: 'action_approve'.tr(ref).toUpperCase(),
                color: AppColors.success,
              ),
            ),
            Expanded(
              child: QuickActionButton(
                onPressed: () => onStatusChanged(QuotationStatus.rejected),
                icon: Icons.close_rounded,
                label: 'action_reject'.tr(ref).toUpperCase(),
                color: AppColors.error,
              ),
            ),
            Expanded(
              child: QuickActionButton(
                onPressed: () => onStatusChanged(QuotationStatus.expired),
                icon: Icons.timer_off_outlined,
                label: 'action_expire'.tr(ref).toUpperCase(),
                color: AppColors.warning,
              ),
            ),
          ],
        );

      case QuotationStatus.approved:
      case QuotationStatus.rejected:
      case QuotationStatus.expired:
        return const SizedBox.shrink();
    }
  }
}
