import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:family_chores_app/core/database/app_database.dart';
import 'package:family_chores_app/core/enums/operation_type.dart';
import 'package:family_chores_app/core/network/connectivity_service.dart';
import 'package:family_chores_app/core/network/connectivity_status.dart';
import 'package:family_chores_app/core/sync/conflict_resolver.dart';
import 'package:family_chores_app/core/sync/entity_sync_adapter.dart';
import 'package:family_chores_app/core/sync/models/conflict_result.dart';
import 'package:family_chores_app/core/sync/operation_queue.dart';
import 'package:family_chores_app/core/sync/sync_engine.dart';
import 'package:family_chores_app/core/sync/sync_event.dart';
import 'package:family_chores_app/core/sync/sync_state.dart';
import 'package:family_chores_app/core/sync/sync_status.dart';
import 'package:mocktail/mocktail.dart';

class MockOperationQueue extends Mock implements OperationQueue {}

class MockConflictResolver extends Mock implements ConflictResolver {}

class MockSyncEngine extends Mock implements SyncEngine {}

class MockEntitySyncAdapter extends Mock implements EntitySyncAdapter {}

class MockConnectivity extends Mock implements Connectivity {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockAppDatabase extends Mock implements AppDatabase {}

void registerTestFallbackValues() {
  registerFallbackValue(OperationType.create);
  registerFallbackValue(SyncStatus.pending);
  registerFallbackValue(ConnectivityStatus.online);
  registerFallbackValue(DateTime(2026));
  registerFallbackValue(const SyncIdle());
  registerFallbackValue(const SyncEvent.authRequired());
  registerFallbackValue(
    const ConflictResult(
      winner: ConflictWinner.remote,
      winnerState: null,
      loserState: null,
      reason: 'fallback',
    ),
  );
}
