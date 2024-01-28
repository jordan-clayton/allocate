import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import "../model/user/allocate_user.dart";
import '../util/enums.dart';
import '../util/exceptions.dart';
import 'isar_service.dart';
import 'supabase_service.dart';

class UserStorageService extends ChangeNotifier {
  static final UserStorageService _instance = UserStorageService._internal();

  static UserStorageService get instance => _instance;

  final SupabaseClient _supabaseClient =
      SupabaseService.instance.supabaseClient;
  final Isar _isarClient = IsarService.instance.isarClient;

  late final RealtimeChannel _userStream;

  bool get isConnected => SupabaseService.instance.isConnected;

  bool _subscribed = false;

  UserStatus _status = UserStatus.normal;

  UserStatus get status => _status;

  List<AllocateUser?> _failureCache = [];

  List<AllocateUser?> get failureCache => _failureCache;

  Future<void> updateUser({required AllocateUser user}) async {
    user.isSynced = isConnected;
    late int? id;
    await _isarClient.writeTxn(() async {
      id = await _isarClient.allocateUsers.put(user);
    });
    if (null == id) {
      throw FailureToUpdateException("Failed to update user locally\n "
          "User: $user\n Time: ${DateTime.now()}\n"
          "Isar Open: ${_isarClient.isOpen}");
    }
    if (isConnected) {
      Map<String, dynamic> userEntity = user.toEntity();
      final List<Map<String, dynamic>> response =
          await _supabaseClient.from("users").upsert(userEntity).select("id");

      id = response.last["id"];
      if (null == id) {
        throw FailureToUploadException("Failed to sync user on update\n"
            "User: $user\n"
            "Time: ${DateTime.now()}\n"
            "Supabase Open: $isConnected"
            "Session expired: ${_supabaseClient.auth.currentSession?.isExpired}");
      }
    }
  }

  Future<void> syncUser({AllocateUser? onlineUser}) async {
    if (!isConnected) {
      return;
    }

    AllocateUser? localUser;

    try {
      localUser = await getUser();
      if (null == localUser) {
        throw UserMissingException("Local user missing from DB\n"
            "Users size: ${_isarClient.allocateUsers.countSync()}\n");
      }

      onlineUser = onlineUser ?? await fetchUser();
      if (onlineUser != localUser) {
        throw MultipleUsersException(
            "Users do not match\n"
            "localID: ${localUser.id}\n,"
            "onlineID: ${onlineUser.id}\n",
            users: [onlineUser, localUser]);
      }

      // Grab the most recent user -> if it is the local one, just put back.
      AllocateUser toPut;
      if (localUser.lastUpdated.isAfter(onlineUser.lastUpdated)) {
        toPut = localUser;
      } else {
        toPut = onlineUser.copyWith(
          windowEffect: localUser.windowEffect,
          themeType: localUser.themeType,
          toneMapping: localUser.toneMapping,
          primarySeed: localUser.primarySeed,
          secondarySeed: localUser.secondarySeed,
          tertiarySeed: localUser.tertiarySeed,
          scaffoldOpacity: localUser.scaffoldOpacity,
          sidebarOpacity: localUser.sidebarOpacity,
          useUltraHighContrast: localUser.useUltraHighContrast,
          reduceMotion: localUser.reduceMotion,
        );

        toPut.id = localUser.id;
      }

      await _isarClient.writeTxn(() async {
        await _isarClient.allocateUsers.put(toPut);
      });

      _status = UserStatus.normal;

      notifyListeners();

      // Fetching from Supabase can result in this error.
      // This implies there is no online user, or there is a connection issue.
      // If a local user exists, send it to supabase.
      // Otherwise,
    } on UserSyncException catch (e, stacktrace) {
      log(e.cause, stackTrace: stacktrace);
      if (null != localUser) {
        return await updateUser(user: localUser);
      }
      _status = UserStatus.missing;
      notifyListeners();
    } on MultipleUsersException catch (e, stacktrace) {
      log(e.cause, stackTrace: stacktrace);
      _status = UserStatus.multiple;
      if (null != e.users) {
        _failureCache = e.users!;
        notifyListeners();
        return;
      }

      _failureCache = [onlineUser, localUser];
    } on UserMissingException catch (e, stacktrace) {
      log(e.cause, stackTrace: stacktrace);
      _status = UserStatus.missing;
      notifyListeners();
    }
  }

  Future<AllocateUser> fetchUser() async {
    // This should always only catch one user
    try {
      Map<String, dynamic>? userEntity =
          await _supabaseClient.from("allocateUsers").select().maybeSingle();
      if (null == userEntity) {
        throw Error();
      }

      return AllocateUser.fromEntity(entity: userEntity);
    } catch (error) {
      throw UserSyncException("Failed to retrieve user from DB\n"
          "Time: ${DateTime.now()}\n"
          "Supabase Open: $isConnected"
          "Session expired: ${_supabaseClient.auth.currentSession?.isExpired}");
    }
  }

  Future<void> handleUpsert(PostgresChangePayload payload) async {
    return await syncUser(
        onlineUser: AllocateUser.fromEntity(entity: payload.newRecord));
  }

  Future<void> handleDelete(PostgresChangePayload payload) async {
    int deleteID = payload.oldRecord["id"] as int;
    await _isarClient.writeTxn(() async {
      await _isarClient.allocateUsers.delete(deleteID);
    });
  }

  Future<void> deleteUser({required AllocateUser user}) async {
    if (!user.syncOnline || null == user.uuid) {
      await _isarClient.writeTxn(() async {
        await _isarClient.allocateUsers.delete(user.id);
      });
      return;
    }

    // If there is a connection, delete the user online.
    if (isConnected) {
      await _supabaseClient.auth.admin.deleteUser(user.uuid!);
      await _isarClient.writeTxn(() async {
        await _isarClient.allocateUsers.delete(user.id);
      });
      return;
    }

    // If there is not a connection, store for a retry.
    user.toDelete = true;
    user.syncOnline = true;
    await _isarClient.writeTxn(() async {
      await _isarClient.allocateUsers.put(user);
    });
  }

  // Grab any potentially un-deleted users and delete.
  Future<void> deleteSweep() async {
    if (!isConnected) {
      return;
    }

    List<AllocateUser> usersToDelete =
        await _isarClient.allocateUsers.where().toDeleteEqualTo(true).findAll();
    for (AllocateUser user in usersToDelete) {
      await deleteUser(user: user);
    }
  }

  Future<AllocateUser?> getUser() async {
    List<AllocateUser> users = await _isarClient.allocateUsers
        .where()
        .toDeleteEqualTo(false)
        .findAll();

    if (users.isEmpty) {
      return null;
    }

    // TODO: refactor this logic once multi-user implementation
    if (users.length > 1) {
      throw MultipleUsersException(
          "Multiple users in database.\n"
          "Users Length: ${users.length}",
          users: users);
    }

    return users.first;
  }

  UserStorageService._internal() {
    // I haven't faked the connection channels -> doesn't make sense to.
    if (SupabaseService.instance.debug) {
      return;
    }
    // Initialize table stream -> only listen on signIn.
    _userStream = _supabaseClient
        .channel("public:allocateUsers")
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: "public",
            table: "allocateUsers",
            callback: handleUpsert)
        .onPostgresChanges(
            schema: "public",
            table: "users",
            event: PostgresChangeEvent.update,
            callback: handleUpsert)
        .onPostgresChanges(
            schema: "public",
            table: "users",
            event: PostgresChangeEvent.delete,
            callback: handleDelete);

    // Listen to auth changes.
    SupabaseService.instance.authSubscription.listen((AuthState data) async {
      final AuthChangeEvent event = data.event;
      switch (event) {
        case AuthChangeEvent.signedIn:
          await syncUser();
          // OPEN TABLE STREAM -> insert new data.
          if (!_subscribed) {
            _userStream.subscribe();
            _subscribed = true;
          }
          break;
        case AuthChangeEvent.tokenRefreshed:
          // If not listening to the stream, there hasn't been an update.
          // Sync accordingly.
          if (!_subscribed) {
            await syncUser();
            _userStream.subscribe();
            _subscribed = true;
          }
          break;
        case AuthChangeEvent.signedOut:
          // CLOSE TABLE STREAM.
          await _userStream.unsubscribe();
          _subscribed = false;
          break;
        default:
          break;
      }
    });
  }
}
