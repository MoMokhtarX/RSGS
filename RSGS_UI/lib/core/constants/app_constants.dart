class AppConstants {
  AppConstants._();

  static const appName = 'RSGS CRM';
  static const appNameAr = 'نظام إدارة العملاء';
  static const companyEmail = 'info@redseagreen.com';
  static const companyWebsite = 'www.redseagreen.com';
  static const companyPhone = '+20 123 456 7890';
  static const companyAddress = 'Red Sea Governorate, Egypt';
  static const defaultTaxRate = 14.0;
  static const defaultCurrency = 'EGP';
  static const defaultCurrencySymbol = 'EGP';

  static const customerChannels = [
    'Facebook',
    'WhatsApp',
    'Website',
    'Referral',
    'Call',
    'Organic Lead',
    'Walk-in',
    'Exhibition',
    'Other',
  ];

  static const customerFollowUpStatuses = [
    'New',
    'Contacted',
    'Visited',
    'Quotation Sent',
    'Negotiation',
    'Won',
    'Lost',
    'Deferred',
  ];

  static const governorates = [
    'Cairo',
    'Alexandria',
    'Giza',
    'Red Sea',
    'South Sinai',
    'North Sinai',
    'Port Said',
    'Suez',
    'Luxor',
    'Aswan',
    'Qena',
    'Sohag',
    'Assiut',
    'Minya',
    'Beni Suef',
    'Fayoum',
    'Dakahlia',
    'Sharqia',
    'Qalyubia',
    'Kafr El Sheikh',
    'Gharbia',
    'Monufia',
    'Beheira',
    'Ismailia',
    'Damietta',
    'Matrouh',
    'New Valley',
  ];

  static const projectStatuses = [
    'Draft',
    'Pending',
    'Approved',
    'In Progress',
    'Completed',
    'Cancelled',
  ];

  static const projectTypes = [
    'On-Grid',
    'Off-Grid',
    'Solar Pump',
  ];

  static const eventTypes = [
    'task',
    'meeting',
    'follow_up',
  ];

  static const dialogBorderRadius = 20.0;
}
