import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/task/group.dart';
import '../model/task/todo.dart';
import '../services/isar_service.dart';
import '../services/supabase_service.dart';
import '../util/constants.dart';
import '../util/enums.dart';
import '../util/exceptions.dart';
import '../util/interfaces/repository/model/group_repository.dart';
import '../util/interfaces/sortable.dart';

class GroupRepo extends ChangeNotifier implements GroupRepository {
  static final GroupRepo _instance = GroupRepo._internal();

  static GroupRepo get instance => _instance;

  late final SupabaseClient _supabaseClient;
  late final RealtimeChannel _groupStream;

  late final Isar _isarClient;

  bool get isConnected =>
      SupabaseService.instance.isConnected &&
      IsarService.instance.dbSize.value < Constants.supabaseLimit;

  bool get dbFull => IsarService.instance.dbSize.value >= Constants.isarLimit;

  int _groupCount = 0;
  bool _subscribed = false;
  bool _initialized = false;

  bool _needsRefreshing = true;
  bool _syncing = false;
  bool _refreshing = false;

  String? currentUserID;

  // In the case of an unhandled exception during the refresh/sync functions, the flags do not get reset properly.
  // TODO: Refactor Sync/Refresh logic to catch update exceptions.
  // This is meant to be called on a manual-refresh activated by the user in the UI
  @override
  void forceRefreshState() {
    _needsRefreshing = true;
    _syncing = false;
    _refreshing = false;
  }

  @override
  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _isarClient = IsarService.instance.isarClient;
    _supabaseClient = SupabaseService.instance.supabaseClient;
    _initialized = true;
    // I haven't faked the connection channels -> doesn't make sense to.
    if (SupabaseService.instance.offlineOnly) {
      return;
    }
    // Initialize table stream -> only listen on signIn.
    _groupStream = _supabaseClient
        .channel("public:groups")
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: "public",
            table: "groups",
            callback: handleUpsert)
        .onPostgresChanges(
            schema: "public",
            table: "groups",
            event: PostgresChangeEvent.update,
            callback: handleUpsert)
        .onPostgresChanges(
            schema: "public",
            table: "groups",
            event: PostgresChangeEvent.delete,
            callback: handleDelete);

    await handleUserChange();

    if (!_subscribed) {
      _groupStream.subscribe();
      _subscribed = true;
    }

    // Listen to auth changes.
    SupabaseService.instance.authSubscription.listen((AuthState data) async {
      final AuthChangeEvent event = data.event;
      switch (event) {
        case AuthChangeEvent.signedIn:
          await handleUserChange();
          // This should close and re-open the subscription?
          if (!_subscribed) {
            _groupStream.subscribe();
            _subscribed = true;
          }
          break;
        case AuthChangeEvent.tokenRefreshed:
          if (!_subscribed) {
            await handleUserChange();
            _groupStream.subscribe();
            _subscribed = true;
          }
          break;
        case AuthChangeEvent.signedOut:
          // await _groupStream.unsubscribe();
          // _subscribed = false;
          break;
        default:
          break;
      }
    });

    // This is for online stuff.
    SupabaseService.instance.connectionSubscription
        .listen((List<ConnectivityResult> results) async {
      _needsRefreshing = true;
      if (results.last == ConnectivityResult.none) {
        return;
      }

      // This is to give enough time for the internet to check.
      await Future.delayed(const Duration(seconds: 2));
      if (!isConnected) {
        return;
      }
      forceRefreshState();
      await refreshRepo();
    });

    // This is for watching db size.
    _isarClient.groups.watchLazy().listen((_) async {
      await IsarService.instance.updateDBSize();
    });
  }

  Future<void> handleUserChange() async {
    String? newID = _supabaseClient.auth.currentUser?.id;

    if (newID == currentUserID) {
      if (_needsRefreshing) {
        await refreshRepo();
        _needsRefreshing = false;
        return;
      }
      return await syncRepo();
    }

    // In the case that the previous currentUserID was null.
    // This implies a new login, or a fresh open.
    // if not online, this will just early return.
    if (null == currentUserID) {
      currentUserID = newID;
      if (_needsRefreshing) {
        await refreshRepo();
        _needsRefreshing = false;
        return;
      }
      return await syncRepo();
    }

    // This implies there is a new user -> clear the DB
    // and insert the new user.
    currentUserID = newID;
    return await swapRepo();
  }

  @override
  Future<Group> create(Group group) async {
    if (dbFull) {
      throw LocalLimitExceededException(
          "Database is full. Size: ${IsarService.instance.dbSize.value / 1000000}");
    }
    group.isSynced = isConnected;
    late int? id;

    await _isarClient.writeTxn(() async {
      id = await _isarClient.groups.put(group);
    });

    if (null == id) {
      throw FailureToCreateException("Failed to create group locally\n"
          "Group: ${group.toString()}\n"
          "Time: ${DateTime.now()}\n"
          "Isar Open: ${_isarClient.isOpen}");
    }

    if (isConnected) {
      Map<String, dynamic> groupEntity = group.toEntity();
      groupEntity["uuid"] = _supabaseClient.auth.currentUser!.id;
      final List<Map<String, dynamic>> response =
          await _supabaseClient.from("groups").insert(groupEntity).select("id");
      id = response.last["id"];
      if (null == id) {
        throw FailureToUploadException("Failed to sync group on create");
      }
    }
    return group;
  }

  @override
  Future<Group> update(Group group) async {
    group.isSynced = isConnected;

    late int? id;
    await _isarClient.writeTxn(() async {
      id = await _isarClient.groups.put(group);
    });

    if (null == id) {
      throw FailureToUpdateException("Failed to update group locally\n"
          "Group: ${group.toString()}\n"
          "Time: ${DateTime.now()}\n"
          "Isar Open: ${_isarClient.isOpen}");
    }

    if (isConnected) {
      Map<String, dynamic> groupEntity = group.toEntity();
      groupEntity["uuid"] = _supabaseClient.auth.currentUser!.id;
      final List<Map<String, dynamic>> response =
          await _supabaseClient.from("groups").upsert(groupEntity).select("id");

      id = response.last["id"];

      if (null == id) {
        throw FailureToUploadException("Failed to sync group on update\n"
            "Group: ${group.toString()}\n"
            "Time: ${DateTime.now()}\n\n"
            "Supabase Open: $isConnected"
            "Session expired: ${_supabaseClient.auth.currentSession?.isExpired}");
      }
    }
    return group;
  }

  @override
  Future<void> updateBatch(List<Group> groups) async {
    late List<int?> ids;
    late int? id;
    await _isarClient.writeTxn(() async {
      ids = List<int?>.empty(growable: true);
      for (Group group in groups) {
        group.isSynced = isConnected;
        id = await _isarClient.groups.put(group);
        ids.add(id);
      }
    });
    if (ids.any((id) => null == id)) {
      throw FailureToUpdateException("Failed to update groups locally\n"
          "Groups: ${groups.toString()}\n"
          "Time: ${DateTime.now()}\n"
          "Isar Open: ${_isarClient.isOpen}");
    }

    if (isConnected) {
      ids.clear();
      List<Map<String, dynamic>> groupEntities = groups.map((group) {
        Map<String, dynamic> entity = group.toEntity();
        entity["uuid"] = _supabaseClient.auth.currentUser!.id;
        return entity;
      }).toList();
      for (Map<String, dynamic> groupEntity in groupEntities) {
        final List<Map<String, dynamic>> response = await _supabaseClient
            .from("groups")
            .update(groupEntity)
            .select("id");
        id = response.last["id"];
        ids.add(id);
      }
      if (ids.any((id) => null == id)) {
        throw FailureToUploadException("Failed to sync groups on update\n"
            "Groups: ${groups.toString()}\n"
            "Time: ${DateTime.now()}\n\n"
            "Supabase Open: $isConnected"
            "Session expired: ${_supabaseClient.auth.currentSession?.isExpired}");
      }
    }
  }

  @override
  Future<void> delete(Group group) async {
    group.toDelete = true;
    await update(group);
  }

  @override
  Future<void> remove(Group group) async {
    // Delete online
    if (isConnected) {
      try {
        await _supabaseClient.from("groups").delete().eq("id", group.id);
      } catch (error) {
        throw FailureToDeleteException("Failed to delete Group online\n"
            "Group: ${group.toString()}\n"
            "Time: ${DateTime.now()}\n"
            "Supabase Open: $isConnected"
            "Session expired: ${_supabaseClient.auth.currentSession?.isExpired}");
      }
    }
    // Delete local
    await _isarClient.writeTxn(() async {
      await _isarClient.groups.delete(group.id);
    });
  }

  @override
  Future<List<int>> emptyTrash() async {
    if (isConnected) {
      try {
        await _supabaseClient.from("groups").delete().eq("toDelete", true);
      } catch (error) {
        throw FailureToDeleteException("Failed to empty trash online\n"
            "Time: ${DateTime.now()}\n"
            "Supabase Open: $isConnected"
            "Session expired: ${_supabaseClient.auth.currentSession?.isExpired}");
      }
    }
    late List<int> deleteIDs;
    await _isarClient.writeTxn(() async {
      deleteIDs = await _isarClient.groups
          .where()
          .toDeleteEqualTo(true)
          .idProperty()
          .findAll();
      await _isarClient.groups.deleteAll(deleteIDs);
    });
    return deleteIDs;
  }

  @override
  Future<void> clearDB() async {
    if (isConnected) {
      // not sure whether or not to catch errors.
      await _supabaseClient.from("groups").delete().neq("customViewIndex", -2);
    }

    await _isarClient.writeTxn(() async {
      await _isarClient.groups.clear();
    });
  }

  Future<void> clearLocal() async {
    await _isarClient.writeTxn(() async {
      await _isarClient.groups.clear();
    });
  }

  @override
  Future<void> deleteSweep({DateTime? upTo}) async {
    List<int> toDeletes = await getDeleteIDs(deleteLimit: upTo);
    // For local update
    List<ToDo> toDos = List.empty(growable: true);
    // For online update
    List<Map<String, dynamic>> entities = List.empty(growable: true);
    for (int id in toDeletes) {
      List<ToDo> groupToDos =
          await _isarClient.toDos.where().groupIDEqualTo(id).findAll();
      for (ToDo toDo in groupToDos) {
        toDo.groupID = null;
        toDo.groupIndex = -1;
        toDos.add(toDo);
        Map<String, dynamic> entity = toDo.toEntity();
        entity["uuid"] = _supabaseClient.auth.currentUser!.id;
        entities.add(entity);
      }
    }

    if (isConnected) {
      try {
        await _supabaseClient.from("groups").delete().inFilter("id", toDeletes);
        await _supabaseClient.from("toDos").upsert(entities);
      } catch (error) {
        throw FailureToDeleteException("Failed to delete groups online \n"
            "Time: ${DateTime.now()}\n"
            "Supabase Open: $isConnected"
            "Session expired: ${_supabaseClient.auth.currentSession?.isExpired}");
      }
    }
    await _isarClient.writeTxn(() async {
      await _isarClient.groups.deleteAll(toDeletes);
      for (ToDo toDo in toDos) {
        await _isarClient.toDos.put(toDo);
      }
    });
  }

  Future<int> getOnlineCount() async =>
      _supabaseClient.from("groups").count(CountOption.exact);

  @override
  Future<void> refreshRepo() async {
    if (!isConnected) {
      _refreshing = false;
      _syncing = false;
      return;
    }

    if (_refreshing) {
      return;
    }

    _refreshing = true;
    _syncing = true;

    // Get the set of unsynced data.
    Set<Group> unsynced = await getUnsynced().then((_) => _.toSet());

    // Get the online count.
    _groupCount = await getOnlineCount();

    // Fetch new data -> by fetchRepo();
    List<Group> onlineGroups = await fetchRepo();

    List<Group> toInsert = List.empty(growable: true);
    for (Group onlineGroup in onlineGroups) {
      Group? localGroup = unsynced.lookup(onlineGroup);
      // Prioritize by last updated -> unsynced data will overwrite new data
      // during the batch update.
      if (null != localGroup &&
          onlineGroup.lastUpdated.isAfter(localGroup.lastUpdated)) {
        unsynced.remove(localGroup);
      }
      toInsert.add(onlineGroup);
    }

    // Clear the DB, then add all new data.
    // Unsynced data will be updated once remaining data has been collected.
    await clearLocal();

    await _isarClient.writeTxn(() async {
      await _isarClient.groups.putAll(toInsert);
    });

    insertRemaining(totalFetched: onlineGroups.length, unsynced: unsynced);
    notifyListeners();
  }

  // This doesn't currently throw exceptions, as these are technically less critical.
  // Most function happens offline.
  @override
  Future<void> syncRepo() async {
    if (!isConnected) {
      _syncing = false;
      return;
    }

    if (_syncing || _refreshing) {
      return;
    }

    _syncing = true;

    // Get the set of unsynced data.
    Set<Group> unsynced = await getUnsynced().then((_) => _.toSet());

    // Get the online count.
    _groupCount = await getOnlineCount();

    // Fetch new data -> by fetchRepo();
    List<Group> onlineGroups = await fetchRepo();

    List<Group> toInsert = List.empty(growable: true);
    for (Group onlineGroup in onlineGroups) {
      Group? localGroup = unsynced.lookup(onlineGroup);
      // Prioritize by last updated -> unsynced data will overwrite new data
      // during the batch update.
      if (null != localGroup &&
          onlineGroup.lastUpdated.isAfter(localGroup.lastUpdated)) {
        unsynced.remove(localGroup);
      }
      toInsert.add(onlineGroup);
    }

    // Put all new data in the db.
    await _isarClient.writeTxn(() async {
      await _isarClient.groups.putAll(toInsert);
    });

    insertRemaining(totalFetched: onlineGroups.length, unsynced: unsynced);

    notifyListeners();
  }

  Future<void> insertRemaining(
      {required int totalFetched, Set<Group>? unsynced}) async {
    unsynced = unsynced ?? Set.identity();

    List<Group> toInsert = List.empty(growable: true);
    while (totalFetched < _groupCount) {
      List<Group>? onlineGroups = await fetchRepo(offset: totalFetched);

      // If there is no data or connection is lost, break.
      if (onlineGroups.isEmpty) {
        break;
      }
      for (Group onlineGroup in onlineGroups) {
        Group? localGroup = unsynced.lookup(onlineGroup);
        // Prioritize by last updated -> unsynced data will overwrite new data
        // during the batch update.
        if (null != localGroup &&
            onlineGroup.lastUpdated.isAfter(localGroup.lastUpdated)) {
          unsynced.remove(localGroup);
        }
        toInsert.add(onlineGroup);
      }
      totalFetched += onlineGroups.length;
    }

    await _isarClient.writeTxn(() async {
      await _isarClient.groups.putAll(toInsert);
    });

    await updateBatch(unsynced.toList());
    _syncing = false;
    _refreshing = false;
    notifyListeners();
  }

  @override
  Future<List<Group>> fetchRepo({int limit = 1000, int offset = 0}) async {
    List<Group> data = List.empty(growable: true);
    if (!isConnected) {
      return data;
    }
    try {
      List<Map<String, dynamic>> groupEntities = await _supabaseClient
          .from("groups")
          .select()
          .eq("uuid", _supabaseClient.auth.currentUser!.id)
          .order("lastUpdated", ascending: false)
          .range(offset, offset + limit);

      for (Map<String, dynamic> entity in groupEntities) {
        data.add(Group.fromEntity(entity: entity));
      }
    } on Error catch (e, stacktrace) {
      log(e.toString(), stackTrace: stacktrace);
    }
    return data;
  }

  Future<void> swapRepo() async {
    await clearLocal();
    await refreshRepo();
  }

  Future<void> handleUpsert(PostgresChangePayload payload) async {
    Group group = Group.fromEntity(entity: payload.newRecord);
    group.lastUpdated = DateTime.now();
    await _isarClient.writeTxn(() async {
      await _isarClient.groups.put(group);
    });

    _groupCount = await getOnlineCount();
    notifyListeners();
  }

  Future<void> handleDelete(PostgresChangePayload payload) async {
    int deleteID = payload.oldRecord["id"] as int;
    await _isarClient.writeTxn(() async {
      await _isarClient.groups.delete(deleteID);
    });

    _groupCount = await getOnlineCount();
    notifyListeners();
  }

  @override
  Future<List<Group>> search(
          {required String searchString, bool toDelete = false}) async =>
      await _isarClient.groups
          .where()
          .toDeleteEqualTo(toDelete)
          .filter()
          .nameContains(searchString, caseSensitive: false)
          .limit(5)
          .findAll();

  @override
  Future<List<Group>> mostRecent({int limit = 50}) async =>
      await _isarClient.groups
          .where()
          .toDeleteEqualTo(false)
          .sortByLastUpdatedDesc()
          .limit(limit)
          .findAll();

  @override
  Future<Group?> getByID({required int id}) async => await _isarClient.groups
      .where()
      .idEqualTo(id)
      .filter()
      .toDeleteEqualTo(false)
      .findFirst();

  @override
  Future<bool> containsID({required int id}) async {
    List<Group> duplicates =
        await _isarClient.groups.where().idEqualTo(id).findAll();
    return duplicates.isNotEmpty;
  }

  // Basic query logic.
  @override
  Future<List<Group>> getRepoList({int limit = 50, int offset = 0}) async =>
      await _isarClient.groups
          .where()
          .toDeleteEqualTo(false)
          .sortByCustomViewIndex()
          .thenByLastUpdatedDesc()
          .offset(offset)
          .limit(limit)
          .findAll();

  @override
  Future<List<Group>> getRepoListBy(
      {required SortableView<Group> sorter,
      int limit = 50,
      int offset = 0}) async {
    switch (sorter.sortMethod) {
      case SortMethod.name:
        if (sorter.descending) {
          return await _isarClient.groups
              .where()
              .toDeleteEqualTo(false)
              .sortByNameDesc()
              .thenByLastUpdatedDesc()
              .offset(offset)
              .limit(limit)
              .findAll();
        } else {
          return await _isarClient.groups
              .where()
              .toDeleteEqualTo(false)
              .sortByName()
              .thenByLastUpdatedDesc()
              .offset(offset)
              .limit(limit)
              .findAll();
        }
      default:
        return getRepoList(limit: limit, offset: offset);
    }
  }

  @override
  Future<List<Group>> getDeleted({int limit = 50, int offset = 0}) async =>
      await _isarClient.groups
          .where()
          .toDeleteEqualTo(true)
          .sortByLastUpdatedDesc()
          .offset(offset)
          .limit(limit)
          .findAll();

  Future<List<int>> getDeleteIDs({DateTime? deleteLimit}) async {
    deleteLimit = deleteLimit ?? Constants.today;
    return await _isarClient.groups
        .where()
        .toDeleteEqualTo(true)
        .filter()
        .lastUpdatedLessThan(deleteLimit)
        .idProperty()
        .findAll();
  }

  Future<List<Group>> getUnsynced() async =>
      await _isarClient.groups.filter().isSyncedEqualTo(false).findAll();

  GroupRepo._internal();
}
