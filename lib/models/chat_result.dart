import 'todo.dart';

enum PreviewAction { create, update, delete }

class ChatResult {
  const ChatResult({required this.message, this.preview, this.errorCode});

  final String message;
  final ScheduleChangePreview? preview;
  final String? errorCode;

  factory ChatResult.fromJson(Map<String, dynamic> json) => ChatResult(
    message: json['message'] as String,
    errorCode: json['error_code'] as String?,
    preview: json['preview'] == null
        ? null
        : ScheduleChangePreview.fromJson(
            json['preview'] as Map<String, dynamic>,
          ),
  );
}

class ScheduleChangePreview {
  const ScheduleChangePreview({
    required this.operationId,
    required this.action,
    this.before,
    this.after,
  });

  final String operationId;
  final PreviewAction action;
  final Todo? before;
  final Todo? after;

  ScheduleChangePreview copyWith({Todo? after}) => ScheduleChangePreview(
    operationId: operationId,
    action: action,
    before: before,
    after: after ?? this.after,
  );

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

    return ScheduleChangePreview(
      operationId: operationId,
      action: action,
      before: before,
      after: switch (action) {
        PreviewAction.create => _createTodo(operationId, proposedValues),
        PreviewAction.update => _updateTodo(before!, proposedValues),
        PreviewAction.delete => null,
      },
    );
  }

  static Todo _createTodo(String operationId, Map<String, dynamic> proposed) {
    final locationId = proposed['location_id'] as int?;
    return Todo(
      id: -operationId.hashCode.abs(),
      eta: parseScheduleDateTime(proposed['eta'] as String),
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
    return Todo(
      id: before.id,
      eta: proposed['eta'] == null
          ? before.eta
          : parseScheduleDateTime(proposed['eta'] as String),
      description: (proposed['description'] as String?) ?? before.description,
      user: before.user,
      alarm: ScheduleAlarm(
        alarmId: (proposed['alarm_id'] as String?) ?? before.alarm.alarmId,
        alarmMusic: before.alarm.alarmMusic,
        alarmText: before.alarm.alarmText,
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
