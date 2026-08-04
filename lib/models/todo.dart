import 'package:freezed_annotation/freezed_annotation.dart';

part 'todo.freezed.dart';
part 'todo.g.dart';

DateTime parseScheduleDateTime(String value) {
  final wallClock = value.length >= 19 ? value.substring(0, 19) : value;
  return DateTime.parse(wallClock);
}

class ScheduleDateTimeConverter implements JsonConverter<DateTime?, String?> {
  const ScheduleDateTimeConverter();

  @override
  DateTime? fromJson(String? value) {
    if (value case final String text) return parseScheduleDateTime(text);
    return null;
  }

  @override
  String? toJson(DateTime? value) => value?.toIso8601String();
}

class ScheduleDateConverter implements JsonConverter<DateTime?, String?> {
  const ScheduleDateConverter();

  @override
  DateTime? fromJson(String? value) {
    if (value case final String text) return DateTime.parse(text);
    return null;
  }

  @override
  String? toJson(DateTime? value) => value?.toIso8601String().substring(0, 10);
}

Object? readScheduleDate(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value != null) return value;
  final eta = json['eta'] as String?;
  return eta?.substring(0, 10);
}

@Freezed(toJson: false)
abstract class Todo with _$Todo {
  const Todo._();

  const factory Todo({
    required int id,
    @ScheduleDateTimeConverter() required DateTime? eta,
    @JsonKey(name: 'scheduled_date', readValue: readScheduleDate)
    @ScheduleDateConverter()
    DateTime? scheduledDate,
    @Default('') String description,
    required ScheduleUser user,
    required ScheduleAlarm alarm,
    required ScheduleLocation? location,
    @JsonKey(name: 'is_completed') @Default(false) bool isCompleted,
  }) = _Todo;

  factory Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);

  DateTime get scheduledAt => eta ?? scheduledDate ?? DateTime(1970);
  bool get hasTime => eta != null;
  String get title => description.isEmpty ? '일정 #$id' : description;
}

@Freezed(toJson: false)
abstract class ScheduleUser with _$ScheduleUser {
  const factory ScheduleUser({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'user_name') required String userName,
    @JsonKey(name: 'phone_number') required String phoneNumber,
  }) = _ScheduleUser;

  factory ScheduleUser.fromJson(Map<String, dynamic> json) =>
      _$ScheduleUserFromJson(json);
}

@Freezed(toJson: false)
abstract class ScheduleAlarm with _$ScheduleAlarm {
  const factory ScheduleAlarm({
    @JsonKey(name: 'alarm_id') required String alarmId,
    @JsonKey(name: 'alarm_music') required String? alarmMusic,
    @JsonKey(name: 'alarm_text') required String? alarmText,
    @JsonKey(name: 'minutes_before') required int minutesBefore,
  }) = _ScheduleAlarm;

  factory ScheduleAlarm.fromJson(Map<String, dynamic> json) =>
      _$ScheduleAlarmFromJson(json);
}

@Freezed(toJson: false)
abstract class ScheduleLocation with _$ScheduleLocation {
  const factory ScheduleLocation({
    @JsonKey(name: 'location_id') required int locationId,
    required String name,
    required double latitude,
    required double longitude,
    @JsonKey(name: 'source_id') required int sourceId,
  }) = _ScheduleLocation;

  factory ScheduleLocation.fromJson(Map<String, dynamic> json) =>
      _$ScheduleLocationFromJson(json);
}
