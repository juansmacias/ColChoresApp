import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/family.dart';
import '../../domain/repositories/family_repository.dart';

part 'family_event.dart';
part 'family_state.dart';

@singleton
class FamilyBloc extends Bloc<FamilyEvent, FamilyState> {
  FamilyBloc(this._familyRepository) : super(const FamilyInitial()) {
    on<FamilyCheckRequested>(_onCheckRequested);
    on<CreateFamilyRequested>(_onCreateRequested);
    on<JoinFamilyRequested>(_onJoinRequested);
    on<GenerateInviteCodeRequested>(_onGenerateInviteCodeRequested);
    on<FamilyHydrated>(_onHydrated);
    on<FamilyCleared>(_onCleared);
  }

  final FamilyRepository _familyRepository;
  StreamSubscription<Family?>? _familySubscription;

  Future<void> _onCheckRequested(
    FamilyCheckRequested event,
    Emitter<FamilyState> emit,
  ) async {
    emit(const FamilyLoading());
    final result = await _familyRepository.getFamilyForUser(event.uid);
    await result.when(
      success: (family) async {
        await _familySubscription?.cancel();
        if (family == null) {
          emit(const FamilyNotFound());
          return;
        }
        emit(FamilyLoaded(family));
        _familySubscription =
            _familyRepository.watchFamily(family.syncId).listen(
          (updatedFamily) {
            if (updatedFamily != null && !isClosed) {
              add(FamilyHydrated(updatedFamily));
            }
          },
        );
      },
      failure: (failure) async => emit(FamilyError(failure)),
    );
  }

  Future<void> _onCreateRequested(
    CreateFamilyRequested event,
    Emitter<FamilyState> emit,
  ) async {
    emit(const FamilyLoading());
    final result = await _familyRepository.createFamily(
      name: event.name,
      createdByUid: event.createdByUid,
      createdByName: event.createdByName,
    );
    result.when(
      success: (family) => emit(FamilyCreated(family)),
      failure: (failure) => emit(FamilyError(failure)),
    );
  }

  Future<void> _onJoinRequested(
    JoinFamilyRequested event,
    Emitter<FamilyState> emit,
  ) async {
    emit(const FamilyLoading());
    final result = await _familyRepository.joinFamily(
      inviteCode: event.inviteCode,
      userId: event.userId,
      userName: event.userName,
    );
    result.when(
      success: (family) => emit(FamilyJoined(family)),
      failure: (failure) => emit(FamilyError(failure)),
    );
  }

  Future<void> _onGenerateInviteCodeRequested(
    GenerateInviteCodeRequested event,
    Emitter<FamilyState> emit,
  ) async {
    emit(const FamilyLoading());
    final result = await _familyRepository.generateInviteCode(event.familyId);
    result.when(
      success: (inviteCode) => emit(InviteCodeGenerated(inviteCode)),
      failure: (failure) => emit(FamilyError(failure)),
    );
  }

  Future<void> _onCleared(
    FamilyCleared event,
    Emitter<FamilyState> emit,
  ) async {
    await _familySubscription?.cancel();
    emit(const FamilyInitial());
  }

  Future<void> _onHydrated(
    FamilyHydrated event,
    Emitter<FamilyState> emit,
  ) async {
    emit(FamilyLoaded(event.family));
  }

  @override
  Future<void> close() async {
    await _familySubscription?.cancel();
    return super.close();
  }
}
