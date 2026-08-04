// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatState {

 bool get isSending; bool get isAnalyzing; bool get isPreviewSaving; bool get isRecoveryVisible; List<Todo> get recoveryTodos; String? get assistantMessage; String? get errorMessage; ScheduleChangePreview? get preview;
/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatStateCopyWith<ChatState> get copyWith => _$ChatStateCopyWithImpl<ChatState>(this as ChatState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatState&&(identical(other.isSending, isSending) || other.isSending == isSending)&&(identical(other.isAnalyzing, isAnalyzing) || other.isAnalyzing == isAnalyzing)&&(identical(other.isPreviewSaving, isPreviewSaving) || other.isPreviewSaving == isPreviewSaving)&&(identical(other.isRecoveryVisible, isRecoveryVisible) || other.isRecoveryVisible == isRecoveryVisible)&&const DeepCollectionEquality().equals(other.recoveryTodos, recoveryTodos)&&(identical(other.assistantMessage, assistantMessage) || other.assistantMessage == assistantMessage)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.preview, preview) || other.preview == preview));
}


@override
int get hashCode => Object.hash(runtimeType,isSending,isAnalyzing,isPreviewSaving,isRecoveryVisible,const DeepCollectionEquality().hash(recoveryTodos),assistantMessage,errorMessage,preview);

@override
String toString() {
  return 'ChatState(isSending: $isSending, isAnalyzing: $isAnalyzing, isPreviewSaving: $isPreviewSaving, isRecoveryVisible: $isRecoveryVisible, recoveryTodos: $recoveryTodos, assistantMessage: $assistantMessage, errorMessage: $errorMessage, preview: $preview)';
}


}

/// @nodoc
abstract mixin class $ChatStateCopyWith<$Res>  {
  factory $ChatStateCopyWith(ChatState value, $Res Function(ChatState) _then) = _$ChatStateCopyWithImpl;
@useResult
$Res call({
 bool isSending, bool isAnalyzing, bool isPreviewSaving, bool isRecoveryVisible, List<Todo> recoveryTodos, String? assistantMessage, String? errorMessage, ScheduleChangePreview? preview
});


$ScheduleChangePreviewCopyWith<$Res>? get preview;

}
/// @nodoc
class _$ChatStateCopyWithImpl<$Res>
    implements $ChatStateCopyWith<$Res> {
  _$ChatStateCopyWithImpl(this._self, this._then);

  final ChatState _self;
  final $Res Function(ChatState) _then;

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isSending = null,Object? isAnalyzing = null,Object? isPreviewSaving = null,Object? isRecoveryVisible = null,Object? recoveryTodos = null,Object? assistantMessage = freezed,Object? errorMessage = freezed,Object? preview = freezed,}) {
  return _then(_self.copyWith(
isSending: null == isSending ? _self.isSending : isSending // ignore: cast_nullable_to_non_nullable
as bool,isAnalyzing: null == isAnalyzing ? _self.isAnalyzing : isAnalyzing // ignore: cast_nullable_to_non_nullable
as bool,isPreviewSaving: null == isPreviewSaving ? _self.isPreviewSaving : isPreviewSaving // ignore: cast_nullable_to_non_nullable
as bool,isRecoveryVisible: null == isRecoveryVisible ? _self.isRecoveryVisible : isRecoveryVisible // ignore: cast_nullable_to_non_nullable
as bool,recoveryTodos: null == recoveryTodos ? _self.recoveryTodos : recoveryTodos // ignore: cast_nullable_to_non_nullable
as List<Todo>,assistantMessage: freezed == assistantMessage ? _self.assistantMessage : assistantMessage // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,preview: freezed == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as ScheduleChangePreview?,
  ));
}
/// Create a copy of ChatState
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


/// Adds pattern-matching-related methods to [ChatState].
extension ChatStatePatterns on ChatState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatState value)  $default,){
final _that = this;
switch (_that) {
case _ChatState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatState value)?  $default,){
final _that = this;
switch (_that) {
case _ChatState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isSending,  bool isAnalyzing,  bool isPreviewSaving,  bool isRecoveryVisible,  List<Todo> recoveryTodos,  String? assistantMessage,  String? errorMessage,  ScheduleChangePreview? preview)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatState() when $default != null:
return $default(_that.isSending,_that.isAnalyzing,_that.isPreviewSaving,_that.isRecoveryVisible,_that.recoveryTodos,_that.assistantMessage,_that.errorMessage,_that.preview);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isSending,  bool isAnalyzing,  bool isPreviewSaving,  bool isRecoveryVisible,  List<Todo> recoveryTodos,  String? assistantMessage,  String? errorMessage,  ScheduleChangePreview? preview)  $default,) {final _that = this;
switch (_that) {
case _ChatState():
return $default(_that.isSending,_that.isAnalyzing,_that.isPreviewSaving,_that.isRecoveryVisible,_that.recoveryTodos,_that.assistantMessage,_that.errorMessage,_that.preview);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isSending,  bool isAnalyzing,  bool isPreviewSaving,  bool isRecoveryVisible,  List<Todo> recoveryTodos,  String? assistantMessage,  String? errorMessage,  ScheduleChangePreview? preview)?  $default,) {final _that = this;
switch (_that) {
case _ChatState() when $default != null:
return $default(_that.isSending,_that.isAnalyzing,_that.isPreviewSaving,_that.isRecoveryVisible,_that.recoveryTodos,_that.assistantMessage,_that.errorMessage,_that.preview);case _:
  return null;

}
}

}

/// @nodoc


class _ChatState implements ChatState {
  const _ChatState({this.isSending = false, this.isAnalyzing = false, this.isPreviewSaving = false, this.isRecoveryVisible = false, final  List<Todo> recoveryTodos = const <Todo>[], this.assistantMessage, this.errorMessage, this.preview}): _recoveryTodos = recoveryTodos;
  

@override@JsonKey() final  bool isSending;
@override@JsonKey() final  bool isAnalyzing;
@override@JsonKey() final  bool isPreviewSaving;
@override@JsonKey() final  bool isRecoveryVisible;
 final  List<Todo> _recoveryTodos;
@override@JsonKey() List<Todo> get recoveryTodos {
  if (_recoveryTodos is EqualUnmodifiableListView) return _recoveryTodos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recoveryTodos);
}

@override final  String? assistantMessage;
@override final  String? errorMessage;
@override final  ScheduleChangePreview? preview;

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatStateCopyWith<_ChatState> get copyWith => __$ChatStateCopyWithImpl<_ChatState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatState&&(identical(other.isSending, isSending) || other.isSending == isSending)&&(identical(other.isAnalyzing, isAnalyzing) || other.isAnalyzing == isAnalyzing)&&(identical(other.isPreviewSaving, isPreviewSaving) || other.isPreviewSaving == isPreviewSaving)&&(identical(other.isRecoveryVisible, isRecoveryVisible) || other.isRecoveryVisible == isRecoveryVisible)&&const DeepCollectionEquality().equals(other._recoveryTodos, _recoveryTodos)&&(identical(other.assistantMessage, assistantMessage) || other.assistantMessage == assistantMessage)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.preview, preview) || other.preview == preview));
}


@override
int get hashCode => Object.hash(runtimeType,isSending,isAnalyzing,isPreviewSaving,isRecoveryVisible,const DeepCollectionEquality().hash(_recoveryTodos),assistantMessage,errorMessage,preview);

@override
String toString() {
  return 'ChatState(isSending: $isSending, isAnalyzing: $isAnalyzing, isPreviewSaving: $isPreviewSaving, isRecoveryVisible: $isRecoveryVisible, recoveryTodos: $recoveryTodos, assistantMessage: $assistantMessage, errorMessage: $errorMessage, preview: $preview)';
}


}

/// @nodoc
abstract mixin class _$ChatStateCopyWith<$Res> implements $ChatStateCopyWith<$Res> {
  factory _$ChatStateCopyWith(_ChatState value, $Res Function(_ChatState) _then) = __$ChatStateCopyWithImpl;
@override @useResult
$Res call({
 bool isSending, bool isAnalyzing, bool isPreviewSaving, bool isRecoveryVisible, List<Todo> recoveryTodos, String? assistantMessage, String? errorMessage, ScheduleChangePreview? preview
});


@override $ScheduleChangePreviewCopyWith<$Res>? get preview;

}
/// @nodoc
class __$ChatStateCopyWithImpl<$Res>
    implements _$ChatStateCopyWith<$Res> {
  __$ChatStateCopyWithImpl(this._self, this._then);

  final _ChatState _self;
  final $Res Function(_ChatState) _then;

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isSending = null,Object? isAnalyzing = null,Object? isPreviewSaving = null,Object? isRecoveryVisible = null,Object? recoveryTodos = null,Object? assistantMessage = freezed,Object? errorMessage = freezed,Object? preview = freezed,}) {
  return _then(_ChatState(
isSending: null == isSending ? _self.isSending : isSending // ignore: cast_nullable_to_non_nullable
as bool,isAnalyzing: null == isAnalyzing ? _self.isAnalyzing : isAnalyzing // ignore: cast_nullable_to_non_nullable
as bool,isPreviewSaving: null == isPreviewSaving ? _self.isPreviewSaving : isPreviewSaving // ignore: cast_nullable_to_non_nullable
as bool,isRecoveryVisible: null == isRecoveryVisible ? _self.isRecoveryVisible : isRecoveryVisible // ignore: cast_nullable_to_non_nullable
as bool,recoveryTodos: null == recoveryTodos ? _self._recoveryTodos : recoveryTodos // ignore: cast_nullable_to_non_nullable
as List<Todo>,assistantMessage: freezed == assistantMessage ? _self.assistantMessage : assistantMessage // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,preview: freezed == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as ScheduleChangePreview?,
  ));
}

/// Create a copy of ChatState
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

// dart format on
