import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/localization/language_provider.dart';
import '../../../core/localization/date_formatter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_models.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/theme/typography_extensions.dart';
import '../data/calendar_repository.dart';
import '../../dashboard/data/dashboard_repository.dart' show dashboardProvider;
import '../../../core/services/event_reminder_scheduler.dart';

final calendarSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredCalendarEventsProvider = Provider<AsyncValue<List<CalendarEvent>>>((ref) {
  final eventsAsync = ref.watch(calendarEventsProvider);
  final searchQuery = ref.watch(calendarSearchQueryProvider).toLowerCase();

  return eventsAsync.whenData((events) {
    if (searchQuery.isEmpty) return events;
    return events.where((e) {
      return e.title.toLowerCase().contains(searchQuery) ||
          (e.description?.toLowerCase().contains(searchQuery) ?? false);
    }).toList();
  });
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(filteredCalendarEventsProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 1100;
          
          return eventsAsync.when(
            data: (events) {
              final eventsMap = <DateTime, List<CalendarEvent>>{};
              for (var event in events) {
                final day = DateTime(event.date.year, event.date.month, event.date.day);
                eventsMap[day] ??= [];
                eventsMap[day]!.add(event);
              }

              final selectedDateOnly = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
              final dayEvents = eventsMap[selectedDateOnly] ?? [];
              final isDesktop = !isMobile;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderColor, width: 1.2),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                              child: isMobile
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _SearchField(
                                          onChanged: (v) => ref.read(calendarSearchQueryProvider.notifier).state = v,
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: const _AddEventButton(),
                                        ),
                                        const SizedBox(height: 12),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: _CalendarTopBar(
                                            focusedDay: _focusedDay,
                                            onNavigate: (day) => setState(() => _focusedDay = day),
                                            onToday: () => setState(() {
                                              _focusedDay = DateTime.now();
                                              _selectedDay = _focusedDay;
                                            }),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: _SearchField(
                                            onChanged: (v) => ref.read(calendarSearchQueryProvider.notifier).state = v,
                                          ),
                                        ),
                                        const Spacer(),
                                        _CalendarTopBar(
                                          focusedDay: _focusedDay,
                                          onNavigate: (day) => setState(() => _focusedDay = day),
                                          onToday: () => setState(() {
                                            _focusedDay = DateTime.now();
                                            _selectedDay = _focusedDay;
                                          }),
                                        ),
                                        const SizedBox(width: 16),
                                        const _AddEventButton(),
                                      ],
                                    ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: isDesktop
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 6,
                                          child: SingleChildScrollView(
                                            child: _FadeIn(
                                              delay: 0,
                                              child: _buildCalendarCard(eventsMap, locale),
                                            ),
                                          ),
                                        ),
                                        VerticalDivider(width: 1, color: context.borderColor),
                                        Expanded(
                                          flex: 4,
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: _buildEventList(dayEvents, isScrollable: true),
                                          ),
                                        ),
                                      ],
                                    )
                                  : SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _FadeIn(
                                            delay: 0,
                                            child: _buildCalendarCard(eventsMap, locale, isMobile: true),
                                          ),
                                          const Divider(height: 1),
                                          Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: SizedBox(
                                              height: 500,
                                              child: _buildEventList(dayEvents, isScrollable: true),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
            loading: () => const LoadingOverlay(),
            error: (err, _) => Center(child: Text('${'error'.tr(ref)}: $err', style: context.bodyLarge)),
          );
        },
      ),
    );
  }

  Widget _buildCalendarCard(Map<DateTime, List<CalendarEvent>> events, Locale locale, {bool isMobile = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.surfaceColor,
      ),
      child: TableCalendar(
        locale: locale.languageCode,
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          _showDayEventsOverlay(context, events[DateTime(selectedDay.year, selectedDay.month, selectedDay.day)] ?? [], selectedDay, locale);
        },
        onPageChanged: (focusedDay) {
          setState(() => _focusedDay = focusedDay);
        },
        eventLoader: (day) => events[DateTime(day.year, day.month, day.day)] ?? [],
        startingDayOfWeek: StartingDayOfWeek.saturday,
        weekendDays: const [DateTime.friday],
        daysOfWeekHeight: isMobile ? 50 : 70,
        rowHeight: isMobile ? 70 : 90,
        headerVisible: false,
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: (isMobile ? context.labelSmall : context.labelMedium)?.extraBold.withColor(context.onSurfaceVariant) ?? const TextStyle(),
          weekendStyle: (isMobile ? context.labelSmall : context.labelMedium)?.extraBold.withColor(context.errorColor) ?? const TextStyle(),
          decoration: BoxDecoration(
            color: context.primaryColor.withValues(alpha: 0.03),
            border: Border(bottom: BorderSide(color: context.borderColor, width: 1)),
          ),
        ),
        calendarStyle: CalendarStyle(
          defaultTextStyle: (isMobile ? context.titleSmall : context.titleMedium)?.extraBold ?? const TextStyle(),
          weekendTextStyle: (isMobile ? context.titleSmall : context.titleMedium)?.extraBold.withColor(context.errorColor) ?? const TextStyle(),
          todayDecoration: BoxDecoration(
            color: context.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
            border: Border.all(color: context.primaryColor.withValues(alpha: 0.3), width: 1.5),
          ),
          todayTextStyle: (isMobile ? context.titleSmall : context.titleMedium)?.extraBold.primary ?? const TextStyle(),
          selectedDecoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryTeal, AppColors.primaryTealDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryTeal.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          selectedTextStyle: (isMobile ? context.titleSmall : context.titleMedium)?.extraBold.white ?? const TextStyle(),
          markerDecoration: const BoxDecoration(color: AppColors.accentGold, shape: BoxShape.circle),
          markersMaxCount: 1,
          outsideDaysVisible: false,
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) => _buildDayCell(day, isWeekend: day.weekday == DateTime.friday, isMobile: isMobile),
          outsideBuilder: (context, day, focusedDay) => const SizedBox.shrink(),
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return null;
            final eventList = events as List<CalendarEvent>;
            return Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: eventList.take(4).map((event) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getEventColor(event.type),
                      border: Border.all(color: context.surfaceColor, width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: _getEventColor(event.type).withValues(alpha: 0.3),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime day, {bool isWeekend = false, bool isMobile = false}) {
    return Container(
      margin: EdgeInsets.all(isMobile ? 6 : 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isWeekend
            ? context.errorColor.withValues(alpha: context.theme.brightness == Brightness.dark ? 0.08 : 0.03)
            : (context.theme.brightness == Brightness.dark ? AppColors.white.withValues(alpha: 0.03) : context.primaryColor.withValues(alpha: 0.015)),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
      ),
      child: Text(
        '${day.day}',
        style: (isMobile ? context.titleSmall : context.titleMedium)?.extraBold.withColor(
          isWeekend ? context.errorColor.withValues(alpha: 0.8) : context.onSurfaceColor,
        ),
      ),
    );
  }


  void _showDayEventsOverlay(BuildContext context, List<CalendarEvent> events, DateTime date, Locale locale) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 40,
          vertical: 24,
        ),
        child: Container(
          width: isMobile ? double.infinity : 900,
          height: isMobile ? MediaQuery.of(context).size.height * 0.8 : 650,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: context.theme.brightness == Brightness.dark ? 0.4 : 0.2),
                blurRadius: 50,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: isMobile 
            ? Column(children: _buildSpotlightPanes(context, events, date, true, locale))
            : Row(children: _buildSpotlightPanes(context, events, date, false, locale)),
        ),
      ),
    );
  }

  List<Widget> _buildSpotlightPanes(BuildContext context, List<CalendarEvent> events, DateTime date, bool isMobile, Locale locale) {
    final dayNum = date.format('dd', locale.languageCode);
    final monthName = date.format('MMMM', locale.languageCode);
    final dayName = date.format('EEEE', locale.languageCode);

    return [
      Container(
        width: isMobile ? double.infinity : 320,
        height: isMobile ? 180 : double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              context.primaryColor,
              context.primaryColor.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -20,
              child: Text(
                dayNum,
                style: context.displayLarge?.black.white.withSize(200).withHeight(1).withColor(
                  Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      dayName.toUpperCase(),
                      style: context.labelSmall?.extraBold.white.withLetterSpacing(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    dayNum,
                    style: context.displayLarge?.black.white.withSize(80).withHeight(1).copyWith(letterSpacing: -4),
                  ),
                  Text(
                    monthName,
                    style: context.displaySmall?.black.withColor(Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
            if (isMobile)
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                ),
              ),
          ],
        ),
      ),
      
      Expanded(
        child: Container(
          color: context.theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              if (!isMobile)
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                  child: Row(
                    children: [
                      Text(
                        'upcoming_events'.tr(ref),
                        style: context.titleLarge?.extraBold,
                      ),
                      const Spacer(),
                      ActionButton(
                        icon: Icons.close_rounded,
                        color: context.onSurfaceColor,
                        tooltip: 'close'.tr(ref),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    if (events.isEmpty)
                      Center(child: _buildEmptyEventsPlaceholder(minimal: true))
                    else
                      ListView.separated(
                        padding: const EdgeInsets.fromLTRB(32, 32, 32, 100),
                        itemCount: events.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) => _FadeIn(
                          delay: (index + 1) * 80,
                          child: _CalendarEventCard(event: events[index]),
                        ),
                      ),
                    
                    Positioned(
                      bottom: 24,
                      left: 32,
                      right: 32,
                      child: _FadeIn(
                        delay: 300,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            showEventDialog(context, ref);
                          },
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: context.primaryColor.withValues(alpha: 0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.black.withValues(alpha: context.theme.brightness == Brightness.dark ? 0.2 : 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 20),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: context.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add_rounded, color: AppColors.white, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'add_event'.tr(ref),
                                  style: context.titleMedium?.extraBold.primary,
                                ),
                                const Spacer(),
                                Icon(Icons.chevron_right_rounded, color: context.primaryColor.withValues(alpha: 0.4)),
                                const SizedBox(width: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildEmptyEventsPlaceholder({bool minimal = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(minimal ? 24 : 40),
          decoration: BoxDecoration(
            color: context.primaryColor.withValues(alpha: 0.04),
            shape: BoxShape.circle,
          ),
          child: Icon(
            minimal ? Icons.event_available_rounded : Icons.event_note_rounded, 
            size: minimal ? 50 : 80, 
            color: context.primaryColor.withValues(alpha: 0.15)
          ),
        ),
        SizedBox(height: minimal ? 24 : 32),
        Text(
          'no_events_day'.tr(ref),
          style: minimal ? context.titleLarge?.extraBold : context.headlineMedium?.black,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: minimal ? 0 : 48),
          child: Text(
            'calendar_empty_desc'.tr(ref),
            textAlign: TextAlign.center,
            style: (minimal ? context.bodyMedium : context.bodyLarge)?.medium.withColor(context.onSurfaceVariant).withHeight(1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildEventList(List<CalendarEvent> events, {bool isScrollable = false}) {
    final listContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'schedule'.tr(ref).toUpperCase(),
                    style: context.labelSmall?.extraBold.withColor(
                      context.primaryColor.withValues(alpha: 0.6),
                    ).withLetterSpacing(2),
                  ),
                  Row(
                    children: [
                      Text(
                        'upcoming_events'.tr(ref),
                        style: context.headlineMedium?.black,
                      ),
                      if (events.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${events.length} ${'events'.tr(ref)}',
                            style: context.labelSmall?.extraBold.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (events.isEmpty)
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: _buildEmptyEventsPlaceholder(),
              ),
            ),
          )
        else ...[
          Expanded(
            child: ListView.separated(
              shrinkWrap: false,
              padding: const EdgeInsets.only(bottom: 12),
              physics: isScrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _FadeIn(
                  delay: (index + 1) * 80,
                  child: _CalendarEventCard(event: events[index]),
                );
              },
            ),
          ),
        ],
      ],
    );

    return listContent;
  }





  void _showDeleteConfirmation(BuildContext context, CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('delete_event'.tr(ref), style: context.titleLarge?.extraBold),
        content: Text('confirm_delete_event'.tr(ref), style: context.bodyLarge?.medium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(ref), style: context.labelLarge?.extraBold.withColor(context.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () async {
              final id = int.parse(event.id.split('_')[1]);
              await ref.read(calendarRepositoryProvider).deleteEvent(id);
              DataRefreshCoordinator.refresh(ref);
              EventReminderScheduler.instance.cancel(id);
              
              ref.invalidate(calendarEventsProvider);
              ref.invalidate(dashboardProvider);
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('event_deleted'.tr(ref)),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('delete'.tr(ref), style: context.labelLarge?.extraBold.withColor(context.errorColor)),
          ),
        ],
      ),
    );
  }
}

class _CalendarEventCard extends ConsumerWidget {
  const _CalendarEventCard({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final color = _getEventColor(event.type);
    final timeStr = event.date.toTime(locale.languageCode);

    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () {
          if (event.referenceType == 'customer') {
            context.go('/customers/${event.referenceId}');
          } else if (event.referenceType == 'project') {
            context.go('/projects/${event.referenceId}');
          }
        },
        borderRadius: BorderRadius.circular(28),
        hoverColor: color.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: context.theme.brightness == Brightness.dark ? 0.2 : 0.02),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      timeStr.split(' ')[0],
                      style: context.labelLarge?.extraBold.white,
                    ),
                    Text(
                      timeStr.split(' ')[1],
                      style: context.labelSmall?.extraBold.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TypePill(type: event.type, color: color),
                        const Spacer(),
                        if (event.referenceType != null)
                          _ReferencePill(type: event.referenceType!),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.title,
                      style: context.titleMedium?.extraBold,
                    ),
                    if (event.description != null && event.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.description!,
                        style: context.bodySmall?.medium.withColor(context.onSurfaceVariant).withHeight(1.4),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildEventActions(context, ref, color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventActions(BuildContext context, WidgetRef ref, Color color) {
    final isCustom = event.id.startsWith('custom_');

    if (isCustom) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ActionButton(
            icon: Icons.edit_rounded,
            color: context.primaryColor,
            tooltip: 'edit'.tr(ref),
            onPressed: () => showEventDialog(context, ref, eventToEdit: event),
          ),
          const SizedBox(width: 8),
          ActionButton(
            icon: Icons.delete_outline_rounded,
            color: context.errorColor,
            tooltip: 'delete'.tr(ref),
            onPressed: () {
              final state = context.findAncestorStateOfType<_CalendarScreenState>();
              state?._showDeleteConfirmation(context, event);
            },
          ),
        ],
      );
    }

    return ActionButton(
      icon: Icons.arrow_forward_ios_rounded,
      color: context.appTheme.textMuted,
      tooltip: 'view_details'.tr(ref),
      onPressed: () {
        if (event.referenceType == 'customer') {
          context.go('/customers/${event.referenceId}');
        } else if (event.referenceType == 'project') {
          context.go('/projects/${event.referenceId}');
        }
      },
    );
  }
}


Color _getEventColor(String type) {
  switch (type) {
    case 'installation': return AppColors.info;
    case 'follow_up': return AppColors.primaryTeal;
    case 'meeting': return AppColors.accentGold;
    default: return AppColors.textMuted;
  }
}

class _TypePill extends ConsumerWidget {
  const _TypePill({required this.type, required this.color});
  final String type;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.tr(ref).toUpperCase(),
        style: context.labelSmall?.extraBold.withColor(color),
      ),
    );
  }
}

class _ReferencePill extends ConsumerWidget {
  const _ReferencePill({required this.type});
  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.appTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == 'project' ? Icons.folder_shared_rounded : Icons.person_rounded,
            size: 10,
            color: context.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            type.tr(ref).toUpperCase(),
            style: context.labelSmall?.extraBold.withColor(context.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

void showEventDialog(BuildContext context, WidgetRef ref, {CalendarEvent? eventToEdit}) {
  final locale = ref.read(localeProvider);
  final formKey = GlobalKey<FormState>();
  final titleCtrl = TextEditingController(text: eventToEdit?.title);
  final descCtrl = TextEditingController(text: eventToEdit?.description);

  DateTime selectedDate = eventToEdit?.date ?? DateTime.now();
  TimeOfDay selectedTime = eventToEdit != null ? TimeOfDay.fromDateTime(eventToEdit.date) : TimeOfDay.now();
  String selectedType = eventToEdit?.type ?? AppConstants.eventTypes[0];

  bool isSaving = false;
  final isEditing = eventToEdit != null;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              
              return Dialog(
                backgroundColor: context.surfaceColor,
                insetPadding: EdgeInsets.all(isNarrow ? 12 : 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 600,
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  child: Container(
                    padding: EdgeInsets.all(isNarrow ? 20 : 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                isEditing ? 'edit_event'.tr(ref) : 'add_event'.tr(ref),
                                style: (isNarrow ? context.headlineSmall : context.headlineMedium)?.black,
                              ),
                            ),
                            IconButton(
                              onPressed: isSaving ? null : () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded, size: 28),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Form(
                              key: formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionHeader(context, 'basic_info'.tr(ref), icon: Icons.info_outline_rounded),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: context.appTheme.surfaceSubtle.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: context.borderColor),
                                    ),
                                    child: Column(
                                      children: [
                                        TextFormField(
                                          controller: titleCtrl,
                                          style: context.titleMedium?.extraBold,
                                          decoration: customInputDecoration(context, 'event_title'.tr(ref), icon: Icons.title_rounded),
                                          validator: (v) => (v == null || v.isEmpty) ? 'required'.tr(ref) : null,
                                        ),
                                        const SizedBox(height: 20),
                                        TextFormField(
                                          controller: descCtrl,
                                          style: context.bodyMedium?.semiBold,
                                          decoration: customInputDecoration(context, 'event_description'.tr(ref), icon: Icons.description_outlined),
                                          maxLines: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 32),
                                  _sectionHeader(context, 'event_type'.tr(ref), icon: Icons.category_outlined),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: context.appTheme.surfaceSubtle.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: context.borderColor),
                                    ),
                                    child: DropdownButtonFormField<String>(
                                      initialValue: selectedType,
                                      isExpanded: true,
                                      style: context.titleSmall?.extraBold,
                                      decoration: customInputDecoration(context, 'event_type'.tr(ref), icon: Icons.category_outlined),
                                      items: AppConstants.eventTypes.map((t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t.tr(ref), overflow: TextOverflow.ellipsis),
                                      )).toList(),
                                      onChanged: (v) => setState(() => selectedType = v!),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 32),
                                  _sectionHeader(context, 'dates'.tr(ref), icon: Icons.calendar_month_outlined),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: context.appTheme.surfaceSubtle.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: context.borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final d = await showDatePicker(
                                                context: context,
                                                initialDate: selectedDate,
                                                firstDate: DateTime(2020),
                                                lastDate: DateTime(2030),
                                                builder: (context, child) => Theme(
                                                  data: Theme.of(context).copyWith(
                                                    colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primaryTeal),
                                                  ),
                                                  child: child!,
                                                ),
                                              );
                                              if (d != null) setState(() => selectedDate = d);
                                            },
                                            child: InputDecorator(
                                              decoration: customInputDecoration(context, 'date'.tr(ref), icon: Icons.calendar_today_rounded),
                                              child: Text(
                                                selectedDate.toFullDate(locale.languageCode),
                                                style: context.titleSmall?.extraBold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final t = await showTimePicker(
                                                context: context,
                                                initialTime: selectedTime,
                                                builder: (context, child) => Theme(
                                                  data: Theme.of(context).copyWith(
                                                    colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primaryTeal),
                                                  ),
                                                  child: child!,
                                                ),
                                              );
                                              if (t != null) setState(() => selectedTime = t);
                                            },
                                            child: InputDecorator(
                                              decoration: customInputDecoration(context, 'select_time'.tr(ref), icon: Icons.access_time_rounded),
                                              child: Text(
                                                selectedTime.format(context),
                                                style: context.titleSmall?.extraBold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isSaving ? null : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(
                                'cancel'.tr(ref),
                                style: context.titleSmall?.bold.withColor(context.onSurfaceVariant),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: isSaving ? null : const LinearGradient(
                                  colors: [AppColors.primaryTeal, AppColors.primaryTealDark],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                color: isSaving ? context.borderColor : null,
                                boxShadow: isSaving ? null : [
                                  BoxShadow(color: AppColors.primaryTeal.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
                                ],
                              ),
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 48),
                                ),
                                onPressed: isSaving ? null : () async {
                                  if (!formKey.currentState!.validate()) return;

                                  setState(() => isSaving = true);

                                  final finalDate = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                    selectedTime.hour,
                                    selectedTime.minute,
                                  );

                                  final model = CalendarEventModel(
                                    id: eventToEdit != null ? int.parse(eventToEdit.id.split('_')[1]) : 0,
                                    title: titleCtrl.text.trim(),
                                    description: descCtrl.text.trim(),
                                    date: finalDate,
                                    type: selectedType,
                                    isCompleted: eventToEdit?.isCompleted ?? false,
                                  );

                                  try {
                                    if (isEditing) {
                                      await ref.read(calendarRepositoryProvider).updateEvent(model);
                                      DataRefreshCoordinator.refresh(ref);
                                    } else {
                                      final eventId = await ref
                                          .read(calendarRepositoryProvider)
                                          .addEvent(model);

                                      EventReminderScheduler.instance.schedule(
                                        CalendarEventModel(
                                          id: eventId,
                                          title: model.title,
                                          description: model.description,
                                          date: model.date,
                                          type: model.type,
                                          isCompleted: model.isCompleted,
                                        ),
                                      );
                                    }

                                    if (isEditing) {
                                      EventReminderScheduler.instance.schedule(model);
                                    }

                                    ref.invalidate(calendarEventsProvider);
                                    ref.invalidate(dashboardProvider);
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (e) {
                                    setState(() => isSaving = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${'error'.tr(ref)}: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: isSaving
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.white))
                                    : Text(
                                        isEditing ? 'save'.tr(ref) : 'create'.tr(ref),
                                        style: context.titleMedium?.extraBold.white,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}


Widget _sectionHeader(BuildContext context, String title, {IconData? icon}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
    decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.primaryTeal, width: 4))),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.primaryTeal, size: 18),
          const SizedBox(width: 10),
        ],
        Text(
          title,
          style: context.titleMedium?.bold.primary.withHeight(1.0),
        )
      ],
    ),
  );
}

class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child, this.delay = 0});
  final Widget child;
  final int delay;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _opacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _offset = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: SlideTransition(position: _offset, child: widget.child));
  }
}

class _AddEventButton extends ConsumerWidget {
  const _AddEventButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: () => showEventDialog(context, ref),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text('add_event'.tr(ref)),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
    );
  }
}

class _CalendarTopBar extends ConsumerWidget {
  const _CalendarTopBar({
    required this.focusedDay,
    required this.onNavigate,
    required this.onToday,
  });

  final DateTime focusedDay;
  final Function(DateTime) onNavigate;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final year = focusedDay.format('yyyy', locale.languageCode);
    final month = focusedDay.format('MMMM', locale.languageCode);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.appTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGoToTodayButton(context, ref, height: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                year,
                style: context.labelSmall?.extraBold.primary.withLetterSpacing(1).withHeight(1),
              ),
              Text(
                month,
                style: context.titleSmall?.bold.withHeight(1.1),
              ),
            ],
          ),
          const SizedBox(width: 20),
          _buildHeaderAction(
            context,
            icon: Icons.chevron_left_rounded,
            onTap: () => onNavigate(DateTime(focusedDay.year, focusedDay.month - 1)),
          ),
          const SizedBox(width: 8),
          _buildHeaderAction(
            context,
            icon: Icons.chevron_right_rounded,
            onTap: () => onNavigate(DateTime(focusedDay.year, focusedDay.month + 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildGoToTodayButton(BuildContext context, WidgetRef ref, {double height = 48}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.primaryColor.withValues(alpha: 0.2), width: 1.5),
      ),
      child: TextButton.icon(
        onPressed: onToday,
        icon: Icon(Icons.calendar_today_rounded, color: context.primaryColor, size: 16),
        label: Text(
          'today'.tr(ref),
          style: context.labelSmall?.extraBold.primary,
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildHeaderAction(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.primaryColor.withValues(alpha: 0.2), width: 1),
          ),
          child: Icon(icon, color: context.primaryColor, size: 18),
        ),
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final _controller = TextEditingController();
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _isFocused || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 48,
        decoration: BoxDecoration(
          color: _isFocused 
              ? AppColors.primaryTeal.withValues(alpha: 0.1) 
              : _isHovered ? AppColors.primaryTeal.withValues(alpha: 0.06) : context.onSurfaceColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.primaryTeal.withValues(alpha: 0.2) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search_rounded, 
              size: 20, 
              color: active ? AppColors.primaryTeal : context.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Focus(
                onFocusChange: (focused) => setState(() => _isFocused = focused),
                child: TextField(
                  controller: _controller,
                  onChanged: widget.onChanged,
                  style: context.labelMedium?.bold,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'search'.tr(ref),
                    hintStyle: context.labelMedium?.withColor(context.appTheme.textMuted),
                    isCollapsed: true,
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}
