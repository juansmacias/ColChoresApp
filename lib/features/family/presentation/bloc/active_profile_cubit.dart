import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_constants.dart';
import '../../domain/entities/member.dart';
import '../../domain/repositories/member_repository.dart';

@lazySingleton
class ActiveProfileCubit extends Cubit<Member?> {
  ActiveProfileCubit(
    this._sharedPreferences,
    this._memberRepository,
  ) : super(null);

  final SharedPreferences _sharedPreferences;
  final MemberRepository _memberRepository;

  String? get activeMemberId =>
      _sharedPreferences.getString(StorageConstants.activeProfileIdKey);

  bool get isParentProfile => state?.isParent ?? false;

  Future<void> loadActiveProfile() async {
    final memberId = activeMemberId;
    if (memberId == null) {
      emit(null);
      return;
    }

    final result = await _memberRepository.getMember(memberId);
    result.when(
      success: emit,
      failure: (_) => emit(null),
    );
  }

  Future<void> switchProfile(Member member) async {
    await _sharedPreferences.setString(
      StorageConstants.activeProfileIdKey,
      member.id,
    );
    emit(member);
  }

  Future<void> clearProfile() async {
    await _sharedPreferences.remove(StorageConstants.activeProfileIdKey);
    emit(null);
  }
}
