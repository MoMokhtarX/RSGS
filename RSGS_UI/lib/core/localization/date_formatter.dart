import 'package:intl/intl.dart';

extension DateFormatter on DateTime {
  String format(String pattern, [String? locale]) {
    return DateFormat(pattern, locale).format(this);
  }

  String toMonthYear([String? locale]) => format('MMMM yyyy', locale);

  String toFullDate([String? locale]) => format('dd MMMM, yyyy', locale);

  String toDayName([String? locale]) => format('EEEE', locale);

  String toTime([String? locale]) => format('hh:mm a', locale);
}
