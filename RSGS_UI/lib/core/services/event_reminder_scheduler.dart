import 'dart:async';

import '../models/app_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_helper.dart';

class EventReminderScheduler {
  EventReminderScheduler._();

  static final EventReminderScheduler instance = EventReminderScheduler._();

  final Map<int, Timer> _timers = <int, Timer>{};
  ProviderContainer? _container;

  Future<void> initialize(ProviderContainer container) async {
    _container = container;
  }

  Future<void> rescheduleAll(List<CalendarEventModel> events) async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();

    for (final event in events) {
      schedule(event);
    }
  }

  void schedule(CalendarEventModel event) {
    final container = _container;
    if (container == null || event.isCompleted || !event.date.isAfter(DateTime.now())) {
      return;
    }

    _timers.remove(event.id)?.cancel();
    _timers[event.id] = Timer(event.date.difference(DateTime.now()), () async {
      _timers.remove(event.id);
      await container.read(NotificationHelper.provider).showAndSave(
        title: 'Event reminder',
        body: event.description == null || event.description!.isEmpty
            ? event.title
            : '${event.title}\n${event.description}',
        type: 'reminder',
      );
    });
  }

  void cancel(int eventId) {
    _timers.remove(eventId)?.cancel();
  }
}
