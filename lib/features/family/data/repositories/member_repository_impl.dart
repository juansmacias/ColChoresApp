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
import '../../domain/entities/member.dart';
import '../../domain/repositories/member_repository.dart';
import '../datasources/member_local_datasource.dart';

@LazySingleton(as: MemberRepository)
class MemberRepositoryImpl implements MemberRepository {
  MemberRepositoryImpl(
    this._memberLocalDataSource,
    this._syncEngine,
    this._idGenerator,
  );

  final MemberLocalDataSource _memberLocalDataSource;
  final SyncEngine _syncEngine;
  final IdGenerator _idGenerator;

  @override
  Future<Result<Member>> createMember({
    required String familyId,
    required String name,
    required int age,
    required MemberRole role,
    required String avatarSeed,
    required String accentColor,
    String? userId,
  }) async {
    try {
      final now = DateTime.now();
      final remoteId = _idGenerator.generate();

      final localId = await _memberLocalDataSource.insertMember(
        MembersTableCompanion.insert(
          remoteId: Value(remoteId),
          familyId: familyId,
          name: name,
          role: role,
          age: age,
          avatarUrl: Value(avatarSeed),
          accentColor: accentColor,
          userId: Value(userId),
          createdAt: now,
          updatedAt: now,
          syncStatus: const Value(SyncStatus.pending),
        ),
      );

      await _syncEngine.enqueueOperation(
        entityType: 'member',
        entityId: remoteId,
        operationType: OperationType.create,
        payload: jsonEncode({
          'remoteId': remoteId,
          'familyId': familyId,
          'name': name,
          'age': age,
          'role': role.name,
          'avatarSeed': avatarSeed,
          'accentColor': accentColor,
          'userId': userId,
        }),
      );

      return Result.success(
        Member(
          id: localId.toString(),
          remoteId: remoteId,
          familyId: familyId,
          name: name,
          role: role,
          age: age,
          avatarSeed: avatarSeed,
          accentColor: accentColor,
          userId: userId,
          createdAt: now,
        ),
      );
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to create member.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteMember(String memberId) async {
    try {
      await _memberLocalDataSource.deleteMember(int.parse(memberId));
      return const Result.success(null);
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to delete member.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Member?>> getMember(String memberId) async {
    try {
      final row = await _memberLocalDataSource.getMember(int.parse(memberId));
      return Result.success(row == null ? null : _toMember(row));
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to load member.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Member?>> getMemberForUser(String uid) async {
    try {
      final row = await _memberLocalDataSource.getMemberForUser(uid);
      return Result.success(row == null ? null : _toMember(row));
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to load linked member.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<Member>>> getMembersForFamily(String familyId) async {
    try {
      final rows = await _memberLocalDataSource.getMembersForFamily(familyId);
      return Result.success(rows.map(_toMember).toList(growable: false));
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to load members.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Member>> updateMember({
    required String memberId,
    String? name,
    int? age,
    String? avatarSeed,
    String? accentColor,
  }) async {
    try {
      final existing =
          await _memberLocalDataSource.getMember(int.parse(memberId));
      if (existing == null) {
        return const Result.failure(
          DatabaseFailure(message: 'Member not found.'),
        );
      }

      await _memberLocalDataSource.updateMember(
        int.parse(memberId),
        MembersTableCompanion(
          name:
              name == null ? const Value<String>.absent() : Value<String>(name),
          age: age == null ? const Value<int>.absent() : Value<int>(age),
          avatarUrl: avatarSeed == null
              ? const Value<String?>.absent()
              : Value<String?>(avatarSeed),
          accentColor: accentColor == null
              ? const Value<String>.absent()
              : Value<String>(accentColor),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(SyncStatus.pending),
        ),
      );

      final updated =
          await _memberLocalDataSource.getMember(int.parse(memberId));
      return Result.success(_toMember(updated!));
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to update member.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Stream<List<Member>> watchMembersForFamily(String familyId) {
    return _memberLocalDataSource
        .watchMembersForFamily(familyId)
        .map<List<Member>>(
          (rows) => rows.map<Member>(_toMember).toList(growable: false),
        );
  }

  Member _toMember(MembersTableData row) {
    return Member(
      id: row.id.toString(),
      remoteId: row.remoteId,
      familyId: row.familyId,
      name: row.name,
      role: row.role,
      age: row.age,
      avatarSeed: row.avatarUrl ?? 'avatar_fox',
      accentColor: row.accentColor,
      userId: row.userId,
      points: row.points,
      currentStreak: row.currentStreak,
      longestStreak: row.longestStreak,
      hasPin: row.pinHash != null && row.pinSalt != null,
      createdAt: row.createdAt,
    );
  }
}
