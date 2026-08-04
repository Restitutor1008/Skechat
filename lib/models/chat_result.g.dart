// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatResult _$ChatResultFromJson(Map<String, dynamic> json) => _ChatResult(
  message: json['message'] as String,
  preview: json['preview'] == null
      ? null
      : ScheduleChangePreview.fromJson(json['preview'] as Map<String, dynamic>),
  errorCode: json['error_code'] as String?,
);
