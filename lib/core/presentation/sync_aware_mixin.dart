import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

import '../sync/sync_engine.dart';
import '../sync/sync_event.dart';

mixin SyncAwareMixin<State> on BlocBase<State> {
  static const Duration _syncThrottleDuration = Duration(milliseconds: 100);

  StreamSubscription<SyncEvent>? _syncSubscription;

  void initSyncListener({
    required SyncEngine syncEngine,
    Set<String>? relevantEntityTypes,
  }) {
    _syncSubscription = syncEngine.eventStream
        .where((event) => _isRelevantEvent(event, relevantEntityTypes))
        .throttleTime(
          _syncThrottleDuration,
          leading: false,
          trailing: true,
        )
        .listen((event) {
      if (!isClosed) {
        onSyncCompleted(event);
      }
    });
  }

  bool _isRelevantEvent(SyncEvent event, Set<String>? relevantEntityTypes) {
    if (relevantEntityTypes == null) {
      return true;
    }

    return switch (event) {
      SyncOperationCompleted(:final entityType) =>
        relevantEntityTypes.contains(entityType),
      SyncConflictResolved(:final entityType) =>
        relevantEntityTypes.contains(entityType),
      SyncOperationFailed(:final entityType) =>
        relevantEntityTypes.contains(entityType),
      SyncPullError(:final entityType) =>
        relevantEntityTypes.contains(entityType),
      _ => true,
    };
  }

  void onSyncCompleted(SyncEvent event);

  Future<void> disposeSyncListener() async {
    await _syncSubscription?.cancel();
    _syncSubscription = null;
  }
}
