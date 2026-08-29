import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';

import '../../customers/data/customers_repository.dart';
import '../../projects/data/projects_repository.dart';
import '../../../core/models/app_models.dart';

final quotationCustomersProvider =
FutureProvider<List<CustomerModel>>(
      (ref) async {
    ref.watch(dataRefreshVersionProvider);
    final repository =
    ref.read(customersRepositoryProvider);

    return repository.getAllCustomers();
  },
);

final quotationProjectsProvider =
FutureProvider<List<ProjectModel>>(
      (ref) async {
    ref.watch(dataRefreshVersionProvider);
    final repository =
    ref.read(projectsRepositoryProvider);

    return repository.getProjects();
  },
);