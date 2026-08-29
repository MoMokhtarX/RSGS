import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/app_models.dart';
import '../../customers/data/customers_repository.dart';
import '../../projects/data/projects_repository.dart';

class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    required this.type,
    this.isCompleted = false,
    this.referenceId,
    this.referenceType,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final String type;
  final bool isCompleted;
  final int? referenceId;
  final String? referenceType;
}

class CalendarRepository {
  CalendarRepository(this._api, this._ref);

  final ApiClient _api;
  final Ref _ref;

  Future<List<CalendarEvent>> getAllEvents() async {
    final events = <CalendarEvent>[];

    try {
      final response = await _api.get('/api/Calendar');

      for (final map in _extractList(response)) {
        final event = _calendarEventFromApi(map);

        events.add(
          CalendarEvent(
            id: 'custom_${event.id}',
            title: event.title,
            description: event.description,
            date: event.date,
            type: event.type,
            isCompleted: event.isCompleted,
            referenceId: event.referenceId,
            referenceType: event.referenceType,
          ),
        );
      }
    } catch (_) {
    }

    try {
      final projects = await _ref.read(projectsStreamProvider.future);

      for (final project in projects) {
        final date = project.installationDate;

        if (date == null) {
          continue;
        }

        events.add(
          CalendarEvent(
            id: 'proj_${project.id}',
            title: 'Installation: ${project.name}',
            description: 'Project Number: ${project.projectNumber}',
            date: date,
            type: 'installation',
            referenceId: project.id,
            referenceType: 'project',
          ),
        );
      }
    } catch (_) {
    }

    try {
      final customers = await _ref.read(customersStreamProvider.future);

      for (final customer in customers) {
        _addFollowUp(
          events,
          customer.id,
          customer.name,
          customer.firstActionDate,
          customer.firstCallNotes,
          1,
        );

        _addFollowUp(
          events,
          customer.id,
          customer.name,
          customer.secondActionDate,
          customer.secondCallNotes,
          2,
        );

        _addFollowUp(
          events,
          customer.id,
          customer.name,
          customer.thirdActionDate,
          customer.thirdCallNotes,
          3,
        );

        _addFollowUp(
          events,
          customer.id,
          customer.name,
          customer.fourthActionDate,
          customer.fourthCallNotes,
          4,
        );
      }
    } catch (_) {
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  Future<int> addEvent(CalendarEventModel event) async {
    final response = await _api.post(
      '/api/Calendar',
      data: _toCreateApi(event),
    );

    final map = _extractObject(response);
    final id = _toInt(map?['id']);

    if (id == null) {
      throw const FormatException(
        'Calendar event was created, but the API did not return its id.',
      );
    }

    return id;
  }

  Future<void> updateEvent(CalendarEventModel event) async {
    await _api.put(
      '/api/Calendar/${event.id}',
      data: _toUpdateApi(event),
    );
  }

  Future<void> deleteEvent(int id) async {
    await _api.delete('/api/Calendar/$id');
  }

  Future<void> markCompleted(int id) async {
    await _api.patch('/api/Calendar/$id/complete');
  }

  void _addFollowUp(
    List<CalendarEvent> events,
    int customerId,
    String customerName,
    DateTime? date,
    String? notes,
    int callNumber,
  ) {
    if (date == null) {
      return;
    }

    events.add(
      CalendarEvent(
        id: 'cust_${callNumber}_$customerId',
        title: '$callNumber${_ordinalSuffix(callNumber)} Call: $customerName',
        description: notes,
        date: date,
        type: 'follow_up',
        referenceId: customerId,
        referenceType: 'customer',
      ),
    );
  }

  String _ordinalSuffix(int number) {
    if (number == 1) return 'st';
    if (number == 2) return 'nd';
    if (number == 3) return 'rd';
    return 'th';
  }
}

CalendarEventModel _calendarEventFromApi(
  Map<String, dynamic> map,
) {
  return CalendarEventModel(
    id: _toInt(map['id']) ?? 0,
    title: map['title']?.toString() ?? '',
    description: map['description']?.toString(),
    date: _parseDate(
      map['eventDate'] ?? map['event_date'] ?? map['date'],
    ),
    type: _calendarTypeFromApi(map['type']),
    isCompleted: map['isCompleted'] == true ||
        map['is_completed'] == true ||
        map['isCompleted'] == 1 ||
        map['is_completed'] == 1,
    referenceId: _toInt(
      map['referenceId'] ?? map['reference_id'],
    ),
    referenceType:
        map['referenceType']?.toString() ??
            map['reference_type']?.toString(),
  );
}

Map<String, Object?> _toCreateApi(CalendarEventModel event) {
  return {
    'title': event.title,
    'description': event.description,
    'eventDate': event.date.toUtc().toIso8601String(),
    'type': _calendarTypeToApi(event.type),
    'referenceId': event.referenceId,
    'referenceType': event.referenceType,
  };
}

Map<String, Object?> _toUpdateApi(CalendarEventModel event) {
  return {
    'title': event.title,
    'description': event.description,
    'eventDate': event.date.toUtc().toIso8601String(),
    'type': _calendarTypeToApi(event.type),
    'referenceId': event.referenceId,
    'referenceType': event.referenceType,
    'isCompleted': event.isCompleted,
  };
}

int _calendarTypeToApi(String type) {
  switch (type.trim().toLowerCase()) {
    case 'task':
      return 1;
    case 'follow_up':
    case 'followup':
      return 2;
    case 'meeting':
      return 3;
    case 'installation':
      return 4;
    case 'maintenance':
      return 5;
    case 'reminder':
      return 6;
    case 'other':
      return 99;
    default:
      return 1;
  }
}

String _calendarTypeFromApi(dynamic value) {
  if (value is num) {
    return _calendarTypeFromNumber(value.toInt());
  }

  final normalized = value?.toString().trim().toLowerCase();

  switch (normalized) {
    case 'task':
      return 'task';
    case 'followup':
    case 'follow_up':
      return 'follow_up';
    case 'meeting':
      return 'meeting';
    case 'installation':
      return 'installation';
    case 'maintenance':
      return 'maintenance';
    case 'reminder':
      return 'reminder';
    case 'other':
      return 'other';
    default:
      return 'task';
  }
}

String _calendarTypeFromNumber(int value) {
  switch (value) {
    case 1:
      return 'task';
    case 2:
      return 'follow_up';
    case 3:
      return 'meeting';
    case 4:
      return 'installation';
    case 5:
      return 'maintenance';
    case 6:
      return 'reminder';
    case 99:
      return 'other';
    default:
      return 'task';
  }
}

DateTime _parseDate(dynamic value) {
  final raw = value?.toString();

  if (raw == null || raw.isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  return DateTime.parse(raw).toLocal();
}

List<Map<String, dynamic>> _extractList(dynamic response) {
  dynamic current = response;

  for (var depth = 0; depth < 6; depth++) {
    if (current is List) {
      return current
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (current is! Map) {
      break;
    }

    final map = Map<String, dynamic>.from(current);

    if (map['items'] is List) {
      return (map['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (map.containsKey('data')) {
      current = map['data'];
      continue;
    }

    if (map.containsKey('results')) {
      current = map['results'];
      continue;
    }

    break;
  }

  return const <Map<String, dynamic>>[];
}

Map<String, dynamic>? _extractObject(dynamic response) {
  dynamic current = response;

  for (var depth = 0; depth < 6; depth++) {
    if (current is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(current);

    if (map.containsKey('id')) {
      return map;
    }

    if (map.containsKey('data')) {
      current = map['data'];
      continue;
    }

    if (map.containsKey('result')) {
      current = map['result'];
      continue;
    }

    return null;
  }

  return null;
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

final calendarRepositoryProvider =
    Provider<CalendarRepository>((ref) {
  return CalendarRepository(
    ref.watch(apiClientProvider),
    ref,
  );
});

final calendarEventsProvider =
    FutureProvider<List<CalendarEvent>>((ref) {
  ref.watch(dataRefreshVersionProvider);
  return ref
      .watch(calendarRepositoryProvider)
      .getAllEvents();
});
