import 'package:drift/drift.dart' hide isNotNull;
import 'package:family_chores_app/core/database/app_database.dart';
import 'package:family_chores_app/core/enums/member_role.dart';
import 'package:family_chores_app/core/sync/sync_engine.dart';
import 'package:family_chores_app/core/utils/id_generator.dart';
import 'package:family_chores_app/features/family/data/datasources/family_local_datasource.dart';
import 'package:family_chores_app/features/family/data/datasources/family_remote_datasource.dart';
import 'package:family_chores_app/features/family/data/datasources/member_local_datasource.dart';
import 'package:family_chores_app/features/family/data/repositories/family_repository_impl.dart';
import 'package:family_chores_app/features/family/domain/entities/family.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/drift_test_helper.dart';

class MockFamilyRemoteDataSource extends Mock
    implements FamilyRemoteDataSource {}

class MockSyncEngine extends Mock implements SyncEngine {}

class MockIdGenerator extends Mock implements IdGenerator {}

void main() {
  group('FamilyRepositoryImpl', () {
    late AppDatabase database;
    late FamilyLocalDataSource familyLocalDataSource;
    late MemberLocalDataSource memberLocalDataSource;
    late MockFamilyRemoteDataSource familyRemoteDataSource;
    late MockSyncEngine syncEngine;
    late MockIdGenerator idGenerator;
    late FamilyRepositoryImpl repository;

    setUp(() async {
      database = await DriftTestHelper.createInMemoryDatabase();
      familyLocalDataSource = FamilyLocalDataSource(database);
      memberLocalDataSource = MemberLocalDataSource(database);
      familyRemoteDataSource = MockFamilyRemoteDataSource();
      syncEngine = MockSyncEngine();
      idGenerator = MockIdGenerator();

      repository = FamilyRepositoryImpl(
        familyLocalDataSource,
        memberLocalDataSource,
        familyRemoteDataSource,
        syncEngine,
        idGenerator,
      );
    });

    tearDown(() async {
      await DriftTestHelper.closeDatabase(database);
    });

    test('joinFamily should persist remote success locally when family is new',
        () async {
      when(
        () => familyRemoteDataSource.validateAndJoinFamily(
          inviteCode: 'ABC123',
          userId: 'user-1',
          userName: 'Sofia',
        ),
      ).thenAnswer(
        (_) async => (
          familyId: 'family-1',
          familyName: 'The Johnsons',
        ),
      );

      final result = await repository.joinFamily(
        inviteCode: 'ABC123',
        userId: 'user-1',
        userName: 'Sofia',
      );

      expect(result.isSuccess, isTrue);
      expect(
        result.valueOrNull,
        isA<Family>()
            .having((family) => family.remoteId, 'remoteId', 'family-1')
            .having((family) => family.name, 'name', 'The Johnsons'),
      );

      final storedFamily =
          await familyLocalDataSource.getFamilyByRemoteId('family-1');
      final storedMember =
          await memberLocalDataSource.getMemberForUser('user-1');

      expect(storedFamily, isNotNull);
      expect(storedFamily!.name, 'The Johnsons');
      expect(storedMember, isNotNull);
      expect(storedMember!.familyId, 'family-1');
      expect(storedMember.role, MemberRole.parent);
    });

    test('joinFamily should reuse existing local family when already hydrated',
        () async {
      final now = DateTime(2026, 3, 9, 10);
      await familyLocalDataSource.insertFamily(
        FamiliesTableCompanion.insert(
          remoteId: const Value('family-1'),
          name: 'Existing Family',
          createdBy: 'owner-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      when(
        () => familyRemoteDataSource.validateAndJoinFamily(
          inviteCode: 'ABC123',
          userId: 'user-1',
          userName: 'Sofia',
        ),
      ).thenAnswer(
        (_) async => (
          familyId: 'family-1',
          familyName: 'Server Name',
        ),
      );

      final result = await repository.joinFamily(
        inviteCode: 'ABC123',
        userId: 'user-1',
        userName: 'Sofia',
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.name, 'Existing Family');
    });
  });
}
