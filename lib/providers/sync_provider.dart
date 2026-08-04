import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/startup_profiler.dart';
import 'holiday_provider.dart';
import 'repository_provider.dart';
import 'schedule_provider.dart';

enum CentralSyncStatus { checking, online, offline }

class CentralSyncState {
  const CentralSyncState({
    required this.status,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.nextAttemptAt,
    this.error,
  });

  const CentralSyncState.checking() : this(status: CentralSyncStatus.checking);

  final CentralSyncStatus status;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final DateTime? nextAttemptAt;
  final String? error;

  CentralSyncState copyWith({
    CentralSyncStatus? status,
    int? pendingCount,
    DateTime? lastSyncedAt,
    DateTime? nextAttemptAt,
    String? error,
  }) => CentralSyncState(
    status: status ?? this.status,
    pendingCount: pendingCount ?? this.pendingCount,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    nextAttemptAt: nextAttemptAt,
    error: error,
  );
}

final centralSyncProvider =
    NotifierProvider<CentralSyncNotifier, CentralSyncState>(
      CentralSyncNotifier.new,
    );

class CentralSyncNotifier extends Notifier<CentralSyncState> {
  Timer? _timer;
  bool _isRunning = false;
  bool _hasStarted = false;
  int _consecutiveFailures = 0;
  DateTime? _lastAttemptAt;
  DateTime? _crudUploadAt;

  @override
  CentralSyncState build() {
    ref.onDispose(() => _timer?.cancel());
    return const CentralSyncState.checking();
  }

  Future<void> startAfterLocalScheduleFrame() async {
    if (_hasStarted) return;
    _hasStarted = true;
    StartupProfiler.mark('background_services_start');
    await _initializeAndSynchronize();
  }

  Future<void> _initializeAndSynchronize() async {
    final latestChange = await ref
        .read(todoRepositoryProvider)
        .latestPendingChangeAt();
    if (latestChange != null) {
      final candidate = latestChange.add(AppConfig.crudBatchIdleDelay);
      if (candidate.isAfter(DateTime.now())) _crudUploadAt = candidate;
    }
    await _synchronize();
  }

  Future<void> noteLocalChange() async {
    final count = await ref.read(todoRepositoryProvider).pendingChangeCount();
    _crudUploadAt = DateTime.now().add(AppConfig.crudBatchIdleDelay);
    state = state.copyWith(pendingCount: count);
  }

  Future<void> synchronizeAfterServerMutation() => _synchronize();

  Future<void> synchronizeOnResume() async {
    if (!_hasStarted) return;
    final nextAttemptAt = state.nextAttemptAt;
    if (state.status == CentralSyncStatus.offline &&
        nextAttemptAt != null &&
        DateTime.now().isBefore(nextAttemptAt)) {
      return;
    }
    final lastAttempt = _lastAttemptAt;
    if (lastAttempt != null &&
        DateTime.now().difference(lastAttempt) <
            AppConfig.resumeSyncMinimumInterval) {
      return;
    }
    await _synchronize();
  }

  Future<void> _synchronize() async {
    if (_isRunning) return;
    _isRunning = true;
    _lastAttemptAt = DateTime.now();
    StartupProfiler.mark('central_sync_start');
    _timer?.cancel();
    try {
      final now = DateTime.now();
      final uploadPending =
          _crudUploadAt == null || !now.isBefore(_crudUploadAt!);
      final result = await ref
          .read(todoRepositoryProvider)
          .synchronize(uploadPending: uploadPending);
      if (uploadPending) {
        _crudUploadAt = result.pendingCount == 0
            ? null
            : DateTime.now().add(AppConfig.crudBatchIdleDelay);
      }
      _consecutiveFailures = 0;
      final syncedAt = DateTime.now();
      state = CentralSyncState(
        status: CentralSyncStatus.online,
        pendingCount: result.pendingCount,
        lastSyncedAt: syncedAt,
        nextAttemptAt: syncedAt.add(AppConfig.centralSyncInterval),
      );
      StartupProfiler.mark('central_sync_end', {
        'changed': result.changed,
        'pending_count': result.pendingCount,
      });
      if (result.changed) {
        await ref.read(scheduleProvider.notifier).refreshFromLocal();
      }
      if (result.holidaysChanged) {
        ref.invalidate(koreanHolidayProvider);
      }
      _schedule(AppConfig.centralSyncInterval);
    } catch (error) {
      StartupProfiler.mark('central_sync_failed', {
        'error_type': error.runtimeType.toString(),
      });
      _consecutiveFailures++;
      final delay = _failureDelay(_consecutiveFailures);
      var pendingCount = state.pendingCount;
      try {
        pendingCount = await ref
            .read(todoRepositoryProvider)
            .pendingChangeCount();
      } catch (_) {
        // The existing count is more useful than replacing it with a DB error.
      }
      state = CentralSyncState(
        status: CentralSyncStatus.offline,
        pendingCount: pendingCount,
        lastSyncedAt: state.lastSyncedAt,
        nextAttemptAt: DateTime.now().add(delay),
        error: error.toString(),
      );
      _schedule(delay);
    } finally {
      _isRunning = false;
    }
  }

  Duration _failureDelay(int failures) {
    final multiplier = 1 << (failures - 1).clamp(0, 10);
    final seconds = AppConfig.centralSyncInterval.inSeconds * multiplier;
    return Duration(
      seconds: seconds.clamp(
        AppConfig.centralSyncInterval.inSeconds,
        AppConfig.centralSyncMaximumBackoff.inSeconds,
      ),
    );
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _synchronize);
  }
}
