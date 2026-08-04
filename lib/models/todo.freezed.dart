// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'todo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Todo {

 int get id;@ScheduleDateTimeConverter() DateTime? get eta;@JsonKey(name: 'scheduled_date', readValue: readScheduleDate)@ScheduleDateConverter() DateTime? get scheduledDate; String get description; ScheduleUser get user; ScheduleAlarm get alarm; ScheduleLocation? get location;@JsonKey(name: 'is_completed') bool get isCompleted;
/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TodoCopyWith<Todo> get copyWith => _$TodoCopyWithImpl<Todo>(this as Todo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Todo&&(identical(other.id, id) || other.id == id)&&(identical(other.eta, eta) || other.eta == eta)&&(identical(other.scheduledDate, scheduledDate) || other.scheduledDate == scheduledDate)&&(identical(other.description, description) || other.description == description)&&(identical(other.user, user) || other.user == user)&&(identical(other.alarm, alarm) || other.alarm == alarm)&&(identical(other.location, location) || other.location == location)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,eta,scheduledDate,description,user,alarm,location,isCompleted);

@override
String toString() {
  return 'Todo(id: $id, eta: $eta, scheduledDate: $scheduledDate, description: $description, user: $user, alarm: $alarm, location: $location, isCompleted: $isCompleted)';
}


}

/// @nodoc
abstract mixin class $TodoCopyWith<$Res>  {
  factory $TodoCopyWith(Todo value, $Res Function(Todo) _then) = _$TodoCopyWithImpl;
@useResult
$Res call({
 int id,@ScheduleDateTimeConverter() DateTime? eta,@JsonKey(name: 'scheduled_date', readValue: readScheduleDate)@ScheduleDateConverter() DateTime? scheduledDate, String description, ScheduleUser user, ScheduleAlarm alarm, ScheduleLocation? location,@JsonKey(name: 'is_completed') bool isCompleted
});


$ScheduleUserCopyWith<$Res> get user;$ScheduleAlarmCopyWith<$Res> get alarm;$ScheduleLocationCopyWith<$Res>? get location;

}
/// @nodoc
class _$TodoCopyWithImpl<$Res>
    implements $TodoCopyWith<$Res> {
  _$TodoCopyWithImpl(this._self, this._then);

  final Todo _self;
  final $Res Function(Todo) _then;

/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? eta = freezed,Object? scheduledDate = freezed,Object? description = null,Object? user = null,Object? alarm = null,Object? location = freezed,Object? isCompleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,eta: freezed == eta ? _self.eta : eta // ignore: cast_nullable_to_non_nullable
as DateTime?,scheduledDate: freezed == scheduledDate ? _self.scheduledDate : scheduledDate // ignore: cast_nullable_to_non_nullable
as DateTime?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as ScheduleUser,alarm: null == alarm ? _self.alarm : alarm // ignore: cast_nullable_to_non_nullable
as ScheduleAlarm,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as ScheduleLocation?,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduleUserCopyWith<$Res> get user {
  
  return $ScheduleUserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduleAlarmCopyWith<$Res> get alarm {
  
  return $ScheduleAlarmCopyWith<$Res>(_self.alarm, (value) {
    return _then(_self.copyWith(alarm: value));
  });
}/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduleLocationCopyWith<$Res>? get location {
    if (_self.location == null) {
    return null;
  }

  return $ScheduleLocationCopyWith<$Res>(_self.location!, (value) {
    return _then(_self.copyWith(location: value));
  });
}
}


/// Adds pattern-matching-related methods to [Todo].
extension TodoPatterns on Todo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Todo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Todo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Todo value)  $default,){
final _that = this;
switch (_that) {
case _Todo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Todo value)?  $default,){
final _that = this;
switch (_that) {
case _Todo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @ScheduleDateTimeConverter()  DateTime? eta, @JsonKey(name: 'scheduled_date', readValue: readScheduleDate)@ScheduleDateConverter()  DateTime? scheduledDate,  String description,  ScheduleUser user,  ScheduleAlarm alarm,  ScheduleLocation? location, @JsonKey(name: 'is_completed')  bool isCompleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Todo() when $default != null:
return $default(_that.id,_that.eta,_that.scheduledDate,_that.description,_that.user,_that.alarm,_that.location,_that.isCompleted);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @ScheduleDateTimeConverter()  DateTime? eta, @JsonKey(name: 'scheduled_date', readValue: readScheduleDate)@ScheduleDateConverter()  DateTime? scheduledDate,  String description,  ScheduleUser user,  ScheduleAlarm alarm,  ScheduleLocation? location, @JsonKey(name: 'is_completed')  bool isCompleted)  $default,) {final _that = this;
switch (_that) {
case _Todo():
return $default(_that.id,_that.eta,_that.scheduledDate,_that.description,_that.user,_that.alarm,_that.location,_that.isCompleted);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @ScheduleDateTimeConverter()  DateTime? eta, @JsonKey(name: 'scheduled_date', readValue: readScheduleDate)@ScheduleDateConverter()  DateTime? scheduledDate,  String description,  ScheduleUser user,  ScheduleAlarm alarm,  ScheduleLocation? location, @JsonKey(name: 'is_completed')  bool isCompleted)?  $default,) {final _that = this;
switch (_that) {
case _Todo() when $default != null:
return $default(_that.id,_that.eta,_that.scheduledDate,_that.description,_that.user,_that.alarm,_that.location,_that.isCompleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _Todo extends Todo {
  const _Todo({required this.id, @ScheduleDateTimeConverter() required this.eta, @JsonKey(name: 'scheduled_date', readValue: readScheduleDate)@ScheduleDateConverter() this.scheduledDate, this.description = '', required this.user, required this.alarm, required this.location, @JsonKey(name: 'is_completed') this.isCompleted = false}): super._();
  factory _Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);

@override final  int id;
@override@ScheduleDateTimeConverter() final  DateTime? eta;
@override@JsonKey(name: 'scheduled_date', readValue: readScheduleDate)@ScheduleDateConverter() final  DateTime? scheduledDate;
@override@JsonKey() final  String description;
@override final  ScheduleUser user;
@override final  ScheduleAlarm alarm;
@override final  ScheduleLocation? location;
@override@JsonKey(name: 'is_completed') final  bool isCompleted;

/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TodoCopyWith<_Todo> get copyWith => __$TodoCopyWithImpl<_Todo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Todo&&(identical(other.id, id) || other.id == id)&&(identical(other.eta, eta) || other.eta == eta)&&(identical(other.scheduledDate, scheduledDate) || other.scheduledDate == scheduledDate)&&(identical(other.description, description) || other.description == description)&&(identical(other.user, user) || other.user == user)&&(identical(other.alarm, alarm) || other.alarm == alarm)&&(identical(other.location, location) || other.location == location)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,eta,scheduledDate,description,user,alarm,location,isCompleted);

@override
String toString() {
  return 'Todo(id: $id, eta: $eta, scheduledDate: $scheduledDate, description: $description, user: $user, alarm: $alarm, location: $location, isCompleted: $isCompleted)';
}


}

/// @nodoc
abstract mixin class _$TodoCopyWith<$Res> implements $TodoCopyWith<$Res> {
  factory _$TodoCopyWith(_Todo value, $Res Function(_Todo) _then) = __$TodoCopyWithImpl;
@override @useResult
$Res call({
 int id,@ScheduleDateTimeConverter() DateTime? eta,@JsonKey(name: 'scheduled_date', readValue: readScheduleDate)@ScheduleDateConverter() DateTime? scheduledDate, String description, ScheduleUser user, ScheduleAlarm alarm, ScheduleLocation? location,@JsonKey(name: 'is_completed') bool isCompleted
});


@override $ScheduleUserCopyWith<$Res> get user;@override $ScheduleAlarmCopyWith<$Res> get alarm;@override $ScheduleLocationCopyWith<$Res>? get location;

}
/// @nodoc
class __$TodoCopyWithImpl<$Res>
    implements _$TodoCopyWith<$Res> {
  __$TodoCopyWithImpl(this._self, this._then);

  final _Todo _self;
  final $Res Function(_Todo) _then;

/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? eta = freezed,Object? scheduledDate = freezed,Object? description = null,Object? user = null,Object? alarm = null,Object? location = freezed,Object? isCompleted = null,}) {
  return _then(_Todo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,eta: freezed == eta ? _self.eta : eta // ignore: cast_nullable_to_non_nullable
as DateTime?,scheduledDate: freezed == scheduledDate ? _self.scheduledDate : scheduledDate // ignore: cast_nullable_to_non_nullable
as DateTime?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as ScheduleUser,alarm: null == alarm ? _self.alarm : alarm // ignore: cast_nullable_to_non_nullable
as ScheduleAlarm,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as ScheduleLocation?,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduleUserCopyWith<$Res> get user {
  
  return $ScheduleUserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduleAlarmCopyWith<$Res> get alarm {
  
  return $ScheduleAlarmCopyWith<$Res>(_self.alarm, (value) {
    return _then(_self.copyWith(alarm: value));
  });
}/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduleLocationCopyWith<$Res>? get location {
    if (_self.location == null) {
    return null;
  }

  return $ScheduleLocationCopyWith<$Res>(_self.location!, (value) {
    return _then(_self.copyWith(location: value));
  });
}
}


/// @nodoc
mixin _$ScheduleUser {

@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'user_name') String get userName;@JsonKey(name: 'phone_number') String get phoneNumber;
/// Create a copy of ScheduleUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleUserCopyWith<ScheduleUser> get copyWith => _$ScheduleUserCopyWithImpl<ScheduleUser>(this as ScheduleUser, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleUser&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,userName,phoneNumber);

@override
String toString() {
  return 'ScheduleUser(userId: $userId, userName: $userName, phoneNumber: $phoneNumber)';
}


}

/// @nodoc
abstract mixin class $ScheduleUserCopyWith<$Res>  {
  factory $ScheduleUserCopyWith(ScheduleUser value, $Res Function(ScheduleUser) _then) = _$ScheduleUserCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'user_name') String userName,@JsonKey(name: 'phone_number') String phoneNumber
});




}
/// @nodoc
class _$ScheduleUserCopyWithImpl<$Res>
    implements $ScheduleUserCopyWith<$Res> {
  _$ScheduleUserCopyWithImpl(this._self, this._then);

  final ScheduleUser _self;
  final $Res Function(ScheduleUser) _then;

/// Create a copy of ScheduleUser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? userName = null,Object? phoneNumber = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ScheduleUser].
extension ScheduleUserPatterns on ScheduleUser {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScheduleUser value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScheduleUser() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScheduleUser value)  $default,){
final _that = this;
switch (_that) {
case _ScheduleUser():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScheduleUser value)?  $default,){
final _that = this;
switch (_that) {
case _ScheduleUser() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'user_name')  String userName, @JsonKey(name: 'phone_number')  String phoneNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduleUser() when $default != null:
return $default(_that.userId,_that.userName,_that.phoneNumber);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'user_name')  String userName, @JsonKey(name: 'phone_number')  String phoneNumber)  $default,) {final _that = this;
switch (_that) {
case _ScheduleUser():
return $default(_that.userId,_that.userName,_that.phoneNumber);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'user_name')  String userName, @JsonKey(name: 'phone_number')  String phoneNumber)?  $default,) {final _that = this;
switch (_that) {
case _ScheduleUser() when $default != null:
return $default(_that.userId,_that.userName,_that.phoneNumber);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _ScheduleUser implements ScheduleUser {
  const _ScheduleUser({@JsonKey(name: 'user_id') required this.userId, @JsonKey(name: 'user_name') required this.userName, @JsonKey(name: 'phone_number') required this.phoneNumber});
  factory _ScheduleUser.fromJson(Map<String, dynamic> json) => _$ScheduleUserFromJson(json);

@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'user_name') final  String userName;
@override@JsonKey(name: 'phone_number') final  String phoneNumber;

/// Create a copy of ScheduleUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduleUserCopyWith<_ScheduleUser> get copyWith => __$ScheduleUserCopyWithImpl<_ScheduleUser>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduleUser&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,userName,phoneNumber);

@override
String toString() {
  return 'ScheduleUser(userId: $userId, userName: $userName, phoneNumber: $phoneNumber)';
}


}

/// @nodoc
abstract mixin class _$ScheduleUserCopyWith<$Res> implements $ScheduleUserCopyWith<$Res> {
  factory _$ScheduleUserCopyWith(_ScheduleUser value, $Res Function(_ScheduleUser) _then) = __$ScheduleUserCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'user_name') String userName,@JsonKey(name: 'phone_number') String phoneNumber
});




}
/// @nodoc
class __$ScheduleUserCopyWithImpl<$Res>
    implements _$ScheduleUserCopyWith<$Res> {
  __$ScheduleUserCopyWithImpl(this._self, this._then);

  final _ScheduleUser _self;
  final $Res Function(_ScheduleUser) _then;

/// Create a copy of ScheduleUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? userName = null,Object? phoneNumber = null,}) {
  return _then(_ScheduleUser(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ScheduleAlarm {

@JsonKey(name: 'alarm_id') String get alarmId;@JsonKey(name: 'alarm_music') String? get alarmMusic;@JsonKey(name: 'alarm_text') String? get alarmText;@JsonKey(name: 'minutes_before') int get minutesBefore;
/// Create a copy of ScheduleAlarm
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleAlarmCopyWith<ScheduleAlarm> get copyWith => _$ScheduleAlarmCopyWithImpl<ScheduleAlarm>(this as ScheduleAlarm, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleAlarm&&(identical(other.alarmId, alarmId) || other.alarmId == alarmId)&&(identical(other.alarmMusic, alarmMusic) || other.alarmMusic == alarmMusic)&&(identical(other.alarmText, alarmText) || other.alarmText == alarmText)&&(identical(other.minutesBefore, minutesBefore) || other.minutesBefore == minutesBefore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,alarmId,alarmMusic,alarmText,minutesBefore);

@override
String toString() {
  return 'ScheduleAlarm(alarmId: $alarmId, alarmMusic: $alarmMusic, alarmText: $alarmText, minutesBefore: $minutesBefore)';
}


}

/// @nodoc
abstract mixin class $ScheduleAlarmCopyWith<$Res>  {
  factory $ScheduleAlarmCopyWith(ScheduleAlarm value, $Res Function(ScheduleAlarm) _then) = _$ScheduleAlarmCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'alarm_id') String alarmId,@JsonKey(name: 'alarm_music') String? alarmMusic,@JsonKey(name: 'alarm_text') String? alarmText,@JsonKey(name: 'minutes_before') int minutesBefore
});




}
/// @nodoc
class _$ScheduleAlarmCopyWithImpl<$Res>
    implements $ScheduleAlarmCopyWith<$Res> {
  _$ScheduleAlarmCopyWithImpl(this._self, this._then);

  final ScheduleAlarm _self;
  final $Res Function(ScheduleAlarm) _then;

/// Create a copy of ScheduleAlarm
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? alarmId = null,Object? alarmMusic = freezed,Object? alarmText = freezed,Object? minutesBefore = null,}) {
  return _then(_self.copyWith(
alarmId: null == alarmId ? _self.alarmId : alarmId // ignore: cast_nullable_to_non_nullable
as String,alarmMusic: freezed == alarmMusic ? _self.alarmMusic : alarmMusic // ignore: cast_nullable_to_non_nullable
as String?,alarmText: freezed == alarmText ? _self.alarmText : alarmText // ignore: cast_nullable_to_non_nullable
as String?,minutesBefore: null == minutesBefore ? _self.minutesBefore : minutesBefore // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ScheduleAlarm].
extension ScheduleAlarmPatterns on ScheduleAlarm {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScheduleAlarm value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScheduleAlarm() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScheduleAlarm value)  $default,){
final _that = this;
switch (_that) {
case _ScheduleAlarm():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScheduleAlarm value)?  $default,){
final _that = this;
switch (_that) {
case _ScheduleAlarm() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'alarm_id')  String alarmId, @JsonKey(name: 'alarm_music')  String? alarmMusic, @JsonKey(name: 'alarm_text')  String? alarmText, @JsonKey(name: 'minutes_before')  int minutesBefore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduleAlarm() when $default != null:
return $default(_that.alarmId,_that.alarmMusic,_that.alarmText,_that.minutesBefore);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'alarm_id')  String alarmId, @JsonKey(name: 'alarm_music')  String? alarmMusic, @JsonKey(name: 'alarm_text')  String? alarmText, @JsonKey(name: 'minutes_before')  int minutesBefore)  $default,) {final _that = this;
switch (_that) {
case _ScheduleAlarm():
return $default(_that.alarmId,_that.alarmMusic,_that.alarmText,_that.minutesBefore);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'alarm_id')  String alarmId, @JsonKey(name: 'alarm_music')  String? alarmMusic, @JsonKey(name: 'alarm_text')  String? alarmText, @JsonKey(name: 'minutes_before')  int minutesBefore)?  $default,) {final _that = this;
switch (_that) {
case _ScheduleAlarm() when $default != null:
return $default(_that.alarmId,_that.alarmMusic,_that.alarmText,_that.minutesBefore);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _ScheduleAlarm implements ScheduleAlarm {
  const _ScheduleAlarm({@JsonKey(name: 'alarm_id') required this.alarmId, @JsonKey(name: 'alarm_music') required this.alarmMusic, @JsonKey(name: 'alarm_text') required this.alarmText, @JsonKey(name: 'minutes_before') required this.minutesBefore});
  factory _ScheduleAlarm.fromJson(Map<String, dynamic> json) => _$ScheduleAlarmFromJson(json);

@override@JsonKey(name: 'alarm_id') final  String alarmId;
@override@JsonKey(name: 'alarm_music') final  String? alarmMusic;
@override@JsonKey(name: 'alarm_text') final  String? alarmText;
@override@JsonKey(name: 'minutes_before') final  int minutesBefore;

/// Create a copy of ScheduleAlarm
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduleAlarmCopyWith<_ScheduleAlarm> get copyWith => __$ScheduleAlarmCopyWithImpl<_ScheduleAlarm>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduleAlarm&&(identical(other.alarmId, alarmId) || other.alarmId == alarmId)&&(identical(other.alarmMusic, alarmMusic) || other.alarmMusic == alarmMusic)&&(identical(other.alarmText, alarmText) || other.alarmText == alarmText)&&(identical(other.minutesBefore, minutesBefore) || other.minutesBefore == minutesBefore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,alarmId,alarmMusic,alarmText,minutesBefore);

@override
String toString() {
  return 'ScheduleAlarm(alarmId: $alarmId, alarmMusic: $alarmMusic, alarmText: $alarmText, minutesBefore: $minutesBefore)';
}


}

/// @nodoc
abstract mixin class _$ScheduleAlarmCopyWith<$Res> implements $ScheduleAlarmCopyWith<$Res> {
  factory _$ScheduleAlarmCopyWith(_ScheduleAlarm value, $Res Function(_ScheduleAlarm) _then) = __$ScheduleAlarmCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'alarm_id') String alarmId,@JsonKey(name: 'alarm_music') String? alarmMusic,@JsonKey(name: 'alarm_text') String? alarmText,@JsonKey(name: 'minutes_before') int minutesBefore
});




}
/// @nodoc
class __$ScheduleAlarmCopyWithImpl<$Res>
    implements _$ScheduleAlarmCopyWith<$Res> {
  __$ScheduleAlarmCopyWithImpl(this._self, this._then);

  final _ScheduleAlarm _self;
  final $Res Function(_ScheduleAlarm) _then;

/// Create a copy of ScheduleAlarm
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? alarmId = null,Object? alarmMusic = freezed,Object? alarmText = freezed,Object? minutesBefore = null,}) {
  return _then(_ScheduleAlarm(
alarmId: null == alarmId ? _self.alarmId : alarmId // ignore: cast_nullable_to_non_nullable
as String,alarmMusic: freezed == alarmMusic ? _self.alarmMusic : alarmMusic // ignore: cast_nullable_to_non_nullable
as String?,alarmText: freezed == alarmText ? _self.alarmText : alarmText // ignore: cast_nullable_to_non_nullable
as String?,minutesBefore: null == minutesBefore ? _self.minutesBefore : minutesBefore // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ScheduleLocation {

@JsonKey(name: 'location_id') int get locationId; String get name; double get latitude; double get longitude;@JsonKey(name: 'source_id') int get sourceId;
/// Create a copy of ScheduleLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleLocationCopyWith<ScheduleLocation> get copyWith => _$ScheduleLocationCopyWithImpl<ScheduleLocation>(this as ScheduleLocation, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleLocation&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.name, name) || other.name == name)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locationId,name,latitude,longitude,sourceId);

@override
String toString() {
  return 'ScheduleLocation(locationId: $locationId, name: $name, latitude: $latitude, longitude: $longitude, sourceId: $sourceId)';
}


}

/// @nodoc
abstract mixin class $ScheduleLocationCopyWith<$Res>  {
  factory $ScheduleLocationCopyWith(ScheduleLocation value, $Res Function(ScheduleLocation) _then) = _$ScheduleLocationCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'location_id') int locationId, String name, double latitude, double longitude,@JsonKey(name: 'source_id') int sourceId
});




}
/// @nodoc
class _$ScheduleLocationCopyWithImpl<$Res>
    implements $ScheduleLocationCopyWith<$Res> {
  _$ScheduleLocationCopyWithImpl(this._self, this._then);

  final ScheduleLocation _self;
  final $Res Function(ScheduleLocation) _then;

/// Create a copy of ScheduleLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? locationId = null,Object? name = null,Object? latitude = null,Object? longitude = null,Object? sourceId = null,}) {
  return _then(_self.copyWith(
locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ScheduleLocation].
extension ScheduleLocationPatterns on ScheduleLocation {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScheduleLocation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScheduleLocation() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScheduleLocation value)  $default,){
final _that = this;
switch (_that) {
case _ScheduleLocation():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScheduleLocation value)?  $default,){
final _that = this;
switch (_that) {
case _ScheduleLocation() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'location_id')  int locationId,  String name,  double latitude,  double longitude, @JsonKey(name: 'source_id')  int sourceId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduleLocation() when $default != null:
return $default(_that.locationId,_that.name,_that.latitude,_that.longitude,_that.sourceId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'location_id')  int locationId,  String name,  double latitude,  double longitude, @JsonKey(name: 'source_id')  int sourceId)  $default,) {final _that = this;
switch (_that) {
case _ScheduleLocation():
return $default(_that.locationId,_that.name,_that.latitude,_that.longitude,_that.sourceId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'location_id')  int locationId,  String name,  double latitude,  double longitude, @JsonKey(name: 'source_id')  int sourceId)?  $default,) {final _that = this;
switch (_that) {
case _ScheduleLocation() when $default != null:
return $default(_that.locationId,_that.name,_that.latitude,_that.longitude,_that.sourceId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _ScheduleLocation implements ScheduleLocation {
  const _ScheduleLocation({@JsonKey(name: 'location_id') required this.locationId, required this.name, required this.latitude, required this.longitude, @JsonKey(name: 'source_id') required this.sourceId});
  factory _ScheduleLocation.fromJson(Map<String, dynamic> json) => _$ScheduleLocationFromJson(json);

@override@JsonKey(name: 'location_id') final  int locationId;
@override final  String name;
@override final  double latitude;
@override final  double longitude;
@override@JsonKey(name: 'source_id') final  int sourceId;

/// Create a copy of ScheduleLocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduleLocationCopyWith<_ScheduleLocation> get copyWith => __$ScheduleLocationCopyWithImpl<_ScheduleLocation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduleLocation&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.name, name) || other.name == name)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locationId,name,latitude,longitude,sourceId);

@override
String toString() {
  return 'ScheduleLocation(locationId: $locationId, name: $name, latitude: $latitude, longitude: $longitude, sourceId: $sourceId)';
}


}

/// @nodoc
abstract mixin class _$ScheduleLocationCopyWith<$Res> implements $ScheduleLocationCopyWith<$Res> {
  factory _$ScheduleLocationCopyWith(_ScheduleLocation value, $Res Function(_ScheduleLocation) _then) = __$ScheduleLocationCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'location_id') int locationId, String name, double latitude, double longitude,@JsonKey(name: 'source_id') int sourceId
});




}
/// @nodoc
class __$ScheduleLocationCopyWithImpl<$Res>
    implements _$ScheduleLocationCopyWith<$Res> {
  __$ScheduleLocationCopyWithImpl(this._self, this._then);

  final _ScheduleLocation _self;
  final $Res Function(_ScheduleLocation) _then;

/// Create a copy of ScheduleLocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? locationId = null,Object? name = null,Object? latitude = null,Object? longitude = null,Object? sourceId = null,}) {
  return _then(_ScheduleLocation(
locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
