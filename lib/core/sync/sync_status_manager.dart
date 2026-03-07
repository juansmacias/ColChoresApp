import 'dart:async';

import 'package:injectable/injectable.dart';

import 'sync_event.dart';
import 'sync_state.dart';

/// Manages sync state and event streams.
/// The [SyncEngineImpl] uses this to broadcast state changes and events.
@lazySingleton
class SyncStatusManager {
  final _stateController = StreamController<SyncState>.broadcast();
  final _eventController = StreamController<SyncEvent>.broadcast();

  SyncState _currentState = const SyncState.stopped();

  /// Stream of high-level sync state changes.
  Stream<SyncState> get stateStream => _stateController.stream;

  /// Stream of individual sync events (for UI notifications).
  Stream<SyncEvent> get eventStream => _eventController.stream;

  /// Current sync state snapshot.
  SyncState get currentState => _currentState;

  /// Emits a new state.
  void emitState(SyncState state) {
    _currentState = state;
    _stateController.add(state);
  }

  /// Emits an individual sync event.
  void emitEvent(SyncEvent event) {
    _eventController.add(event);
  }

  /// Closes both streams. Call on app disposal.
  void dispose() {
    _stateController.close();
    _eventController.close();
  }
}
