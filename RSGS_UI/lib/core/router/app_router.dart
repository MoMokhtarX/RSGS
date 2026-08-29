import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/customers/presentation/customer_details_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/projects/presentation/project_details_screen.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/activity/presentation/activity_screen.dart';
import '../../features/users/presentation/users_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/products/presentation/price_list_screen.dart';
import '../../features/finance/presentation/invoices_screen.dart';
import '../../features/finance/presentation/payments_screen.dart';
import '../../features/operations/presentation/operations_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/quotations/presentation/quotations_screen.dart';
import '../../features/quotations/presentation/quotation_details_screen.dart';
import '../../features/quotations/presentation/quotation_form_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../permissions/user_role.dart';

class AppRoute {
  const AppRoute({
    required this.path,
    required this.labelKey,
    required this.icon,
    required this.permission,
  });

  final String path;
  final String labelKey;
  final IconData icon;
  final AppPermission permission;
}

const appRoutes = [
  AppRoute(path: '/dashboard', labelKey: 'dashboard', icon: Icons.dashboard_rounded, permission: AppPermission.viewDashboard),
  AppRoute(path: '/customers', labelKey: 'customers', icon: Icons.people_rounded, permission: AppPermission.viewCustomers),
  AppRoute(path: '/projects', labelKey: 'projects', icon: Icons.folder_copy_rounded, permission: AppPermission.viewProjects),
  AppRoute(path: '/quotations', labelKey: 'quotations', icon: Icons.request_quote_rounded, permission: AppPermission.viewQuotations),
  AppRoute(path: '/calendar', labelKey: 'calendar', icon: Icons.calendar_month_rounded, permission: AppPermission.viewCalendar),
  AppRoute(path: '/activity', labelKey: 'activity_log', icon: Icons.history_rounded, permission: AppPermission.viewActivityLogs),
  AppRoute(path: '/users', labelKey: 'users', icon: Icons.manage_accounts_rounded, permission: AppPermission.manageUsers),
  AppRoute(path: '/products', labelKey: 'products', icon: Icons.inventory_2_rounded, permission: AppPermission.viewProducts),
  AppRoute(path: '/price-list', labelKey: 'price_list', icon: Icons.sell_rounded, permission: AppPermission.viewProducts),
  AppRoute(path: '/invoices', labelKey: 'invoices', icon: Icons.receipt_long_rounded, permission: AppPermission.viewInvoices),
  AppRoute(path: '/payments', labelKey: 'payments', icon: Icons.payments_rounded, permission: AppPermission.viewPayments),
  AppRoute(path: '/operations', labelKey: 'operations', icon: Icons.business_center_rounded, permission: AppPermission.viewInventory),
  AppRoute(path: '/reports', labelKey: 'reports', icon: Icons.analytics_rounded, permission: AppPermission.viewReports),
];

List<AppRoute> routesForUser(UserRole? role) {
  if (role == null) return [];
  return appRoutes.where((route) => role.can(route.permission)).toList();
}

AppPermission? _permissionForLocation(String location) {
  if (location == '/dashboard' || location.startsWith('/dashboard/')) {
    return AppPermission.viewDashboard;
  }
  if (location == '/customers' || location.startsWith('/customers/')) {
    return AppPermission.viewCustomers;
  }
  if (location == '/projects' || location.startsWith('/projects/')) {
    return AppPermission.viewProjects;
  }
  if (location == '/quotations' || location == '/quotations/new' || location.endsWith('/edit')) {
    return location == '/quotations' ? AppPermission.viewQuotations : AppPermission.manageQuotations;
  }
  if (location.startsWith('/quotations/')) {
    return AppPermission.viewQuotations;
  }
  if (location == '/calendar' || location.startsWith('/calendar/')) {
    return AppPermission.viewCalendar;
  }
  if (location == '/activity' || location.startsWith('/activity/')) {
    return AppPermission.viewActivityLogs;
  }
  if (location == '/users' || location.startsWith('/users/')) {
    return AppPermission.manageUsers;
  }
  if (location == '/products' || location.startsWith('/products/')) {
    return AppPermission.viewProducts;
  }
  if (location == '/price-list' || location.startsWith('/price-list/')) {
    return AppPermission.viewProducts;
  }
  if (location == '/invoices' || location.startsWith('/invoices/')) {
    return AppPermission.viewInvoices;
  }
  if (location == '/payments' || location.startsWith('/payments/')) {
    return AppPermission.viewPayments;
  }
  if (location == '/operations' || location.startsWith('/operations/')) {
    return AppPermission.viewInventory;
  }
  if (location == '/reports' || location.startsWith('/reports/')) {
    return AppPermission.viewReports;
  }
  if (location == '/notifications' || location.startsWith('/notifications/')) {
    return AppPermission.viewNotifications;
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isLogin = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      if (isSplash) return null;

      if (!isLoggedIn && !isLogin) return '/login';
      if (isLoggedIn && isLogin) return '/dashboard';

      if (isLoggedIn) {
        final permission = _permissionForLocation(state.matchedLocation);
        final role = authState.user?.role;

        if (permission != null && (role == null || !role.can(permission))) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
          GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
          GoRoute(path: '/activity', builder: (context, state) => const ActivityScreen()),
          GoRoute(path: '/users', builder: (context, state) => const UsersScreen()),
          GoRoute(path: '/products', builder: (context, state) => const ProductsScreen()),
          GoRoute(path: '/price-list', builder: (context, state) => const PriceListScreen()),
          GoRoute(path: '/invoices', builder: (context, state) => const InvoicesScreen()),
          GoRoute(path: '/payments', builder: (context, state) => const PaymentsScreen()),
          GoRoute(path: '/operations', builder: (context, state) => const OperationsScreen()),
          GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return CustomerDetailsScreen(customerId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/projects',
            builder: (context, state) => const ProjectsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ProjectDetailsScreen(projectId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/quotations',
            builder: (context, state) => const QuotationsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) {
                  final customerId = int.tryParse(state.uri.queryParameters['customerId'] ?? '');
                  final projectId = int.tryParse(state.uri.queryParameters['projectId'] ?? '');
                  return QuotationFormScreen(
                    initialCustomerId: customerId,
                    initialProjectId: projectId,
                  );
                },
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return QuotationDetailsScreen(quotationId: id);
                },
              ),
              GoRoute(
                path: ':id/edit',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return QuotationFormScreen(quotationId: id);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
