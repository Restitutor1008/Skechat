DateTime parseScheduleDateTime(String value) {
  final wallClock = value.length >= 19 ? value.substring(0, 19) : value;
  return DateTime.parse(wallClock);
}

class Todo {
  const Todo({
    required this.id,
    required this.eta,
    required this.description,
    required this.user,
    required this.alarm,
    required this.location,
    this.isCompleted = false,
  });

  final int id;
  final DateTime eta;
  final String description;
  final ScheduleUser user;
  final ScheduleAlarm alarm;
  final ScheduleLocation? location;
  final bool isCompleted;

  DateTime get scheduledAt => eta;
  String get title => description.isEmpty ? '일정 #$id' : description;

  Todo copyWith({
    DateTime? eta,
    String? description,
    ScheduleAlarm? alarm,
    bool? isCompleted,
  }) => Todo(
    id: id,
    eta: eta ?? this.eta,
    description: description ?? this.description,
    user: user,
    alarm: alarm ?? this.alarm,
    location: location,
    isCompleted: isCompleted ?? this.isCompleted,
  );

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as int,
    eta: parseScheduleDateTime(json['eta'] as String),
    description: (json['description'] as String?) ?? '',
    user: ScheduleUser.fromJson(json['user'] as Map<String, dynamic>),
    alarm: ScheduleAlarm.fromJson(json['alarm'] as Map<String, dynamic>),
    location: json['location'] == null
        ? null
        : ScheduleLocation.fromJson(json['location'] as Map<String, dynamic>),
    isCompleted: (json['is_completed'] as bool?) ?? false,
  );
}

class ScheduleUser {
  const ScheduleUser({
    required this.userId,
    required this.userName,
    required this.phoneNumber,
  });

  final String userId;
  final String userName;
  final String phoneNumber;

  factory ScheduleUser.fromJson(Map<String, dynamic> json) => ScheduleUser(
    userId: json['user_id'] as String,
    userName: json['user_name'] as String,
    phoneNumber: json['phone_number'] as String,
  );
}

class ScheduleAlarm {
  const ScheduleAlarm({
    required this.alarmId,
    required this.alarmMusic,
    required this.alarmText,
    required this.minutesBefore,
  });

  final String alarmId;
  final String? alarmMusic;
  final String? alarmText;
  final int minutesBefore;

  ScheduleAlarm copyWith({int? minutesBefore}) => ScheduleAlarm(
    alarmId: alarmId,
    alarmMusic: alarmMusic,
    alarmText: alarmText,
    minutesBefore: minutesBefore ?? this.minutesBefore,
  );

  factory ScheduleAlarm.fromJson(Map<String, dynamic> json) => ScheduleAlarm(
    alarmId: json['alarm_id'] as String,
    alarmMusic: json['alarm_music'] as String?,
    alarmText: json['alarm_text'] as String?,
    minutesBefore: (json['minutes_before'] as num).toInt(),
  );
}

class ScheduleLocation {
  const ScheduleLocation({
    required this.locationId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.sourceId,
  });

  final int locationId;
  final String name;
  final double latitude;
  final double longitude;
  final int sourceId;

  factory ScheduleLocation.fromJson(Map<String, dynamic> json) =>
      ScheduleLocation(
        locationId: (json['location_id'] as num).toInt(),
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        sourceId: json['source_id'] as int,
      );
}
