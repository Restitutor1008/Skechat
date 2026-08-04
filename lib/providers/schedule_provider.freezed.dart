// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScheduleData {

 DateTime get date; List<Todo> get todos; String? get actionError;
/// Create a copy of ScheduleData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleDataCopyWith<ScheduleData> get copyWith => _$ScheduleDataCopyWithImpl<ScheduleData>(this as ScheduleData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleData&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other.todos, todos)&&(identical(other.actionError, actionError) || other.actionError == actionError));
}


@override
int get hashCode => Object.hash(runtimeType,date,const DeepCollectionEquality().hash(todos),actionError);

@override
String toString() {
  return 'ScheduleData(date: $date, todos: $todos, actionError: $actionError)';
}


}

/// @nodoc
abstract mixin class $ScheduleDataCopyWith<$Res>  {
  factory $ScheduleDataCopyWith(ScheduleData value, $Res Function(ScheduleData) _then) = _$ScheduleDataCopyWithImpl;
@useResult
$Res call({
 DateTime date, List<Todo> todos, String? actionError
});




}
/// @nodoc
class _$ScheduleDataCopyWithImpl<$Res>
    implements $ScheduleDataCopyWith<$Res> {
  _$ScheduleDataCopyWithImpl(this._self, this._then);

  final ScheduleData _self;
  final $Res Function(ScheduleData) _then;

/// Create a copy of ScheduleData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? todos = null,Object? actionError = freezed,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,todos: null == todos ? _self.todos : todos // ignore: cast_nullable_to_non_nullable
as List<Todo>,actionError: freezed == actionError ? _self.actionError : actionError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ScheduleData].
extension ScheduleDataPatterns on ScheduleData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScheduleData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScheduleData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScheduleData value)  $default,){
final _that = this;
switch (_that) {
case _ScheduleData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScheduleData value)?  $default,){
final _that = this;
switch (_that) {
case _ScheduleData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime date,  List<Todo> todos,  String? actionError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduleData() when $default != null:
return $default(_that.date,_that.todos,_that.actionError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime date,  List<Todo> todos,  String? actionError)  $default,) {final _that = this;
switch (_that) {
case _ScheduleData():
return $default(_that.date,_that.todos,_that.actionError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime date,  List<Todo> todos,  String? actionError)?  $default,) {final _that = this;
switch (_that) {
case _ScheduleData() when $default != null:
return $default(_that.date,_that.todos,_that.actionError);case _:
  return null;

}
}

}

/// @nodoc


class _ScheduleData implements ScheduleData {
  const _ScheduleData({required this.date, required final  List<Todo> todos, this.actionError}): _todos = todos;
  

@override final  DateTime date;
 final  List<Todo> _todos;
@override List<Todo> get todos {
  if (_todos is EqualUnmodifiableListView) return _todos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_todos);
}

@override final  String? actionError;

/// Create a copy of ScheduleData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduleDataCopyWith<_ScheduleData> get copyWith => __$ScheduleDataCopyWithImpl<_ScheduleData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduleData&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other._todos, _todos)&&(identical(other.actionError, actionError) || other.actionError == actionError));
}


@override
int get hashCode => Object.hash(runtimeType,date,const DeepCollectionEquality().hash(_todos),actionError);

@override
String toString() {
  return 'ScheduleData(date: $date, todos: $todos, actionError: $actionError)';
}


}

/// @nodoc
abstract mixin class _$ScheduleDataCopyWith<$Res> implements $ScheduleDataCopyWith<$Res> {
  factory _$ScheduleDataCopyWith(_ScheduleData value, $Res Function(_ScheduleData) _then) = __$ScheduleDataCopyWithImpl;
@override @useResult
$Res call({
 DateTime date, List<Todo> todos, String? actionError
});




}
/// @nodoc
class __$ScheduleDataCopyWithImpl<$Res>
    implements _$ScheduleDataCopyWith<$Res> {
  __$ScheduleDataCopyWithImpl(this._self, this._then);

  final _ScheduleData _self;
  final $Res Function(_ScheduleData) _then;

/// Create a copy of ScheduleData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? todos = null,Object? actionError = freezed,}) {
  return _then(_ScheduleData(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,todos: null == todos ? _self._todos : todos // ignore: cast_nullable_to_non_nullable
as List<Todo>,actionError: freezed == actionError ? _self.actionError : actionError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
