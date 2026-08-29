import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import 'package:go_router/go_router.dart';
import '../../customers/data/customers_repository.dart';
import '../../../core/models/app_models.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/localization/date_formatter.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_provider.dart';
import '../data/quotations_repository.dart';
import '../models/quotation_models.dart';
import '../providers/quotations_provider.dart';
import '../providers/quotation_form_providers.dart';
import '../../products/data/products_repository.dart';
import '../../products/models/product_models.dart';

class QuotationFormScreen
    extends ConsumerStatefulWidget {
  const QuotationFormScreen({
    super.key,
    this.quotationId,
    this.initialCustomerId,
    this.initialProjectId,
  });

  final int? quotationId;
  final int? initialCustomerId;
  final int? initialProjectId;

  bool get isEdit => quotationId != null;

  @override
  ConsumerState<QuotationFormScreen> createState() =>
      _QuotationFormScreenState();
}

class _QuotationFormScreenState
    extends ConsumerState<QuotationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  QuotationType _type =
      QuotationType.onGrid;

  int? _customerId;
  int? _projectId;

  CustomerModel? _selectedCustomer;
  ProjectModel? _selectedProject;

  DateTime? _quotationDate;
  DateTime? _validUntil;

  final _systemDescriptionController =
  TextEditingController();

  final _capacityController =
  TextEditingController();

  final _introductionController =
  TextEditingController();

  final _generalTermsController =
  TextEditingController();

  final _paymentTermsController =
  TextEditingController();

  final _notesController =
  TextEditingController();

  final _materialsController =
  TextEditingController();

  final _transportationController =
  TextEditingController();

  final _installationController =
  TextEditingController();

  final _otherCostController =
  TextEditingController();

  final _profitMarginController =
  TextEditingController();

  final _discountController =
  TextEditingController();

  final _taxController =
  TextEditingController();

  String _capacityUnit = 'kW';

  final List<_QuotationItemForm> _items = [];

  int _currentStep = 0;
  late final PageController _pageController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentStep);

    _materialsController.addListener(_recalculate);
    _transportationController.addListener(_recalculate);
    _installationController.addListener(_recalculate);
    _otherCostController.addListener(_recalculate);
    _profitMarginController.addListener(_recalculate);
    _discountController.addListener(_recalculate);
    _taxController.addListener(_recalculate);

    if (!widget.isEdit) {
      _quotationDate = DateTime.now();
      _customerId = widget.initialCustomerId;
      _projectId = widget.initialProjectId;

      if (_projectId != null) {
        _loadProjectAndSetType(_projectId!);
      } else {
        _initializeRequiredItems(_type);
      }
    }
  }

  Future<void> _loadProjectAndSetType(int projectId) async {
    final projects = await ref.read(quotationProjectsProvider.future);
    final project = projects.firstWhere((p) => p.id == projectId);
    
    if (mounted) {
      setState(() {
        _selectedProject = project;
        _type = _mapProjectToQuotationType(project.name);
        _initializeRequiredItems(_type);
      });
    }
  }

  QuotationType _mapProjectToQuotationType(String projectName) {
    switch (projectName) {
      case 'On-Grid':
        return QuotationType.onGrid;
      case 'Off-Grid':
        return QuotationType.offGrid;
      case 'Solar Pump':
        return QuotationType.solarPump;
      default:
        return QuotationType.onGrid;
    }
  }

  void _recalculate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    _systemDescriptionController.dispose();
    _capacityController.dispose();
    _introductionController.dispose();
    _generalTermsController.dispose();
    _paymentTermsController.dispose();
    _notesController.dispose();

    _materialsController.dispose();
    _transportationController.dispose();
    _installationController.dispose();
    _otherCostController.dispose();
    _profitMarginController.dispose();
    _discountController.dispose();
    _taxController.dispose();

    for (final item in _items) {
      item.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEdit) {
      return _buildEditBody(context);
    }

    return _buildForm(context);
  }

  Widget _buildEditBody(
      BuildContext context,
      ) {
    final quotationAsync =
    ref.watch(
      quotationProvider(
        widget.quotationId!,
      ),
    );

    return quotationAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Text(
            'failed_load_quotation'.tr(ref),
          ),
        ),
      ),
      data: (quotation) {
        if (quotation == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'quotation_not_found'.tr(ref),
              ),
            ),
          );
        }

        _fillFromQuotation(
          quotation,
        );

        return _buildForm(context);
      },
    );
  }

  bool _loadedExisting = false;

  void _fillFromQuotation(
      QuotationModel quotation,
      ) {
    if (_loadedExisting) return;

    _loadedExisting = true;

    _type = quotation.type;

    _customerId =
        quotation.customerId;

    _projectId =
        quotation.projectId;

    _quotationDate =
        quotation.quotationDate;

    _validUntil =
        quotation.validUntil;

    _systemDescriptionController.text =
        quotation.systemDescription ?? '';

    _capacityController.text =
        quotation.systemCapacity
            ?.toString() ??
            '';

    _capacityUnit =
        quotation.capacityUnit;

    _introductionController.text =
        quotation.introduction ?? '';

    _generalTermsController.text =
        quotation.generalTerms ?? '';

    _paymentTermsController.text =
        quotation.paymentTerms ?? '';

    _notesController.text =
        quotation.notes ?? '';

    final catalogCost = quotation.items.fold<double>(0, (sum, item) => sum + item.totalCost);
    final additionalMaterials = (quotation.materialsCost - catalogCost).clamp(0, double.infinity);
    _materialsController.text = additionalMaterials.toString();

    _transportationController.text =
        quotation.transportationCost.toString();

    _installationController.text =
        quotation.installationCost.toString();

    _otherCostController.text =
        quotation.otherCost.toString();

    _profitMarginController.text =
        quotation.profitMargin.toString();

    _discountController.text =
        quotation.discount.toString();

    _taxController.text =
        quotation.tax.toString();

    _initializeItemsFromExisting(
      quotation.items,
    );

    _loadExistingCustomer(
      quotation.customerId,
    );
  }

  Future<void> _loadExistingCustomer(
      int customerId,
      ) async {
    final repository =
    ref.read(
      customersRepositoryProvider,
    );

    final customer =
    await repository.getCustomer(
      customerId,
    );

    if (!mounted || customer == null) {
      return;
    }

    setState(() {
      _selectedCustomer = customer;
    });

    if (_projectId == null) return;

    final projects =
    await ref.read(
      quotationProjectsProvider.future,
    );

    ProjectModel? project;

    for (final p in projects) {
      if (p.id == _projectId &&
          p.customerId == customerId) {
        project = p;
        break;
      }
    }

    if (!mounted) return;

    setState(() {
      _selectedProject = project;
    });
  }

  Widget _buildForm(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildUnifiedHeader(context),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 1000;
                    return isWide ? _buildWideLayout(context) : _buildMobileLayout(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedHeader(BuildContext context) {
    final steps = [
      'customer'.tr(ref),
      'project'.tr(ref),
      'order_items'.tr(ref),
      'pricing'.tr(ref),
      'payment_terms'.tr(ref)
    ];
    final isLastStep = _currentStep == 4;

    return LayoutBuilder(builder: (context, constraints) {
      final bool isCompact = constraints.maxWidth < 1000;
      final bool hideLabels = constraints.maxWidth < 800;
      final bool hideButtonText = constraints.maxWidth < 600;
      final bool ultraCompact = constraints.maxWidth < 450;
      final double gap = ultraCompact ? 4 : (isCompact ? 8 : 32);

      return Container(
        padding: EdgeInsets.symmetric(horizontal: ultraCompact ? 8 : (isCompact ? 12 : 24), vertical: 12),
        decoration: BoxDecoration(
          color: context.theme.scaffoldBackgroundColor,
          border: Border(bottom: BorderSide(color: context.borderColor.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            ActionButton(
              icon: Icons.arrow_back_rounded,
              color: context.onSurfaceColor,
              onPressed: _isSaving ? null : () => context.pop(),
              size: ultraCompact ? 18 : 20,
              padding: ultraCompact ? 8 : 10,
              borderRadius: 12,
              alpha: 0.08,
            ),
            SizedBox(width: gap),
            if (_currentStep > 0)
              OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: hideButtonText ? 8 : 16),
                  minimumSize: Size(0, ultraCompact ? 40 : 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.chevron_left_rounded, size: ultraCompact ? 18 : 20),
                    if (!hideButtonText) ...[
                      const SizedBox(width: 4),
                      Text('previous'.tr(ref).toUpperCase(), style: context.labelSmall?.bold),
                    ],
                  ],
                ),
              )
            else if (!isCompact)
              const SizedBox(width: 100),
            
            SizedBox(width: gap),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Row(
                    children: List.generate(steps.length, (index) {
                      final isActive = _currentStep == index;
                      final isCompleted = _currentStep > index;
                      
                      return Expanded(
                        child: Row(
                          children: [
                            _StepBubble(
                              index: index + 1,
                              label: steps[index],
                              isActive: isActive,
                              isCompleted: isCompleted,
                              showLabel: !hideLabels,
                              size: ultraCompact ? 28 : 32,
                            ),
                            if (index < steps.length - 1)
                              Expanded(
                                child: Container(
                                  height: 2,
                                  margin: EdgeInsets.symmetric(horizontal: ultraCompact ? 2 : 4),
                                  decoration: BoxDecoration(
                                    color: isCompleted ? AppColors.primaryTeal : context.borderColor,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            SizedBox(width: gap),
            if (!isLastStep)
              FilledButton(
                onPressed: () {
                  if (_validateCurrentStep()) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: hideButtonText ? 8 : 16),
                  minimumSize: Size(0, ultraCompact ? 40 : 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  children: [
                    if (!hideButtonText) ...[
                      Text('next_step'.tr(ref).toUpperCase(), style: context.labelSmall?.bold.white),
                      const SizedBox(width: 4),
                    ],
                    Icon(Icons.chevron_right_rounded, size: ultraCompact ? 18 : 20),
                  ],
                ),
              )
            else
              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: hideButtonText ? 8 : 16),
                  minimumSize: Size(0, ultraCompact ? 40 : 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: AppColors.primaryTeal,
                ),
                child: Row(
                  children: [
                    if (_isSaving)
                      SizedBox(width: ultraCompact ? 14 : 16, height: ultraCompact ? 14 : 16, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    else
                      Icon(Icons.check_circle_rounded, size: ultraCompact ? 16 : 18),
                    if (!hideButtonText) ...[
                      const SizedBox(width: 8),
                      Text(
                        (widget.isEdit ? 'update_quotation'.tr(ref) : 'create_quotation'.tr(ref)).toUpperCase(),
                        style: context.labelSmall?.bold.white,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildWideLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _buildWizardPages(),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 380,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 24, bottom: 40),
              child: _buildSummaryCard(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildWizardPages()),
        _buildSummaryCardMini(context),
      ],
    );
  }

  Widget _buildWizardPages() {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) => setState(() => _currentStep = index),
      children: [
        _buildStepPage(
          child: Column(
            children: [
              _buildBasicInformation(context),
            ],
          ),
        ),
        _buildStepPage(
          child: Column(
            children: [
              _buildQuotationType(context),
              const SizedBox(height: 24),
              _buildSystemInformation(context),
            ],
          ),
        ),
        _buildStepPage(
          child: Column(
            children: [
              _buildTechnicalItems(context),
            ],
          ),
        ),
        _buildStepPage(
          child: Column(
            children: [
              _buildPricing(context),
            ],
          ),
        ),
        _buildStepPage(
          child: Column(
            children: [
              _buildQuotationText(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepPage({required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSummaryCardMini(BuildContext context) {
    final summary = _calculateSummary();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(top: BorderSide(color: context.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('estimated_total'.tr(ref).toUpperCase(), style: context.labelSmall?.extraBold.withColor(context.appTheme.textMuted).withSize(9).withLetterSpacing(1.0)),
                  const SizedBox(height: 4),
                  Text(
                    '${summary.total.toStringAsFixed(2)} EGP',
                    style: context.titleMedium?.black.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _showFullSummary(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryTeal.withValues(alpha: 0.1),
                foregroundColor: AppColors.primaryTeal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.analytics_outlined, size: 18),
              label: Text('view_summary'.tr(ref), style: context.labelMedium?.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullSummary(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: context.theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            child: _buildSummaryCard(context),
          ),
        ),
      ),
    );
  }


  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Client & Context
        if (_selectedCustomer == null) {
          _showError('please_select_customer'.tr(ref));
          return false;
        }
        return true;
        
      case 1: // System Specifications
        final capacity = double.tryParse(_capacityController.text);
        if (capacity == null || capacity <= 0) {
          _showError('enter_valid_capacity'.tr(ref));
          return false;
        }
        return true;
        
      case 2: // Bill of Materials
        if (_items.isEmpty) {
          _showError('add_at_least_one_item'.tr(ref));
          return false;
        }
        // Validate each item has required fields
        for (final item in _items) {
          if (item.itemController.text.trim().isEmpty) {
            _showError('items_must_have_name'.tr(ref));
            return false;
          }
          if ((double.tryParse(item.quantityController.text) ?? 0) <= 0) {
            _showError('${'item'.tr(ref)} "${item.itemController.text}" ${'item_must_have_qty'.tr(ref)}');
            return false;
          }
        }
        return true;
        
      case 3: // Financials
        final margin = double.tryParse(_profitMarginController.text) ?? 0;
        final tax = double.tryParse(_taxController.text) ?? 0;
        
        if (margin < 0 || margin > 100) {
          _showError('margin_range_error'.tr(ref));
          return false;
        }
        if (tax < 0 || tax > 100) {
          _showError('tax_range_error'.tr(ref));
          return false;
        }
        return true;
        
      default:
        return true;
    }
  }


  Widget _buildBasicInformation(
      BuildContext context,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: 'client_context'.tr(ref),
          subtitle: 'assign_customer_project'.tr(ref),
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 32),
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (
                    context,
                    constraints,
                    ) {
                  final small =
                      constraints.maxWidth < 800;

                  final customer =
                  _buildCustomerSelector(
                    context,
                  );

                  final project =
                  _buildProjectSelector(
                    context,
                  );

                  if (small) {
                    return Column(
                      children: [
                        customer,
                        const SizedBox(height: 24),
                        project,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: customer,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: project,
                      ),
                    ],
                  );
                },
              ),
              if (_selectedProject != null) ...[
                const SizedBox(height: 24),
                _buildProjectInfoCard(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepHeader({required String title, required String subtitle, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryTeal.withValues(alpha: 0.1),
            AppColors.primaryTeal.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryTeal.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.titleLarge?.extraBold.withHeight(1.1)),
                const SizedBox(height: 4),
                Text(subtitle, style: context.bodySmall?.semiBold.withColor(context.appTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectInfoCard(BuildContext context) {
    if (_selectedProject == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.solar_power_rounded, color: AppColors.primaryTeal, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('project_overview'.tr(ref).toUpperCase(), style: context.labelSmall?.extraBold.primary.withLetterSpacing(1.2)),
                    const SizedBox(height: 4),
                    Text(
                      _selectedProject!.name,
                      style: context.titleMedium?.extraBold,
                    ),
                    Text(
                      '#${_selectedProject!.projectNumber}',
                      style: context.labelSmall?.medium.withColor(context.appTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    StatusChip(status: _selectedProject!.status),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoItem(context, Icons.bolt_rounded, 'capacity'.tr(ref), '${formatNumber(_selectedProject!.totalKw, locale: ref.watch(localeProvider).languageCode)} ${'kw_unit'.tr(ref)}'),
              const SizedBox(height: 16),
              _infoItem(context, Icons.category_outlined, 'topology'.tr(ref), _type.labelKey.tr(ref)),
              if (_selectedProject!.governorate != null) ...[
                const SizedBox(height: 16),
                _infoItem(
                  context, 
                  Icons.location_on_outlined, 
                  'location'.tr(ref), 
                  '${_selectedProject!.city != null && _selectedProject!.city!.isNotEmpty ? "${_selectedProject!.city}, " : ""}${_selectedProject!.governorate!.tr(ref)}'
                ),
              ],
              if (_selectedProject!.installationDate != null) ...[
                const SizedBox(height: 16),
                _infoItem(context, Icons.calendar_today_rounded, 'installation'.tr(ref), _selectedProject!.installationDate!.format('date_format'.tr(ref), ref.watch(localeProvider).languageCode)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoItem(BuildContext context, IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.appTheme.textMuted),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: context.labelSmall?.medium.withColor(context.appTheme.textMuted).withSize(9)),
            Text(value, style: context.bodySmall?.bold),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerSelector(
      BuildContext context,
      ) {
    final customersAsync =
    ref.watch(
      quotationCustomersProvider,
    );

    return customersAsync.when(
      loading: () {
        return _selectorLoading(
          'loading_customers'.tr(ref),
          icon: Icons.person_rounded,
        );
      },
      error: (error, _) {
        return _selectorError(
          'failed_load_customers'.tr(ref),
          icon: Icons.person_rounded,
        );
      },
      data: (customers) {
        if (_selectedCustomer == null && _customerId != null) {
          try {
            _selectedCustomer = customers.firstWhere(
                  (c) => c.id == _customerId,
            );
          } catch (_) {}
        }

        return _GlassDropdown<CustomerModel>(
          label: 'customer'.tr(ref),
          isRequired: true,
          hint: 'please_select_customer'.tr(ref),
          value: _selectedCustomer,
          items: customers,
          icon: Icons.person_rounded,
          itemBuilder: (context, customer) => Text(
            '${customer.name} #${customer.id}',
            style: context.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
          onChanged: (customer) {
            if (customer == null) return;

            setState(() {
              _selectedCustomer = customer;
              _customerId = customer.id;
              _selectedProject = null;
              _projectId = null;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'customer_required'.tr(ref);
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildProjectSelector(
      BuildContext context,
      ) {
    final projectsAsync =
    ref.watch(
      quotationProjectsProvider,
    );

    if (_selectedCustomer == null) {
      return _GlassDropdown<ProjectModel>(
        label: 'project'.tr(ref),
        hint: 'select_customer_first'.tr(ref),
        value: null,
        items: const [],
        enabled: false,
        icon: Icons.folder_shared_rounded,
        onChanged: (_) {},
        itemBuilder: (context, _) => const SizedBox.shrink(),
      );
    }

    return projectsAsync.when(
      loading: () {
        return _selectorLoading(
          'loading_projects'.tr(ref),
          icon: Icons.folder_shared_rounded,
        );
      },
      error: (error, _) {
        return _selectorError(
          'failed_load_projects'.tr(ref),
          icon: Icons.folder_shared_rounded,
        );
      },
      data: (projects) {
        final customerProjects = projects
            .where(
              (project) => project.customerId == _selectedCustomer!.id,
            )
            .toList();

        if (_selectedProject == null && _projectId != null) {
          try {
            _selectedProject = customerProjects.firstWhere(
              (p) => p.id == _projectId,
            );
          } catch (_) {}
        }

        return _GlassDropdown<ProjectModel>(
          label: 'project'.tr(ref),
          isRequired: true,
          hint: customerProjects.isEmpty
              ? 'no_projects_for_customer'.tr(ref)
              : 'select_project'.tr(ref),
          value: customerProjects.any((p) => p.id == _selectedProject?.id) ? _selectedProject : null,
          items: customerProjects,
          enabled: customerProjects.isNotEmpty,
          icon: Icons.folder_shared_rounded,
          itemBuilder: (context, project) => Text(
            '${project.name} #${project.id}',
            style: context.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
          onChanged: (project) {
            setState(() {
              _selectedProject = project;
              _projectId = project?.id;
              if (project != null) {
                _type = _mapProjectToQuotationType(project.name);
                _initializeRequiredItems(_type);
              }
            });
          },
        );
      },
    );
  }

  Widget _selectorLoading(String text, {IconData? icon}) {
    return InputDecorator(
      decoration: _inputDecoration('', icon: icon),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: context.bodyMedium?.withColor(context.appTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _selectorError(String text, {IconData? icon}) {
    return InputDecorator(
      decoration: _inputDecoration('', icon: icon),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: context.errorColor, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: context.bodyMedium?.withColor(context.errorColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationType(
      BuildContext context,
      ) {
    final bool isLocked = _selectedProject != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: 'system_topology'.tr(ref),
          subtitle: 'select_topology'.tr(ref),
          icon: Icons.category_outlined,
        ),
        const SizedBox(height: 32),
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('topology_selection'.tr(ref).toUpperCase(), style: context.labelSmall?.extraBold.primary.withLetterSpacing(1.2)),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isMobile ? 1 : 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: isMobile ? (constraints.maxWidth < 400 ? 3.2 : 4.5) : 2.0,
                    children: QuotationType.values.map((type) {
                      final isSelected = _type == type;
                      return InkWell(
                        onTap: (isLocked || _isSaving) ? null : () {
                          setState(() {
                            _type = type;
                            _initializeRequiredItems(type);
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AppColors.primaryTeal.withValues(alpha: 0.1)
                                : (isLocked ? context.appTheme.surfaceSubtle.withValues(alpha: 0.5) : context.appTheme.surfaceSubtle),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryTeal : context.borderColor,
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: AppColors.primaryTeal.withValues(alpha: 0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              )
                            ] : null,
                          ),
                          child: Opacity(
                            opacity: (isLocked && !isSelected) ? 0.4 : 1.0,
                            child: Stack(
                              children: [
                                if (isSelected)
                                  const Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Icon(Icons.check_circle_rounded, color: AppColors.primaryTeal, size: 20),
                                  ),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.primaryTeal : context.appTheme.textMuted.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _typeIcon(type),
                                          color: isSelected ? Colors.white : context.appTheme.textMuted,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        type.label,
                                        style: context.labelLarge?.extraBold.withColor(
                                          isSelected ? AppColors.primaryTeal : context.onSurfaceColor,
                                        ).withSize(14),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _typeIcon(
      QuotationType type,
      ) {
    switch (type) {
      case QuotationType.onGrid:
        return Icons.power_rounded;

      case QuotationType.offGrid:
        return Icons.battery_charging_full;

      case QuotationType.solarPump:
        return Icons.water_drop_rounded;
    }
  }

  Widget _buildSystemInformation(
      BuildContext context,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: 'system_parameters'.tr(ref),
          subtitle: 'costs_margins_taxes'.tr(ref), // This subtitle seems slightly off in original code but keeping flow
          icon: Icons.solar_power_outlined,
        ),
        const SizedBox(height: 32),
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('project_parameters'.tr(ref).toUpperCase(), style: context.labelSmall?.extraBold.primary.withLetterSpacing(1.2)),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (
                    context,
                    constraints,
                    ) {
                  final small =
                      constraints.maxWidth < 600;

                  final capacity =
                  _field(
                    label: 'system_capacity_required'.tr(ref),
                    isRequired: true,
                    controller:
                    _capacityController,
                    icon: Icons.bolt_rounded,
                    keyboardType:
                    const TextInputType
                        .numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final number =
                      double.tryParse(
                        value ?? '',
                      );

                      if (number == null ||
                          number <= 0) {
                        return 'capacity_required'.tr(ref);
                      }

                      return null;
                    },
                  );

                  final unit = _GlassDropdown<String>(
                    label: 'capacity_unit'.tr(ref),
                    isRequired: true,
                    hint: 'capacity_unit'.tr(ref),
                    value: _capacityUnit,
                    items: const ['kW', 'MW', 'HP'],
                    icon: Icons.straighten_rounded,
                    itemBuilder: (context, val) => Text(val, style: context.bodyMedium),
                    onChanged: (val) {
                      if (val != null) setState(() => _capacityUnit = val);
                    },
                  );

                  if (small) {
                    return Column(
                      children: [
                        capacity,
                        const SizedBox(height: 20),
                        unit,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: capacity,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: unit,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              _field(
                label: 'system_description'.tr(ref),
                controller:
                _systemDescriptionController,
                icon: Icons.description_outlined,
                maxLines: 3,
              ),

              const SizedBox(height: 32),
              Text('project_lifecycle'.tr(ref).toUpperCase(), style: context.labelSmall?.extraBold.primary.withLetterSpacing(1.2)),
              const SizedBox(height: 20),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < 600;
                  
                  final dateField = _dateField(
                    context,
                    label: 'quotation_date'.tr(ref),
                    isRequired: true,
                    value: _quotationDate,
                    onChanged: (date) {
                      setState(() {
                        _quotationDate = date;
                      });
                    },
                  );

                  final validUntilField = _dateField(
                    context,
                    label: 'valid_until'.tr(ref),
                    value: _validUntil,
                    onChanged: (date) {
                      setState(() {
                        _validUntil = date;
                      });
                    },
                  );

                  if (isSmall) {
                    return Column(
                      children: [
                        dateField,
                        const SizedBox(height: 20),
                        validUntilField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: dateField),
                      const SizedBox(width: 24),
                      Expanded(child: validUntilField),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicalItems(
      BuildContext context,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: 'bill_of_materials'.tr(ref),
          subtitle: '${'required_components'.tr(ref)} ${_type.label} system',
          icon: Icons.inventory_2_outlined,
        ),
        const SizedBox(height: 32),
        ...List.generate(
          _items.length,
              (index) {
            return _ItemEditor(
              key: ValueKey(
                _items[index],
              ),
              item: _items[index],
              onChanged: _recalculate,
              onDelete: () {
                setState(() {
                  _items[index].dispose();
                  _items.removeAt(index);

                  _refreshSortOrders();
                });
              },
            );
          },
        ),

        const SizedBox(height: 16),

        Center(
          child: Container(
            width: 200,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3), width: 1.5),
            ),
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _items.add(
                    _QuotationItemForm(
                      category:
                      QuotationItemCategory
                          .other,
                      sortOrder:
                      _items.length,
                      onPriceChanged: _recalculate,
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add_rounded, color: AppColors.primaryTeal),
              label: Text('add_custom_item'.tr(ref), style: context.labelLarge?.bold.primary),
              style: OutlinedButton.styleFrom(
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPricing(
      BuildContext context,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: 'internal_pricing'.tr(ref),
          subtitle: 'costs_margins_taxes'.tr(ref),
          icon: Icons.calculate_outlined,
        ),
        const SizedBox(height: 32),
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('direct_costs_addons'.tr(ref).toUpperCase(), style: context.labelSmall?.extraBold.primary.withLetterSpacing(1.2)),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final small = constraints.maxWidth < 800;
                  final costFields = [
                    _priceField('additional_materials'.tr(ref), _materialsController, Icons.category_outlined),
                    _priceField('transportation'.tr(ref), _transportationController, Icons.local_shipping_outlined),
                    _priceField('installation'.tr(ref), _installationController, Icons.handyman_outlined),
                    _priceField('other_cost'.tr(ref), _otherCostController, Icons.more_horiz_outlined),
                  ];

                  if (small) {
                    return Column(
                      children: costFields.map((f) => Padding(padding: const EdgeInsets.only(bottom: 24), child: f)).toList(),
                    );
                  }

                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: costFields.map((f) => SizedBox(width: (constraints.maxWidth - 48) / 2, child: f)).toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              Text('pricing_logic'.tr(ref).toUpperCase(), style: context.labelSmall?.extraBold.primary.withLetterSpacing(1.2)),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final small = constraints.maxWidth < 800;
                  final pricingFields = [
                    _priceField('${'profit_margin'.tr(ref)} (%)', _profitMarginController, Icons.trending_up_rounded, isPercent: true),
                    _priceField('discount'.tr(ref), _discountController, Icons.sell_outlined),
                    _priceField('${'tax'.tr(ref)} (%)', _taxController, Icons.receipt_long_outlined, isPercent: true),
                  ];

                  if (small) {
                    return Column(
                      children: pricingFields.map((f) => Padding(padding: const EdgeInsets.only(bottom: 24), child: f)).toList(),
                    );
                  }

                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: pricingFields.map((f) => SizedBox(width: (constraints.maxWidth - 48) / 2, child: f)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuotationText(
      BuildContext context,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: 'document_content'.tr(ref),
          subtitle: 'official_text_pdf'.tr(ref),
          icon: Icons.description_outlined,
        ),
        const SizedBox(height: 32),
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('document_drafting'.tr(ref).toUpperCase(), style: context.labelSmall?.extraBold.primary.withLetterSpacing(1.2)),
              const SizedBox(height: 24),
              _field(
                label: 'introduction'.tr(ref),
                controller:
                _introductionController,
                icon: Icons.short_text_rounded,
                maxLines: 4,
              ),

              const SizedBox(height: 24),

              _field(
                label: 'general_terms'.tr(ref),
                controller:
                _generalTermsController,
                icon: Icons.gavel_rounded,
                maxLines: 5,
              ),

              const SizedBox(height: 24),

              _field(
                label: 'payment_terms'.tr(ref),
                controller:
                _paymentTermsController,
                icon: Icons.payments_outlined,
                maxLines: 4,
              ),

              const SizedBox(height: 24),

              _field(
                label: 'notes'.tr(ref),
                controller: _notesController,
                icon: Icons.notes_rounded,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _field({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      style: context.bodyLarge?.medium,
      decoration: _inputDecoration(label, icon: icon, isRequired: isRequired),
    );
  }

  Widget _priceField(
      String label,
      TextEditingController controller,
      IconData icon,
      {bool isPercent = false, bool isRequired = false}
      ) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: context.bodyLarge?.bold,
      decoration: _inputDecoration(
        label,
        icon: icon,
        suffix: isPercent ? '%' : 'EGP',
        isRequired: isRequired,
      ),
    );
  }

  InputDecoration _inputDecoration(
      String label,
      {IconData? icon, String? suffix, bool isRequired = false}
      ) {
    return customInputDecoration(context, label, icon: icon, suffix: suffix, isRequired: isRequired);
  }

  Widget _dateField(
      BuildContext context, {
        required String label,
        required DateTime? value,
        required ValueChanged<DateTime?>
        onChanged,
        bool isRequired = false,
      }) {
    return InkWell(
      onTap: () async {
        final picked =
        await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDate:
          value ?? DateTime.now(),
        );

        if (picked != null) {
          onChanged(picked);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: _inputDecoration(label, icon: Icons.calendar_today_rounded, isRequired: isRequired),
        child: Text(
          value == null
              ? 'select_date'.tr(ref)
              : '${value.day.toString().padLeft(2, '0')}/'
              '${value.month.toString().padLeft(2, '0')}/'
              '${value.year}',
          style: context.bodyLarge?.medium,
        ),
      ),
    );
  }

  void _initializeRequiredItems(
      QuotationType type,
      ) {
    final categories =
    _requiredCategories(type);

    for (final item in _items) {
      item.dispose();
    }

    _items.clear();

    for (int i = 0;
    i < categories.length;
    i++) {
      _items.add(
        _QuotationItemForm(
          category: categories[i],
          sortOrder: i,
          item:
          _defaultItemName(
            categories[i],
            ref,
          ),
          description:
          _defaultItemDescription(
            categories[i],
            ref,
          ),
          onPriceChanged: _recalculate,
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _initializeItemsFromExisting(
      List<QuotationItemModel> items,
      ) {
    for (final item in _items) {
      item.dispose();
    }

    _items.clear();

    for (final item in items) {
      _items.add(
        _QuotationItemForm.fromModel(
          item,
          onPriceChanged: _recalculate,
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  List<QuotationItemCategory>
  _requiredCategories(
      QuotationType type,
      ) {
    switch (type) {
      case QuotationType.onGrid:
        return [
          QuotationItemCategory.solarPanels,
          QuotationItemCategory.structure,
          QuotationItemCategory.inverter,
          QuotationItemCategory.dcCables,
          QuotationItemCategory.dcCombiner,
          QuotationItemCategory.cableTray,
          QuotationItemCategory.grounding,
          QuotationItemCategory.mc4,
          QuotationItemCategory.transportation,
          QuotationItemCategory.installation,
          QuotationItemCategory.maintenance,
        ];

      case QuotationType.offGrid:
        return [
          QuotationItemCategory.solarPanels,
          QuotationItemCategory.structure,
          QuotationItemCategory.inverter,
          QuotationItemCategory.dcCables,
          QuotationItemCategory.dcCombiner,
          QuotationItemCategory.cableTray,
          QuotationItemCategory.grounding,
          QuotationItemCategory.mc4,
          QuotationItemCategory.transportation,
          QuotationItemCategory.installation,
          QuotationItemCategory.maintenance,
          QuotationItemCategory.batteries,
        ];

      case QuotationType.solarPump:
        return [
          QuotationItemCategory.solarPanels,
          QuotationItemCategory.structure,
          QuotationItemCategory.inverter,
          QuotationItemCategory.dcCables,
          QuotationItemCategory.inverterPanel,
          QuotationItemCategory.dcCombiner,
          QuotationItemCategory.cablePipes,
          QuotationItemCategory.grounding,
          QuotationItemCategory.mc4,
          QuotationItemCategory.transportation,
          QuotationItemCategory.installation,
          QuotationItemCategory.maintenance,
        ];
    }
  }

  String _defaultItemName(
      QuotationItemCategory category,
      WidgetRef ref,
      ) {
    return category.labelKey.tr(ref);
  }

  String _defaultItemDescription(
      QuotationItemCategory category,
      WidgetRef ref,
      ) {
    switch (category) {
      case QuotationItemCategory.solarPanels:
        return 'solar_panels'.tr(ref);
      case QuotationItemCategory.structure:
        return 'mounting_structure'.tr(ref);
      case QuotationItemCategory.inverter:
        return 'inverter'.tr(ref);
      case QuotationItemCategory.dcCables:
        return 'dc_cables'.tr(ref);
      case QuotationItemCategory.dcCombiner:
        return 'dc_combiner'.tr(ref);
      case QuotationItemCategory.cableTray:
        return 'cable_tray'.tr(ref);
      case QuotationItemCategory.grounding:
        return 'grounding_system'.tr(ref);
      case QuotationItemCategory.mc4:
        return 'MC4';
      case QuotationItemCategory.transportation:
        return 'transportation_item'.tr(ref);
      case QuotationItemCategory.installation:
        return 'installation_item'.tr(ref);
      case QuotationItemCategory.maintenance:
        return 'maintenance'.tr(ref);
      case QuotationItemCategory.batteries:
        return 'batteries'.tr(ref);
      case QuotationItemCategory.inverterPanel:
        return 'inverter_panel'.tr(ref);
      case QuotationItemCategory.cablePipes:
        return 'cable_pipes'.tr(ref);
      case QuotationItemCategory.other:
        return 'other'.tr(ref);
    }
  }

  void _refreshSortOrders() {
    for (int i = 0;
    i < _items.length;
    i++) {
      _items[i].sortOrder = i;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_selectedCustomer == null) {
      _showError(
        'Please select a customer.',
      );

      return;
    }

    if (_capacityController.text
            .trim()
            .isEmpty ||
        double.tryParse(
              _capacityController.text,
            ) ==
            null ||
        double.parse(
              _capacityController.text,
            ) <=
            0) {
      _showError(
        'System capacity is required.',
      );
      return;
    }

    final profitMargin = _parseMoney(_profitMarginController);
    final tax = _parseMoney(_taxController);

    if (profitMargin < 0 || profitMargin > 100) {
      _showError('Profit Margin must be between 0% and 100%.');
      return;
    }

    if (tax < 0 || tax > 100) {
      _showError('Tax must be between 0% and 100%.');
      return;
    }

    final missing =
    _findMissingRequiredCategories();

    if (missing.isNotEmpty) {
      _showError(
        'Missing required categories: '
            '${missing.map((e) => e.label).join(', ')}',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final data = _buildPayload();

      final repository = ref.read(
        quotationsRepositoryProvider,
      );

      if (widget.isEdit) {
        await repository.update(
          widget.quotationId!,
          data,
        );
        DataRefreshCoordinator.refresh(ref);

        ref.invalidate(
          quotationProvider(
            widget.quotationId!,
          ),
        );
      } else {
        await repository.create(
          data,
        );
        DataRefreshCoordinator.refresh(ref);
      }

      ref.invalidate(
        quotationsProvider,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? 'quotation_updated_success'.tr(ref)
                : 'quotation_created_success'.tr(ref),
          ),
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;

      _showError(
        e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'customerId':
      _selectedCustomer!.id,

      'type':
      _type.value,

      'projectId':
      _selectedProject?.id,

      'quotationDate':
      _quotationDate
          ?.toUtc()
          .toIso8601String(),

      'validUntil':
      _validUntil
          ?.toUtc()
          .toIso8601String(),

      'systemDescription':
      _nullableText(
        _systemDescriptionController,
      ),

      'systemCapacity':
      _parseDecimal(
        _capacityController.text,
      ),

      'capacityUnit':
      _capacityUnit,

      'introduction':
      _nullableText(
        _introductionController,
      ),

      'generalTerms':
      _nullableText(
        _generalTermsController,
      ),

      'paymentTerms':
      _nullableText(
        _paymentTermsController,
      ),

      'notes':
      _nullableText(
        _notesController,
      ),

      'items':
      _items
          .map(
            (item) =>
            item.toMap(),
      )
          .toList(),

      'materialsCost':
      _parseMoney(
        _materialsController,
      ),

      'transportationCost':
      _parseMoney(
        _transportationController,
      ),

      'installationCost':
      _parseMoney(
        _installationController,
      ),

      'otherCost':
      _parseMoney(
        _otherCostController,
      ),

      'profitMargin':
      _parseMoney(
        _profitMarginController,
      ),

      'discount':
      _parseMoney(
        _discountController,
      ),

      'tax':
      _parseMoney(
        _taxController,
      ),
    };
  }

  List<QuotationItemCategory>
  _findMissingRequiredCategories() {
    final required =
    _requiredCategories(_type);

    final existing = _items
        .map((e) => e.category)
        .toSet();

    return required
        .where(
          (category) =>
      !existing.contains(category),
    )
        .toList();
  }

  double? _parseDecimal(
      String value,
      ) {
    final text = value.trim();

    if (text.isEmpty) return null;

    return double.tryParse(text);
  }

  double _parseMoney(
      TextEditingController controller,
      ) {
    return double.tryParse(
      controller.text.trim(),
    ) ??
        0;
  }

  ({
    double subtotal,
    double totalCost,
    double marginAmount,
    double discountAmount,
    double taxAmount,
    double total,
  }) _calculateSummary() {
    double itemsSellingPrice = 0;
    double itemsCostPrice = 0;

    for (final item in _items) {
      final qty = double.tryParse(item.quantityController.text) ?? 0;
      itemsSellingPrice += (item.unitPrice ?? 0) * qty;
      itemsCostPrice += (item.unitCost ?? 0) * qty;
    }

    final additionalMaterials = _parseMoney(_materialsController);
    final transportation = _parseMoney(_transportationController);
    final installation = _parseMoney(_installationController);
    final other = _parseMoney(_otherCostController);

    final totalAdditionalCost = additionalMaterials + transportation + installation + other;
    final subtotal = itemsSellingPrice + totalAdditionalCost;

    final marginPercent = _parseMoney(_profitMarginController);
    final marginAmount = subtotal * (marginPercent / 100);

    final beforeDiscount = subtotal + marginAmount;
    final discountAmount = _parseMoney(_discountController);
    final taxableAmount = (beforeDiscount - discountAmount).clamp(0, double.infinity).toDouble();

    final taxPercent = _parseMoney(_taxController);
    final taxAmount = taxableAmount * (taxPercent / 100);

    return (
      subtotal: subtotal,
      totalCost: itemsCostPrice + totalAdditionalCost,
      marginAmount: marginAmount,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      total: taxableAmount + taxAmount,
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final summary = _calculateSummary();

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryTeal, size: 20),
              ),
              const SizedBox(width: 12),
              Text('quotation_summary'.tr(ref), style: context.titleLarge?.black.withHeight(1.1)),
            ],
          ),
          const SizedBox(height: 32),
          _summaryRow(context, 'subtotal_items_addons'.tr(ref), summary.subtotal),
          const SizedBox(height: 12),
          _summaryRow(context, 'profit_margin'.tr(ref), summary.marginAmount, isAccent: true),
          const SizedBox(height: 12),
          _summaryRow(context, 'discount'.tr(ref), -summary.discountAmount, isNegative: true),
          const SizedBox(height: 12),
          _summaryRow(context, 'tax'.tr(ref), summary.taxAmount),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('estimated_total'.tr(ref).toUpperCase(), style: context.labelMedium?.extraBold.withColor(context.appTheme.textMuted).withLetterSpacing(1.1)),
                  const SizedBox(height: 6),
                  Text(
                    summary.total.toStringAsFixed(2),
                    style: context.headlineLarge?.black.primary.withHeight(1.0),
                  ),
                ],
              ),
              Text(
                'EGP',
                style: context.titleLarge?.bold.withColor(AppColors.primaryTeal.withValues(alpha: 0.4)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics_outlined, size: 18, color: context.appTheme.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('internal_cost'.tr(ref), style: context.labelSmall?.bold.withColor(context.appTheme.textMuted)),
                      Text(
                        '${summary.totalCost.toStringAsFixed(2)} EGP',
                        style: context.bodyMedium?.bold,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, double value, {bool isNegative = false, bool isAccent = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.bodyMedium?.semiBold.withColor(isAccent ? AppColors.primaryTeal : context.onSurfaceVariant)),
          Text(
            '${value >= 0 ? '' : '-'}${value.abs().toStringAsFixed(2)} EGP',
            style: context.bodyMedium?.extraBold.withColor(isNegative ? AppColors.error : (isAccent ? AppColors.primaryTeal : context.onSurfaceColor)),
          ),
        ],
      ),
    );
  }

  String? _nullableText(
      TextEditingController controller,
      ) {
    final value =
    controller.text.trim();

    return value.isEmpty ? null : value;
  }

  void _showError(
      String message,
      ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        AppColors.error,
      ),
    );
  }
}


class _QuotationItemForm {
  _QuotationItemForm({
    required this.category,
    this.productComponentId,
    this.unitCost,
    this.unitPrice,
    this.item = '',
    this.description = '',
    this.quantity,
    this.unit,
    this.countryOfOrigin,
    this.internalNotes,
    this.sortOrder = 0,
    VoidCallback? onPriceChanged,
  }) {
    itemController.text = item;
    descriptionController.text =
        description;
    quantityController.text =
        quantity?.toString() ?? '';
    unitController.text = unit ?? '';
    originController.text =
        countryOfOrigin ?? '';
    notesController.text =
        internalNotes ?? '';

    if (onPriceChanged != null) {
      quantityController.addListener(onPriceChanged);
    }
  }

  factory _QuotationItemForm.fromModel(
      QuotationItemModel model,
      {VoidCallback? onPriceChanged}
      ) {
    final form = _QuotationItemForm(
      category: model.category,
      productComponentId: model.productComponentId,
      unitCost: model.unitCost,
      unitPrice: model.unitPrice,
      item: model.item,
      description: model.description,
      quantity: model.quantity,
      unit: model.unit,
      countryOfOrigin:
      model.countryOfOrigin,
      internalNotes:
      model.internalNotes,
      sortOrder:
      model.sortOrder,
      onPriceChanged: onPriceChanged,
    );
    return form;
  }

  QuotationItemCategory category;
  int? productComponentId;
  double? unitCost;
  double? unitPrice;

  String item;
  String description;
  double? quantity;
  String? unit;
  String? countryOfOrigin;
  String? internalNotes;
  int sortOrder;

  final itemController =
  TextEditingController();

  final descriptionController =
  TextEditingController();

  final quantityController =
  TextEditingController();

  final unitController =
  TextEditingController();

  final originController =
  TextEditingController();

  final notesController =
  TextEditingController();

  Map<String, dynamic> toMap() {
    return {
      'productComponentId': productComponentId,
      'description':
      descriptionController.text.trim(),

      'item':
      itemController.text.trim(),

      'category':
      category.value,

      'quantity':
      double.tryParse(
        quantityController.text.trim(),
      ),

      'unit':
      unitController.text.trim().isEmpty
          ? null
          : unitController.text.trim(),

      'countryOfOrigin':
      originController.text.trim().isEmpty
          ? null
          : originController.text.trim(),

      'sortOrder':
      sortOrder,

      'internalNotes':
      notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
      'unitCost': unitCost,
      'unitPrice': unitPrice,
    };
  }

  void dispose() {
    itemController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    unitController.dispose();
    originController.dispose();
    notesController.dispose();
  }
}

class _ItemEditor extends ConsumerStatefulWidget {
  const _ItemEditor({
    super.key,
    required this.item,
    required this.onDelete,
    this.onChanged,
  });

  final _QuotationItemForm item;
  final VoidCallback onDelete;
  final VoidCallback? onChanged;

  @override
  ConsumerState<_ItemEditor> createState() =>
      _ItemEditorState();
}

class _ItemEditorState
    extends ConsumerState<_ItemEditor> {
  bool _isExpanded = false;

  @override
  Widget build(
      BuildContext context,
      ) {
    final item = widget.item;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _isExpanded ? AppColors.primaryTeal.withValues(alpha: 0.3) : context.borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _isExpanded 
                ? AppColors.primaryTeal.withValues(alpha: 0.05) 
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: _isExpanded ? AppColors.primaryTeal.withValues(alpha: 0.02) : context.appTheme.surfaceSubtle,
                  border: Border(bottom: BorderSide(color: context.borderColor, width: _isExpanded ? 1 : 0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${item.sortOrder + 1}',
                          style: context.titleSmall?.bold.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemController.text.isEmpty ? item.category.label : item.itemController.text,
                            style: context.bodyLarge?.extraBold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.category.label.toUpperCase(),
                            style: context.labelSmall?.bold.withColor(context.appTheme.textMuted).withLetterSpacing(0.8),
                          ),
                        ],
                      ),
                    ),
                    if (!_isExpanded && item.quantityController.text.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.appTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Text(
                          '× ${item.quantityController.text}',
                          style: context.labelSmall?.bold,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        ActionButton(
                          icon: Icons.delete_outline_rounded,
                          color: AppColors.error,
                          onPressed: widget.onDelete,
                          tooltip: 'delete'.tr(ref),
                          padding: 10,
                          alpha: 0.1,
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: context.appTheme.textMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('item_details'.tr(ref).toUpperCase(), style: context.labelSmall?.bold.primary.withLetterSpacing(1.1)),
                    const SizedBox(height: 20),
                    _buildProductSelector(context, item),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final small = constraints.maxWidth < 700;
                        
                        final categoryField = _GlassDropdown<QuotationItemCategory>(
                          label: 'category'.tr(ref),
                          isRequired: true,
                          hint: 'select_category'.tr(ref),
                          value: item.category,
                          items: QuotationItemCategory.values,
                          icon: Icons.category_outlined,
                          itemBuilder: (context, category) => Text(
                            category.label,
                            style: context.bodyMedium,
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => item.category = value);
                            widget.onChanged?.call();
                          },
                        );

                        final nameField = _textField(
                          controller: item.itemController,
                          label: 'item_name_required'.tr(ref),
                          isRequired: true,
                          icon: Icons.title_rounded,
                          validator: (value) => (value == null || value.trim().length < 2) ? 'required'.tr(ref) : null,
                        );

                        if (small) return Column(children: [categoryField, const SizedBox(height: 24), nameField]);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: categoryField),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: nameField)
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _textField(
                      controller: item.descriptionController,
                      label: 'description'.tr(ref),
                      isRequired: true,
                      icon: Icons.notes_rounded,
                      maxLines: 2,
                      validator: (value) => (value == null || value.trim().length < 2) ? 'required'.tr(ref) : null,
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final small = constraints.maxWidth < 700;
                        final quantity = _textField(
                          controller: item.quantityController,
                          label: 'quantity'.tr(ref),
                          isRequired: true,
                          icon: Icons.numbers_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        );
                        final unit = _textField(
                          controller: item.unitController, 
                          label: 'unit'.tr(ref), 
                          isRequired: true,
                          icon: Icons.straighten_rounded
                        );
                        final origin = _textField(controller: item.originController, label: 'origin'.tr(ref), icon: Icons.public_rounded);
                        
                        if (small) return Column(children: [quantity, const SizedBox(height: 24), unit, const SizedBox(height: 24), origin]);
                        return Row(
                          children: [
                            Expanded(child: quantity),
                            const SizedBox(width: 20),
                            Expanded(child: unit),
                            const SizedBox(width: 20),
                            Expanded(child: origin),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _textField(
                      controller: item.notesController, 
                      label: 'internal_notes_optional'.tr(ref), 
                      icon: Icons.lock_outline_rounded, 
                      maxLines: 2
                    ),
                  ],
                ),
              ),
              crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
              sizeCurve: Curves.easeInOutCubic,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSelector(BuildContext context, _QuotationItemForm item) {
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      loading: () => _selectorLoading(
        'product_component_catalog'.tr(ref),
        icon: Icons.shopping_bag_outlined,
      ),
      error: (error, _) => _selectorError(
        'Catalog unavailable: $error',
        icon: Icons.error_outline_rounded,
      ),
      data: (products) {
        final selectableProducts = products.where((p) => p.isActive || p.id == item.productComponentId).toList();
        ProductComponentModel? selected;
        for (final product in selectableProducts) {
          if (product.id == item.productComponentId) {
            selected = product;
            break;
          }
        }

        final items = [null, ...selectableProducts];

        return _GlassDropdown<ProductComponentModel?>(
          label: 'product_component_catalog'.tr(ref),
          hint: 'product_component_catalog'.tr(ref),
          value: selected,
          items: items,
          icon: Icons.shopping_bag_outlined,
          itemBuilder: (context, product) {
            if (product == null) {
              return Text(
                'manual_item_no_catalog'.tr(ref),
                style: context.bodyMedium?.semiBold,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${product.code} — ${product.displayName}',
                  style: context.bodyMedium?.bold,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${'cost'.tr(ref)}: ${product.costPrice.toStringAsFixed(2)} | ${'selling'.tr(ref)}: ${product.sellingPrice.toStringAsFixed(2)}',
                  style: context.labelSmall?.withColor(context.appTheme.textMuted),
                ),
              ],
            );
          },
          onChanged: (product) {
            setState(() {
              item.productComponentId = product?.id;
              item.unitCost = product?.costPrice;
              item.unitPrice = product?.sellingPrice;

              if (product != null) {
                item.category = QuotationItemCategory.fromValue(product.category.value);
                item.itemController.text = product.displayName;
                item.descriptionController.text = product.specification ?? product.name;
                item.unitController.text = product.unit;
                item.originController.text = product.countryOfOrigin ?? '';
              }
            });
            widget.onChanged?.call();
          },
        );
      },
    );
  }

  Widget _selectorLoading(String text, {IconData? icon}) {
    return InputDecorator(
      decoration: customInputDecoration(context, '', icon: icon),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: context.bodyMedium?.withColor(context.appTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _selectorError(String text, {IconData? icon}) {
    return InputDecorator(
      decoration: customInputDecoration(context, '', icon: icon),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: context.errorColor, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: context.bodyMedium?.withColor(context.errorColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController
    controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: context.bodyLarge?.medium,
      decoration: customInputDecoration(context, label, icon: icon, isRequired: isRequired),
    );
  }
}

class _StepBubble extends StatelessWidget {
  const _StepBubble({
    required this.index,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    this.showLabel = true,
    this.size = 32,
  });

  final int index;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final bool showLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = isActive || isCompleted ? AppColors.primaryTeal : context.appTheme.textMuted;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isCompleted ? AppColors.primaryTeal : (isActive ? AppColors.primaryTeal.withValues(alpha: 0.1) : Colors.transparent),
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: size * 0.0625, // Responsive border width
            ),
            boxShadow: isActive ? [
              BoxShadow(
                color: AppColors.primaryTeal.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: size * 0.5, color: Colors.white)
                : Text(
                    '$index',
                    style: TextStyle(
                      color: isActive ? AppColors.primaryTeal : context.appTheme.textMuted,
                      fontWeight: FontWeight.w900,
                      fontSize: size * 0.375,
                    ),
                  ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: context.labelSmall?.bold.withColor(color).withSize(10).withLetterSpacing(0.5),
          ),
        ],
      ],
    );
  }
}

class _GlassDropdown<T> extends StatefulWidget {
  const _GlassDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.itemBuilder,
    this.validator,
    this.icon,
    this.enabled = true,
    this.isRequired = false,
  });

  final String label;
  final String hint;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final Widget Function(BuildContext, T) itemBuilder;
  final String? Function(T?)? validator;
  final IconData? icon;
  final bool enabled;
  final bool isRequired;

  @override
  State<_GlassDropdown<T>> createState() => _GlassDropdownState<T>();
}

class _GlassDropdownState<T> extends State<_GlassDropdown<T>> {
  final MenuController _controller = MenuController();
  bool _isHovered = false;
  bool _isClosing = false;

  void _handleSelect(T item) async {
    setState(() => _isClosing = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      widget.onChanged(item);
      _controller.close();
      setState(() => _isClosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: widget.value,
      validator: widget.validator,
      builder: (state) {
        final hasError = state.hasError;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: MenuAnchor(
                controller: _controller,
                alignmentOffset: const Offset(0, 8),
                onClose: () => setState(() => _isClosing = false),
                style: MenuStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.transparent),
                  elevation: WidgetStateProperty.all(0),
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                  shadowColor: WidgetStateProperty.all(Colors.transparent),
                  surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
                ),
                menuChildren: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    tween: Tween(begin: 0.0, end: _isClosing ? 0.0 : 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Transform.scale(
                            scale: 0.95 + (0.05 * value),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: GlassContainer(
                      borderRadius: 20,
                      blur: 25,
                      padding: EdgeInsets.zero,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...widget.items.map((item) {
                                final isSelected = widget.value == item;
                                final isNullItem = item == null;
                                
                                return _GlassDropdownItem(
                                  isSelected: isSelected,
                                  isSpecial: isNullItem,
                                  onTap: () => _handleSelect(item),
                                  child: widget.itemBuilder(context, item),
                                );
                              }),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                builder: (context, controller, child) {
                  final isOpen = controller.isOpen;
                  
                  // Special check for nullable types where null might be a valid selection (like "Manual Item")
                  final hasValidSelection = widget.value != null || (widget.items.contains(null) && widget.value == null && !isOpen);
                  final showLabel = hasValidSelection || isOpen;
                  
                  return InkWell(
                    onTap: widget.enabled ? () => isOpen ? controller.close() : controller.open() : null,
                    borderRadius: BorderRadius.circular(28),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      constraints: const BoxConstraints(minHeight: 54),
                      decoration: BoxDecoration(
                        color: context.onSurfaceColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: hasError 
                            ? AppColors.error 
                            : (isOpen ? AppColors.primaryTeal : (_isHovered ? AppColors.primaryTeal.withValues(alpha: 0.5) : context.borderColor)),
                          width: (isOpen || hasError) ? 2 : 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              size: 20,
                              color: isOpen || hasValidSelection ? AppColors.primaryTeal : context.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (showLabel)
                                  Text.rich(
                                    TextSpan(
                                      text: widget.label.replaceAll(' *', '').replaceAll('*', '').trim(),
                                      style: context.labelSmall?.extraBold.primary.withSize(10),
                                      children: [
                                        if (widget.isRequired)
                                          const TextSpan(
                                            text: ' *',
                                            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                    ),
                                  ),
                                if (hasValidSelection && !isOpen)
                                  widget.itemBuilder(context, widget.value as T)
                                else if (!isOpen)
                                  Text(
                                    widget.hint,
                                    style: context.bodyMedium?.withColor(context.appTheme.textMuted),
                                  )
                                else
                                  const SizedBox.shrink(),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: isOpen ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: context.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 6),
                child: Text(
                  state.errorText!,
                  style: context.labelSmall?.bold.withColor(context.errorColor),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GlassDropdownItem extends StatefulWidget {
  const _GlassDropdownItem({
    required this.child,
    required this.isSelected,
    required this.onTap,
    this.isSpecial = false,
  });

  final Widget child;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isSpecial;

  @override
  State<_GlassDropdownItem> createState() => _GlassDropdownItemState();
}

class _GlassDropdownItemState extends State<_GlassDropdownItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isSpecial 
        ? context.onSurfaceColor.withValues(alpha: 0.12) 
        : Colors.transparent;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.isSpecial ? 0 : 8).copyWith(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: widget.isSpecial ? BorderRadius.zero : BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: widget.isSpecial ? 20 : 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isSelected 
                  ? AppColors.primaryTeal.withValues(alpha: 0.12) 
                  : _isHovered 
                      ? AppColors.primaryTeal.withValues(alpha: 0.08) 
                      : baseColor,
              borderRadius: widget.isSpecial ? BorderRadius.zero : BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: widget.child),
                if (widget.isSelected && !widget.isSpecial)
                  const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primaryTeal),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
