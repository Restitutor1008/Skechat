// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Todo _$TodoFromJson(Map<String, dynamic> json) => _Todo(
  id: (json['id'] as num).toInt(),
  eta: const ScheduleDateTimeConverter().fromJson(json['eta'] as String?),
  scheduledDate: const ScheduleDateConverter().fromJson(
    readScheduleDate(json, 'scheduled_date') as String?,
  ),
  description: json['description'] as String? ?? '',
  user: ScheduleUser.fromJson(json['user'] as Map<String, dynamic>),
  alarm: ScheduleAlarm.fromJson(json['alarm'] as Map<String, dynamic>),
  location: json['location'] == null
      ? null
      : ScheduleLocation.fromJson(json['location'] as Map<String, dynamic>),
  isCompleted: json['is_completed'] as bool? ?? false,
);

_ScheduleUser _$ScheduleUserFromJson(Map<String, dynamic> json) =>
    _ScheduleUser(
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      phoneNumber: json['phone_number'] as String,
    );

_ScheduleAlarm _$ScheduleAlarmFromJson(Map<String, dynamic> json) =>
    _ScheduleAlarm(
      alarmId: json['alarm_id'] as String,
      alarmMusic: json['alarm_music'] as String?,
      alarmText: json['alarm_text'] as String?,
      minutesBefore: (json['minutes_before'] as num).toInt(),
    );

_ScheduleLocation _$ScheduleLocationFromJson(Map<String, dynamic> json) =>
    _ScheduleLocation(
      locationId: (json['location_id'] as num).toInt(),
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      sourceId: (json['source_id'] as num).toInt(),
    );
