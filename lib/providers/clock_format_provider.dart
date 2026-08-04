import 'package:flutter_riverpod/flutter_riverpod.dart';

final clockFormatProvider = NotifierProvider<ClockFormatNotifier, bool>(
  ClockFormatNotifier.new,
);

class ClockFormatNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setUse24HourClock(bool value) => state = value;
}
