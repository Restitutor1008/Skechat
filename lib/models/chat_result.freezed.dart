// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatResult {

 String get message; ScheduleChangePreview? get preview;@JsonKey(name: 'error_code') String? get errorCode;
/// Create a copy of ChatResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatResultCopyWith<ChatResult> get copyWith => _$ChatResultCopyWithImpl<ChatResult>(this as ChatResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatResult&&(identical(other.message, message) || other.message == message)&&(identical(other.preview, preview) || other.preview == preview)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,preview,errorCode);

@override
String toString() {
  return 'ChatResult(message: $message, preview: $preview, errorCode: $errorCode)';
}


}

/// @nodoc
abstract mixin class $ChatResultCopyWith<$Res>  {
  factory $ChatResultCopyWith(ChatResult value, $Res Function(ChatResult) _then) = _$ChatResultCopyWithImpl;
@useResult
$Res call({
 String message, ScheduleChangePreview? preview,@JsonKey(name: 'error_code') String? errorCode
});


$ScheduleChangePreviewCopyWith<$Res>? get preview;

}
/// @nodoc
class _$ChatResultCopyWithImpl<$Res>
    implements $ChatResultCopyWith<$Res> {
  _$ChatResultCopyWithImpl(this._self, this._then);

  final ChatResult _self;
  final $Res Function(ChatResult) _then;

/// Create a copy of ChatResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? preview = freezed,Object? errorCode = freezed,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,preview: freezed == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as ScheduleChangePreview?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ChatResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduleChangePreviewCopyWith<$Res>? get preview {
    if (_self.preview == null) {
    return null;
  }

  return $ScheduleChangePreviewCopyWith<$Res>(_self.preview!, (value) {
    return _then(_self.copyWith(preview: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChatResult].
extension ChatResultPatterns on ChatResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatResult value)  $default,){
final _that = this;
switch (_that) {
case _ChatResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatResult value)?  $default,){
final _that = this;
switch (_that) {
case _ChatResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message,  ScheduleChangePreview? preview, @JsonKey(name: 'error_code')  String? errorCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatResult() when $default != null:
return $default(_that.message,_that.preview,_that.errorCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message,  ScheduleChangePreview? preview, @JsonKey(name: 'error_code')  String? errorCode)  $default,) {final _that = this;
switch (_that) {
case _ChatResult():
return $default(_that.message,_that.preview,_that.errorCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message,  ScheduleChangePreview? preview, @JsonKey(name: 'error_code')  String? errorCode)?  $default,) {final _that = this;
switch (_that) {
case _ChatResult() when $default != null:
return $default(_that.message,_that.preview,_that.errorCode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _ChatResult implements ChatResult {
  const _ChatResult({required this.message, this.preview, @JsonKey(name: 'error_code') this.errorCode});
  factory _ChatResult.fromJson(Map<String, dynamic> json) => _$ChatResultFromJson(json);

@override final  String message;
@override final  ScheduleChangePreview? preview;
@override@JsonKey(name: 'error_code') final  String? errorCode;

/// Create a copy of ChatResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatResultCopyWith<_ChatResult> get copyWith => __$ChatResultCopyWithImpl<_ChatResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatResult&&(identical(other.message, message) || other.message == message)&&(identical(other.preview, preview) || other.preview == preview)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,preview,errorCode);

@override
String toString() {
  return 'ChatResult(message: $message, preview: $preview, errorCode: $errorCode)';
}


}

/// @nodoc
abstract mixin class _$ChatResultCopyWith<$Res> implements $ChatResultCopyWith<$Res> {
  factory _$ChatResultCopyWith(_ChatResult value, $Res Function(_ChatResult) _then) = __$ChatResultCopyWithImpl;
@override @useResult
$Res call({
 String message, ScheduleChangePreview? preview,@JsonKey(name: 'error_code') String? errorCode
});


@override $ScheduleChangePreviewCopyWith<$Res>? get preview;

}
/// @nodoc
class __$ChatResultCopyWithImpl<$Res>
    implements _$ChatResultCopyWith<$Res> {
  __$ChatResultCopyWithImpl(this._self, this._then);

  final _ChatResult _self;
  final $Res Function(_ChatResult) _then;

/// Create a copy of ChatResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? preview = freezed,Object? errorCode = freezed,}) {
  return _then(_ChatResult(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,preview: freezed == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as ScheduleChangePreview?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ChatResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduleChangePreviewCopyWith<$Res>? get preview {
    if (_self.preview == null) {
    return null;
  }

  return $ScheduleChangePreviewCopyWith<$Res>(_self.preview!, (value) {
    return _then(_self.copyWith(preview: value));
  });
}
}

/// @nodoc
mixin _$ScheduleChangePreview {

 String get operationId; PreviewAction get action; int get pipelineRevision; Todo? get before; Todo? get after; List<SchedulePreviewItem> get items;
/// Create a copy of ScheduleChangePreview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleChangePreviewCopyWith<ScheduleChangePreview> get copyWith => _$ScheduleChangePreviewCopyWithImpl<ScheduleChangePreview>(this as ScheduleChangePreview, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleChangePreview&&(identical(other.operationId, operationId) || other.operationId == operationId)&&(identical(other.action, action) || other.action == action)&&(identical(other.pipelineRevision, pipelineRevision) || other.pipelineRevision == pipelineRevision)&&(identical(other.before, before) || other.before == before)&&(identical(other.after, after) || other.after == after)&&const DeepCollectionEquality().equals(other.items, items));
}


@override
int get hashCode => Object.hash(runtimeType,operationId,action,pipelineRevision,before,after,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'ScheduleChangePreview(operationId: $operationId, action: $action, pipelineRevision: $pipelineRevision, before: $before, after: $after, items: $items)';
}


}

/// @nodoc
abstract mixin class $ScheduleChangePreviewCopyWith<$Res>  {
  factory $ScheduleChangePreviewCopyWith(ScheduleChangePreview value, $Res Function(ScheduleChangePreview) _then) = _$ScheduleChangePreviewCopyWithImpl;
@useResult
$Res call({
 String operationId, PreviewAction action, int pipelineRevision, Todo? before, Todo? after, List<SchedulePreviewItem> items
});


$TodoCopyWith<$Res>? get before;$TodoCopyWith<$Res>? get after;

}
/// @nodoc
class _$ScheduleChangePreviewCopyWithImpl<$Res>
    implements $ScheduleChangePreviewCopyWith<$Res> {
  _$ScheduleChangePreviewCopyWithImpl(this._self, this._then);

  final ScheduleChangePreview _self;
  final $Res Function(ScheduleChangePreview) _then;

/// Create a copy of ScheduleChangePreview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? operationId = null,Object? action = null,Object? pipelineRevision = null,Object? before = freezed,Object? after = freezed,Object? items = null,}) {
  return _then(_self.copyWith(
operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as PreviewAction,pipelineRevision: null == pipelineRevision ? _self.pipelineRevision : pipelineRevision // ignore: cast_nullable_to_non_nullable
as int,before: freezed == before ? _self.before : before // ignore: cast_nullable_to_non_nullable
as Todo?,after: freezed == after ? _self.after : after // ignore: cast_nullable_to_non_nullable
as Todo?,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<SchedulePreviewItem>,
  ));
}
/// Create a copy of ScheduleChangePreview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TodoCopyWith<$Res>? get before {
    if (_self.before == null) {
    return null;
  }

  return $TodoCopyWith<$Res>(_self.before!, (value) {
    return _then(_self.copyWith(before: value));
  });
}/// Create a copy of ScheduleChangePreview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TodoCopyWith<$Res>? get after {
    if (_self.after == null) {
    return null;
  }

  return $TodoCopyWith<$Res>(_self.after!, (value) {
    return _then(_self.copyWith(after: value));
  });
}
}


/// Adds pattern-matching-related methods to [ScheduleChangePreview].
extension ScheduleChangePreviewPatterns on ScheduleChangePreview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScheduleChangePreview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScheduleChangePreview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScheduleChangePreview value)  $default,){
final _that = this;
switch (_that) {
case _ScheduleChangePreview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScheduleChangePreview value)?  $default,){
final _that = this;
switch (_that) {
case _ScheduleChangePreview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String operationId,  PreviewAction action,  int pipelineRevision,  Todo? before,  Todo? after,  List<SchedulePreviewItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduleChangePreview() when $default != null:
return $default(_that.operationId,_that.action,_that.pipelineRevision,_that.before,_that.after,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String operationId,  PreviewAction action,  int pipelineRevision,  Todo? before,  Todo? after,  List<SchedulePreviewItem> items)  $default,) {final _that = this;
switch (_that) {
case _ScheduleChangePreview():
return $default(_that.operationId,_that.action,_that.pipelineRevision,_that.before,_that.after,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String operationId,  PreviewAction action,  int pipelineRevision,  Todo? before,  Todo? after,  List<SchedulePreviewItem> items)?  $default,) {final _that = this;
switch (_that) {
case _ScheduleChangePreview() when $default != null:
return $default(_that.operationId,_that.action,_that.pipelineRevision,_that.before,_that.after,_that.items);case _:
  return null;

}
}

}

/// @nodoc


class _ScheduleChangePreview implements ScheduleChangePreview {
  const _ScheduleChangePreview({required this.operationId, required this.action, this.pipelineRevision = 1, this.before, this.after, final  List<SchedulePreviewItem> items = const <SchedulePreviewItem>[]}): _items = items;
  

@override final  String operationId;
@override final  PreviewAction action;
@override@JsonKey() final  int pipelineRevision;
@override final  Todo? before;
@override final  Todo? after;
 final  List<SchedulePreviewItem> _items;
@override@JsonKey() List<SchedulePreviewItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of ScheduleChangePreview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduleChangePreviewCopyWith<_ScheduleChangePreview> get copyWith => __$ScheduleChangePreviewCopyWithImpl<_ScheduleChangePreview>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduleChangePreview&&(identical(other.operationId, operationId) || other.operationId == operationId)&&(identical(other.action, action) || other.action == action)&&(identical(other.pipelineRevision, pipelineRevision) || other.pipelineRevision == pipelineRevision)&&(identical(other.before, before) || other.before == before)&&(identical(other.after, after) || other.after == after)&&const DeepCollectionEquality().equals(other._items, _items));
}


@override
int get hashCode => Object.hash(runtimeType,operationId,action,pipelineRevision,before,after,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'ScheduleChangePreview(operationId: $operationId, action: $action, pipelineRevision: $pipelineRevision, before: $before, after: $after, items: $items)';
}


}

/// @nodoc
abstract mixin class _$ScheduleChangePreviewCopyWith<$Res> implements $ScheduleChangePreviewCopyWith<$Res> {
  factory _$ScheduleChangePreviewCopyWith(_ScheduleChangePreview value, $Res Function(_ScheduleChangePreview) _then) = __$ScheduleChangePreviewCopyWithImpl;
@override @useResult
$Res call({
 String operationId, PreviewAction action, int pipelineRevision, Todo? before, Todo? after, List<SchedulePreviewItem> items
});


@override $TodoCopyWith<$Res>? get before;@override $TodoCopyWith<$Res>? get after;

}
/// @nodoc
class __$ScheduleChangePreviewCopyWithImpl<$Res>
    implements _$ScheduleChangePreviewCopyWith<$Res> {
  __$ScheduleChangePreviewCopyWithImpl(this._self, this._then);

  final _ScheduleChangePreview _self;
  final $Res Function(_ScheduleChangePreview) _then;

/// Create a copy of ScheduleChangePreview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? operationId = null,Object? action = null,Object? pipelineRevision = null,Object? before = freezed,Object? after = freezed,Object? items = null,}) {
  return _then(_ScheduleChangePreview(
operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as PreviewAction,pipelineRevision: null == pipelineRevision ? _self.pipelineRevision : pipelineRevision // ignore: cast_nullable_to_non_nullable
as int,before: freezed == before ? _self.before : before // ignore: cast_nullable_to_non_nullable
as Todo?,after: freezed == after ? _self.after : after // ignore: cast_nullable_to_non_nullable
as Todo?,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<SchedulePreviewItem>,
  ));
}

/// Create a copy of ScheduleChangePreview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TodoCopyWith<$Res>? get before {
    if (_self.before == null) {
    return null;
  }

  return $TodoCopyWith<$Res>(_self.before!, (value) {
    return _then(_self.copyWith(before: value));
  });
}/// Create a copy of ScheduleChangePreview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TodoCopyWith<$Res>? get after {
    if (_self.after == null) {
    return null;
  }

  return $TodoCopyWith<$Res>(_self.after!, (value) {
    return _then(_self.copyWith(after: value));
  });
}
}

// dart format on
