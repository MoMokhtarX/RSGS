import 'package:flutter_riverpod/flutter_riverpod.dart';

final dataRefreshVersionProvider = StateProvider<int>((ref) => 0);

class DataRefreshCoordinator {
  const DataRefreshCoordinator._();

  static void refresh(WidgetRef ref) {
    ref.read(dataRefreshVersionProvider.notifier).state++;
  }
}
