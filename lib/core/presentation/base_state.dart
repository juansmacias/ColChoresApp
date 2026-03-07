import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// Base state for all Cubit and BLoC state hierarchies.
sealed class BaseState extends Equatable {
  const BaseState();

  /// Whether this state represents data currently shown while offline.
  bool get isOffline => false;

  @override
  List<Object?> get props => [];
}

class InitialState extends BaseState {
  const InitialState();
}

class LoadingState<T> extends BaseState {
  const LoadingState({this.previousData});

  final T? previousData;

  @override
  List<Object?> get props => [previousData];
}

class LoadedState<T> extends BaseState {
  const LoadedState({
    required this.data,
    this.isOffline = false,
    this.lastSyncedAt,
  });

  final T data;

  @override
  final bool isOffline;

  final DateTime? lastSyncedAt;

  LoadedState<T> copyWith({
    T? data,
    bool? isOffline,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
  }) {
    return LoadedState<T>(
      data: data ?? this.data,
      isOffline: isOffline ?? this.isOffline,
      lastSyncedAt:
          clearLastSyncedAt ? null : lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  List<Object?> get props => [data, isOffline, lastSyncedAt];
}

class ErrorState extends BaseState {
  const ErrorState({
    required this.failure,
    this.previousData,
  });

  final Failure failure;
  final Object? previousData;

  @override
  List<Object?> get props => [failure, previousData];
}
