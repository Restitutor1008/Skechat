class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String defaultUserId = 'Skechatter';
  static const Duration requestTimeout = Duration(seconds: 12);
  static const Duration llmRequestTimeout = Duration(seconds: 60);
  static const Duration chatInputDebounce = Duration(milliseconds: 500);
  static const int chatTimeoutMaximumAttempts = 3;
  static const Duration chatTimeoutRetryDelay = Duration(milliseconds: 400);
  static const Duration centralSyncInterval = Duration(seconds: 30);
  static const Duration centralSyncMaximumBackoff = Duration(minutes: 5);
  static const Duration resumeSyncMinimumInterval = Duration(seconds: 5);
  static const Duration crudBatchIdleDelay = Duration(minutes: 5);
  static const int maximumCrudBatchSize = 100;
  static const Duration koreaUtcOffset = Duration(hours: 9);
  static const int maximumAlarmMinutes = 30;
  static const int calendarYearRange = 10;
}
