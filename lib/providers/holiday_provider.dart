import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:world_holidays/world_holidays.dart';

import '../core/startup_profiler.dart';
import '../models/holiday.dart';
import 'repository_provider.dart';

class KoreanHolidayCalendar {
  KoreanHolidayCalendar(List<AppHoliday> holidays)
    : _dateKeys = holidays.map((holiday) => holiday.dateKey).toSet(),
      _usePackageFallback = holidays.isEmpty;

  KoreanHolidayCalendar.fallback()
    : _dateKeys = const <String>{},
      _usePackageFallback = true;

  final Set<String> _dateKeys;
  final bool _usePackageFallback;
  final WorldHolidays _fallback = WorldHolidays();

  bool isHoliday(DateTime date) {
    if (_usePackageFallback) return _fallback.isHoliday('KR', date);
    return _dateKeys.contains(_dateKey(date));
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

final koreanHolidayProvider = FutureProvider<KoreanHolidayCalendar>((
  ref,
) async {
  StartupProfiler.mark('local_holiday_query_start');
  final holidays = await ref.read(todoRepositoryProvider).fetchHolidays();
  StartupProfiler.mark('local_holiday_query_end', {'count': holidays.length});
  return KoreanHolidayCalendar(holidays);
});
