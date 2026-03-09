import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/enums/member_role.dart';
import '../../../../core/enums/operation_type.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/family.dart';
import '../../domain/repositories/family_repository.dart';
import '../datasources/family_local_datasource.dart';
import '../datasources/family_remote_datasource.dart';
import '../datasources/member_local_datasource.dart';

@LazySingleton(as: FamilyRepository)
class FamilyRepositoryImpl implements FamilyRepository {
  FamilyRepositoryImpl(
    this._familyLocalDataSource,
    this._memberLocalDataSource,
    this._familyRemoteDataSource,
    this._syncEngine,
    this._idGenerator,
  );

  final FamilyLocalDataSource _familyLocalDataSource;
  final MemberLocalDataSource _memberLocalDataSource;
  final FamilyRemoteDataSource _familyRemoteDataSource;
  final SyncEngine _syncEngine;
  final IdGenerator _idGenerator;

  @override
  Future<Result<Family>> createFamily({
    required String name,
    required String createdByUid,
    required String createdByName,
  }) async {
    try {
      final now = DateTime.now();
      final familyId = _idGenerator.generate();
      final memberId = _idGenerator.generate();

      final localId = await _familyLocalDataSource.insertFamily(
        FamiliesTableCompanion.insert(
          remoteId: Value(familyId),
          name: name,
          createdBy: createdByUid,
          createdAt: now,
          updatedAt: now,
          syncStatus: const Value(SyncStatus.pending),
        ),
      );

      await _memberLocalDataSource.insertMember(
        MembersTableCompanion.insert(
          remoteId: Value(memberId),
          familyId: familyId,
          name: createdByName,
          role: MemberRole.parent,
          age: 30,
          avatarUrl: const Value('avatar_bear'),
          accentColor: '#A8D8EA',
          userId: Value(createdByUid),
          createdAt: now,
          updatedAt: now,
          syncStatus: const Value(SyncStatus.pending),
        ),
      );

      await _syncEngine.enqueueOperation(
        entityType: 'family',
        entityId: familyId,
        operationType: OperationType.create,
        payload: jsonEncode({
          'remoteId': familyId,
          'name': name,
          'createdBy': createdByUid,
        }),
      );

      await _syncEngine.enqueueOperation(
        entityType: 'member',
        entityId: memberId,
        operationType: OperationType.create,
        payload: jsonEncode({
          'remoteId': memberId,
          'familyId': familyId,
          'name': createdByName,
          'role': MemberRole.parent.name,
          'age': 30,
          'avatarSeed': 'avatar_bear',
          'accentColor': '#A8D8EA',
          'userId': createdByUid,
        }),
      );

      return Result.success(
        Family(
          id: localId.toString(),
          remoteId: familyId,
          name: name,
          createdBy: createdByUid,
          createdAt: now,
        ),
      );
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to create family.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Family?>> getFamilyForUser(String uid) async {
    try {
      final member = await _memberLocalDataSource.getMemberForUser(uid);
      if (member == null) {
        return const Result.success(null);
      }

      final family = await _familyLocalDataSource.getFamilyByRemoteId(
        member.familyId,
      );
      if (family == null) {
        return const Result.success(null);
      }

      return Result.success(_toFamily(family));
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to load family.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Stream<Family?> watchFamily(String familyId) {
    return _familyLocalDataSource.watchFamilyByRemoteId(familyId).map((row) {
      if (row == null) {
        return null;
      }
      return _toFamily(row);
    });
  }

  @override
  Future<Result<Family>> updateFamily({
    required String familyId,
    String? name,
  }) async {
    try {
      final existing =
          await _familyLocalDataSource.getFamilyByRemoteId(familyId);
      if (existing == null) {
        return const Result.failure(
          DatabaseFailure(message: 'Family not found.'),
        );
      }

      final updatedName = name ?? existing.name;
      await _familyLocalDataSource.updateFamilyByRemoteId(
        familyId,
        FamiliesTableCompanion(
          name: Value(updatedName),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(SyncStatus.pending),
        ),
      );

      await _syncEngine.enqueueOperation(
        entityType: 'family',
        entityId: familyId,
        operationType: OperationType.update,
        payload: jsonEncode({'name': updatedName}),
      );

      final updated =
          await _familyLocalDataSource.getFamilyByRemoteId(familyId);
      return Result.success(_toFamily(updated!));
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to update family.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<String>> generateInviteCode(String familyId) async {
    try {
      final code = await _familyRemoteDataSource.generateInviteCode(familyId);
      await _familyLocalDataSource.updateFamilyByRemoteId(
        familyId,
        FamiliesTableCompanion(
          inviteCode: Value(code),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return Result.success(code);
    } catch (error, stackTrace) {
      return Result.failure(
        NetworkFailure(
          message: 'Unable to generate invite code right now.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Family>> joinFamily({
    required String inviteCode,
    required String userId,
    required String userName,
  }) async {
    try {
      final familyId = await _familyRemoteDataSource.validateAndJoinFamily(
        inviteCode: inviteCode,
        userId: userId,
        userName: userName,
      );

      final existing =
          await _familyLocalDataSource.getFamilyByRemoteId(familyId);
      if (existing != null) {
        return Result.success(_toFamily(existing));
      }

      return Result.failure(
        const NetworkFailure(
          message:
              'Family join succeeded remotely, but local sync is not ready yet.',
        ),
      );
    } catch (error, stackTrace) {
      return Result.failure(
        NetworkFailure(
          message:
              'Unable to join family. Check the invite code and try again.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Family _toFamily(FamiliesTableData row) {
    return Family(
      id: row.id.toString(),
      remoteId: row.remoteId,
      name: row.name,
      createdBy: row.createdBy,
      inviteCode: row.inviteCode,
      inviteCodeExpiresAt: row.inviteCodeExpiresAt,
      createdAt: row.createdAt,
    );
  }
}
