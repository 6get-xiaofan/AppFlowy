import 'package:appflowy/user/application/user_listener.dart';
import 'package:appflowy/user/application/user_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/workspace.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'menu_user_bloc.freezed.dart';

class MenuUserBloc extends Bloc<MenuUserEvent, MenuUserState> {
  MenuUserBloc(this.userProfile)
      : _userListener = UserListener(userProfile: userProfile),
        _userWorkspaceListener = UserWorkspaceListener(),
        _userService = UserBackendService(userId: userProfile.id),
        super(MenuUserState.initial(userProfile)) {
    _dispatch();
  }

  final UserBackendService _userService;
  final UserListener _userListener;
  final UserWorkspaceListener _userWorkspaceListener;
  final UserProfilePB userProfile;

  @override
  Future<void> close() async {
    await _userListener.stop();
    await _userWorkspaceListener.stop();
    return super.close();
  }

  void _dispatch() {
    on<MenuUserEvent>(
      (event, emit) async {
        await event.when(
          initial: () async {
            _userListener.start(onProfileUpdated: _profileUpdated);
            await _initUser();
          },
          fetchWorkspaces: () async {
            //
          },
          didReceiveUserProfile: (UserProfilePB newUserProfile) {
            emit(state.copyWith(userProfile: newUserProfile));
          },
          updateUserName: (String name) {
            _userService.updateUserProfile(name: name).then((result) {
              result.fold(
                (l) => null,
                (err) => Log.error(err),
              );
            });
          },
        );
      },
    );
  }

  Future<void> _initUser() async {
    final result = await _userService.initUser();
    result.fold((l) => null, (error) => Log.error(error));
  }

  void _profileUpdated(Either<UserProfilePB, FlowyError> userProfileOrFailed) {
    if (isClosed) {
      return;
    }
    userProfileOrFailed.fold(
      (newUserProfile) => add(
        MenuUserEvent.didReceiveUserProfile(newUserProfile),
      ),
      (err) => Log.error(err),
    );
  }
}

@freezed
class MenuUserEvent with _$MenuUserEvent {
  const factory MenuUserEvent.initial() = _Initial;
  const factory MenuUserEvent.fetchWorkspaces() = _FetchWorkspaces;
  const factory MenuUserEvent.updateUserName(String name) = _UpdateUserName;
  const factory MenuUserEvent.didReceiveUserProfile(
    UserProfilePB newUserProfile,
  ) = _DidReceiveUserProfile;
}

@freezed
class MenuUserState with _$MenuUserState {
  const factory MenuUserState({
    required UserProfilePB userProfile,
    required Option<List<WorkspacePB>> workspaces,
    required Either<Unit, String> successOrFailure,
  }) = _MenuUserState;

  factory MenuUserState.initial(UserProfilePB userProfile) => MenuUserState(
        userProfile: userProfile,
        workspaces: none(),
        successOrFailure: left(unit),
      );
}
