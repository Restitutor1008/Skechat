import 'package:freezed_annotation/freezed_annotation.dart';

import 'todo.dart';

part 'chat_result.freezed.dart';
part 'chat_result.g.dart';

enum PreviewAction { create, update, delete, mixed }

enum PreviewEntityType { schedule, routine }

enum RoutineFrequency { daily, weekly, monthly, yearly }

class RoutinePreviewRule {
  const RoutinePreviewRule({
    required this.frequency,
    this.repeatInterval = 1,
    this.weekdays = const <String>[],
    this.dayOfMonth,
    required this.startDate,
    this.endDate,
  });

  final RoutineFrequency frequency;
  final int repeatInterval;
  final List<String> weekdays;
  final int? dayOfMonth;
  final DateTime startDate;
  final DateTime? endDate;

  RoutinePreviewRule copyWith({
    RoutineFrequency? frequency,
    int? repeatInterval,
    List<String>? weekdays,
    int? dayOfMonth,
    DateTime? startDate,
  }) => RoutinePreviewRule(
    frequency: frequency ?? this.frequency,
    repeatInterval: repeatInterval ?? this.repeatInterval,
    weekdays: weekdays ?? this.weekdays,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    startDate: startDate ?? this.startDate,
    endDate: endDate,
  );

  Map<String, dynamic> toJson(Todo todo) => {
    'name': todo.description.isEmpty ? ' ' : todo.description,
    'description': todo.description,
    'frequency': frequency.name.toUpperCase(),
    'repeat_interval': repeatInterval,
    'weekdays': weekdays.isEmpty ? null : weekdays,
    'day_of_month': dayOfMonth,
    'start_date': startDate.toIso8601String().substring(0, 10),
    'end_date': endDate?.toIso8601String().substring(0, 10),
    'start_time': todo.eta == null
        ? null
        : '${todo.eta!.hour.toString().padLeft(2, '0')}:'
              '${todo.eta!.minute.toString().padLeft(2, '0')}:00',
    'timezone': 'Asia/Seoul',
    'is_active': true,
  };

  static RoutinePreviewRule fromJson(Map<String, dynamic> json) =>
      RoutinePreviewRule(
        frequency: RoutineFrequency.values.byName(
          (json['frequency'] as String).toLowerCase(),
        ),
        repeatInterval: (json['repeat_interval'] as num?)?.toInt() ?? 1,
        weekdays: ((json['weekdays'] as List?) ?? const []).cast<String>(),
        dayOfMonth: (json['day_of_month'] as num?)?.toInt(),
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: json['end_date'] == null
            ? null
            : DateTime.parse(json['end_date'] as String),
      );
}

class SchedulePreviewItem {
  const SchedulePreviewItem({
    required this.itemId,
    required this.action,
    this.entityType = PreviewEntityType.schedule,
    this.scheduleId,
    required this.before,
    required this.after,
    required this.selected,
    this.confidence = 1,
    this.warning,
    this.confirmationQuestion,
    this.requiresConfirmation = false,
    this.confirmed = false,
    this.conflicted = false,
    this.conflictMessage,
    this.routine,
  });

  final String itemId;
  final PreviewAction action;
  final PreviewEntityType entityType;
  final int? scheduleId;
  final Todo? before;
  final Todo? after;
  final bool selected;
  final double confidence;
  final String? warning;
  final String? confirmationQuestion;
  final bool requiresConfirmation;
  final bool confirmed;
  final bool conflicted;
  final String? conflictMessage;
  final RoutinePreviewRule? routine;

  SchedulePreviewItem copyWith({
    Todo? after,
    PreviewEntityType? entityType,
    bool? selected,
    bool? confirmed,
    bool? conflicted,
    String? conflictMessage,
    RoutinePreviewRule? routine,
  }) => SchedulePreviewItem(
    itemId: itemId,
    action: action,
    entityType: entityType ?? this.entityType,
    scheduleId: scheduleId,
    before: before,
    after: after ?? this.after,
    selected: selected ?? this.selected,
    confidence: confidence,
    warning: warning,
    confirmationQuestion: confirmationQuestion,
    requiresConfirmation: requiresConfirmation,
    confirmed: confirmed ?? this.confirmed,
    conflicted: conflicted ?? this.conflicted,
    conflictMessage: conflictMessage ?? this.conflictMessage,
    routine: routine ?? this.routine,
  );
}

@Freezed(toJson: false)
abstract class ChatResult with _$ChatResult {
  const factory ChatResult({
    required String message,
    ScheduleChangePreview? preview,
    @JsonKey(name: 'error_code') String? errorCode,
  }) = _ChatResult;

  factory ChatResult.fromJson(Map<String, dynamic> json) =>
      _$ChatResultFromJson(json);
}

@freezed
abstract class ScheduleChangePreview with _$ScheduleChangePreview {
  const factory ScheduleChangePreview({
    required String operationId,
    required PreviewAction action,
    @Default(1) int pipelineRevision,
    Todo? before,
    Todo? after,
    @Default(<SchedulePreviewItem>[]) List<SchedulePreviewItem> items,
  }) = _ScheduleChangePreview;

  factory ScheduleChangePreview.fromJson(Map<String, dynamic> json) {
    final action = PreviewAction.values.byName(json['action'] as String);
    final beforeValues = Map<String, dynamic>.from(
      (json['before_values'] as Map?) ?? const {},
    );
    final proposedValues = Map<String, dynamic>.from(
      (json['proposed_values'] as Map?) ?? const {},
    );
    final before = beforeValues.isEmpty ? null : Todo.fromJson(beforeValues);
    final operationId = json['operation_id'] as String;
    final items = ((json['items'] as List?) ?? const []).map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      final itemAction = PreviewAction.values.byName(
        (item['action'] as String?) ?? action.name,
      );
      final rawBefore = Map<String, dynamic>.from(
        (item['before_values'] as Map?) ?? const {},
      );
      final itemBefore = rawBefore.isEmpty ? null : Todo.fromJson(rawBefore);
      final itemProposed = Map<String, dynamic>.from(
        (item['proposed_values'] as Map?) ?? const {},
      );
      final itemId =
          item['item_id']?.toString() ?? item['schedule_id'].toString();
      return SchedulePreviewItem(
        itemId: itemId,
        action: itemAction,
        entityType: PreviewEntityType.values.byName(
          (item['entity_type'] as String?) ?? 'schedule',
        ),
        scheduleId: (item['schedule_id'] as num?)?.toInt(),
        before: itemBefore,
        after: switch (itemAction) {
          PreviewAction.create => _createTodo(
            '$operationId:$itemId',
            itemProposed,
          ),
          PreviewAction.update => _updateTodo(itemBefore!, itemProposed),
          PreviewAction.delete || PreviewAction.mixed => null,
        },
        selected: item['selected'] as bool? ?? false,
        confidence: (item['confidence'] as num?)?.toDouble() ?? 1,
        warning: item['warning'] as String?,
        confirmationQuestion: item['confirmation_question'] as String?,
        requiresConfirmation: item['requires_confirmation'] as bool? ?? false,
        confirmed: item['confirmed'] as bool? ?? false,
        conflicted: item['conflicted'] as bool? ?? false,
        conflictMessage: item['conflict_message'] as String?,
        routine: item['routine_values'] == null
            ? null
            : RoutinePreviewRule.fromJson(
                Map<String, dynamic>.from(item['routine_values'] as Map),
              ),
      );
    }).toList();

    return ScheduleChangePreview(
      operationId: operationId,
      action: action,
      pipelineRevision: (json['pipeline_revision'] as num?)?.toInt() ?? 1,
      before: before,
      items: items,
      after: switch (action) {
        PreviewAction.create => _createTodo(operationId, proposedValues),
        PreviewAction.update => _updateTodo(before!, proposedValues),
        PreviewAction.delete => null,
        PreviewAction.mixed => null,
      },
    );
  }

  static Todo _createTodo(String operationId, Map<String, dynamic> proposed) {
    final locationId = proposed['location_id'] as int?;
    return Todo(
      id: -operationId.hashCode.abs(),
      eta: proposed['eta'] == null
          ? null
          : parseScheduleDateTime(proposed['eta'] as String),
      scheduledDate: proposed['scheduled_date'] == null
          ? null
          : DateTime.parse(proposed['scheduled_date'] as String),
      description: (proposed['description'] as String?) ?? '',
      user: const ScheduleUser(userId: '', userName: '', phoneNumber: ''),
      alarm: ScheduleAlarm(
        alarmId: 'preview',
        alarmMusic: null,
        alarmText: proposed['description'] as String?,
        minutesBefore:
            (proposed['alarm_minutes_before'] as num?)?.toInt() ?? 10,
      ),
      location: locationId == null
          ? null
          : _previewLocation(locationId, proposed['location_name'] as String?),
    );
  }

  static Todo _updateTodo(Todo before, Map<String, dynamic> proposed) {
    final location = proposed.containsKey('location_id')
        ? ((proposed['location_id'] as int?) == null
              ? null
              : _previewLocation(
                  proposed['location_id'] as int,
                  proposed['location_name'] as String?,
                ))
        : before.location;
    final delta = (proposed['time_delta_minutes'] as num?)?.toInt();
    return before.copyWith(
      eta: proposed.containsKey('eta')
          ? (proposed['eta'] == null
                ? null
                : parseScheduleDateTime(proposed['eta'] as String))
          : (delta == null
                ? before.eta
                : before.eta?.add(Duration(minutes: delta))),
      scheduledDate: proposed['scheduled_date'] == null
          ? before.scheduledDate
          : DateTime.parse(proposed['scheduled_date'] as String),
      description: (proposed['description'] as String?) ?? before.description,
      alarm: before.alarm.copyWith(
        alarmId: (proposed['alarm_id'] as String?) ?? before.alarm.alarmId,
        minutesBefore:
            (proposed['alarm_minutes_before'] as num?)?.toInt() ??
            before.alarm.minutesBefore,
      ),
      location: location,
      isCompleted: (proposed['is_completed'] as bool?) ?? before.isCompleted,
    );
  }

  static ScheduleLocation _previewLocation(int id, String? name) =>
      ScheduleLocation(
        locationId: id,
        name: name ?? '장소 #$id',
        latitude: 0,
        longitude: 0,
        sourceId: 0,
      );
}
