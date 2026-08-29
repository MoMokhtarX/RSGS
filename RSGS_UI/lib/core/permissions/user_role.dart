enum UserRole {
  admin(1, 'Admin', 'Full system access'),
  engineer(2, 'Engineer', 'Assigned customers/projects and project status management'),
  sales(3, 'Sales', 'Customer, project and quotation management'),
  accountant(4, 'Accountant', 'Read access to customers, projects and quotations'),
  manager(5, 'Manager', 'Customer, project and quotation management');
  const UserRole(this.apiValue,this.label,this.description); final int apiValue; final String label; final String description; String get name=>toString().split('.').last;
  static UserRole fromString(String value){final n=value.trim().toLowerCase();final num=int.tryParse(n);if(num!=null)return values.firstWhere((x)=>x.apiValue==num,orElse:()=>throw FormatException('Unknown user role: $value'));return values.firstWhere((x)=>x.name==n||x.label.toLowerCase()==n,orElse:()=>throw FormatException('Unknown user role: $value'));}
}

enum AppPermission {
  viewDashboard,viewCustomers,manageCustomers,viewProjects,manageProjects,viewQuotations,manageQuotations,viewCalendar,viewActivityLogs,manageUsers,viewProducts,manageProducts,manageSettings,globalSearch,viewNotifications,
  viewInvoices,manageInvoices,viewPayments,managePayments,viewSuppliers,manageSuppliers,viewInventory,manageInventory,viewPurchaseOrders,managePurchaseOrders,viewReports,
}

extension UserRolePermissions on UserRole {
  Set<AppPermission> get permissions { switch(this){
    case UserRole.admin: return AppPermission.values.toSet();
    case UserRole.manager: return {AppPermission.viewDashboard,AppPermission.viewCustomers,AppPermission.manageCustomers,AppPermission.viewProjects,AppPermission.manageProjects,AppPermission.viewQuotations,AppPermission.manageQuotations,AppPermission.viewCalendar,AppPermission.viewProducts,AppPermission.manageProducts,AppPermission.globalSearch,AppPermission.viewNotifications,AppPermission.viewInvoices,AppPermission.manageInvoices,AppPermission.viewPayments,AppPermission.managePayments,AppPermission.viewSuppliers,AppPermission.manageSuppliers,AppPermission.viewInventory,AppPermission.manageInventory,AppPermission.viewPurchaseOrders,AppPermission.managePurchaseOrders,AppPermission.viewReports};
    case UserRole.sales: return {AppPermission.viewDashboard,AppPermission.viewCustomers,AppPermission.manageCustomers,AppPermission.viewProjects,AppPermission.manageProjects,AppPermission.viewQuotations,AppPermission.manageQuotations,AppPermission.viewCalendar,AppPermission.viewProducts,AppPermission.globalSearch,AppPermission.viewNotifications,AppPermission.viewInvoices};
    case UserRole.engineer: return {AppPermission.viewDashboard,AppPermission.viewCustomers,AppPermission.viewProjects,AppPermission.viewQuotations,AppPermission.viewCalendar,AppPermission.globalSearch,AppPermission.viewNotifications,AppPermission.viewProducts,AppPermission.viewInventory};
    case UserRole.accountant: return {AppPermission.viewDashboard,AppPermission.viewCustomers,AppPermission.viewProjects,AppPermission.viewQuotations,AppPermission.viewCalendar,AppPermission.viewProducts,AppPermission.globalSearch,AppPermission.viewNotifications,AppPermission.viewInvoices,AppPermission.manageInvoices,AppPermission.viewPayments,AppPermission.managePayments,AppPermission.viewSuppliers,AppPermission.manageSuppliers,AppPermission.viewInventory,AppPermission.manageInventory,AppPermission.viewPurchaseOrders,AppPermission.managePurchaseOrders,AppPermission.viewReports};
  }}
  bool can(AppPermission permission)=>permissions.contains(permission);
}
