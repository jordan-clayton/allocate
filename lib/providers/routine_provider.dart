import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import "../model/task/routine.dart";
import '../model/task/subtask.dart';
import '../model/user/user.dart';
import '../repositories/routine_repo.dart';
import '../repositories/subtask_repo.dart';
import '../util/constants.dart';
import '../util/enums.dart';
import "../util/exceptions.dart";
import '../util/interfaces/repository/model/routine_repository.dart';
import '../util/interfaces/repository/model/subtask_repository.dart';
import '../util/numbers.dart';
import '../util/sorting/routine_sorter.dart';

class RoutineProvider extends ChangeNotifier {
  bool _rebuild = true;

  bool get rebuild => _rebuild;

  set rebuild(bool rebuild) {
    _rebuild = rebuild;
    if (_rebuild) {
      routines = [];
      notifyListeners();
    }
  }

  set softRebuild(bool rebuild) {
    _rebuild = rebuild;

    if (_rebuild) {
      routines = [];
    }
  }

  late Timer syncTimer;

  late final RoutineRepository _routineRepo;
  late final SubtaskRepository _subtaskRepo;

  User? user;
  Routine? curRoutine;

  Routine? _curMorning;
  Routine? _curAfternoon;
  Routine? _curEvening;

  // For testing
  int? _morningID;
  int? _aftID;
  int? _eveID;

  final Map<int, ValueNotifier<int>> routineSubtaskCounts = {
    Constants.intMax: ValueNotifier<int>(0),
  };

  // CONSTRUCTOR
  RoutineProvider({
    this.user,
    RoutineRepository? routineRepository,
    SubtaskRepository? subtaskRepository,
  })  : sorter = user?.routineSorter ?? RoutineSorter(),
        _routineRepo = routineRepository ?? RoutineRepo.instance,
        _subtaskRepo = subtaskRepository ?? SubtaskRepo.instance {
    init();
  }

  Future<void> init() async {
    await setDailyRoutines();
  }

  Routine? get curMorning => _curMorning;

  Routine? get curAfternoon => _curAfternoon;

  Routine? get curEvening => _curEvening;

  set curMorning(Routine? newRoutine) {
    _curMorning = newRoutine;
    user?.curMornID = newRoutine?.id;
    // For testing
    _morningID = newRoutine?.id;
  }

  set curAfternoon(Routine? newRoutine) {
    _curAfternoon = newRoutine;
    user?.curAftID = newRoutine?.id;
    // For testing
    _aftID = newRoutine?.id;
  }

  set curEvening(Routine? newRoutine) {
    _curEvening = newRoutine;
    user?.curEveID = newRoutine?.id;
    // For testing
    _eveID = newRoutine?.id;
  }

  void clearRoutines() {
    curMorning = null;
    curAfternoon = null;
    curEvening = null;
  }

  void setDailyRoutine({required int timeOfDay, Routine? routine}) {
    if (null == routine) {
      return;
    }
    if (timeOfDay & 1 == 1) {
      curMorning = routine;
    }
    if (timeOfDay & 2 == 2) {
      curAfternoon = routine;
    }
    if (timeOfDay & 4 == 4) {
      curEvening = routine;
    }
    if (timeOfDay == 0) {
      unsetDailyRoutine(id: routine.id);
    }
    notifyListeners();
  }

  void unsetDailyRoutine({required int id}) {
    if (id == curMorning?.id) {
      curMorning = null;
    }
    if (id == curAfternoon?.id) {
      curAfternoon = null;
    }
    if (id == curEvening?.id) {
      curEvening = null;
    }
  }

  int get routineWeight =>
      (curMorning?.weight ?? 0) +
      (curAfternoon?.weight ?? 0) +
      (curEvening?.weight ?? 0);

  List<Routine> routines = [];

  late RoutineSorter sorter;

  void setUser({User? newUser}) {
    user = newUser;
    sorter = user?.routineSorter ?? sorter;
    notifyListeners();
  }

  int getRoutineTime({Routine? routine}) {
    int times = 0;
    if (_curMorning == routine) {
      times |= 1;
    }
    if (_curAfternoon == routine) {
      times |= 2;
    }
    if (_curEvening == routine) {
      times |= 4;
    }
    return times;
  }

  Future<void> setDailyRoutines() async {
    curMorning = (null != user?.curMornID!)
        ? await _routineRepo.getByID(id: user!.curMornID!)
        : null;

    curAfternoon = (null != user?.curAftID!)
        ? await _routineRepo.getByID(id: user!.curAftID!)
        : null;

    curEvening = (null != user?.curAftID!)
        ? await _routineRepo.getByID(id: user!.curAftID!)
        : null;
    notifyListeners();
  }

  SortMethod get sortMethod => sorter.sortMethod;

  set sortMethod(SortMethod method) {
    if (method == sorter.sortMethod) {
      sorter.descending = !sorter.descending;
    } else {
      sorter.sortMethod = method;
      sorter.descending = false;
    }
    user?.routineSorter = sorter;
    notifyListeners();
  }

  bool get descending => sorter.descending;

  List<SortMethod> get sortMethods => sorter.sortMethods;

  int calculateRealDuration({int? weight, int? duration}) => (remap(
              x: weight ?? 0,
              inMin: 0,
              inMax: Constants.medianWeight,
              outMin: Constants.lowerBound,
              outMax: Constants.upperBound) *
          (duration ?? 0))
      .toInt();

  Future<int> getWeight(
          {required int taskID, int limit = Constants.maxNumTasks}) async =>
      await _subtaskRepo.getTaskSubtaskWeight(taskID: taskID, limit: limit);

  ValueNotifier<int> getSubtaskCount(
      {required int id, int limit = Constants.maxNumTasks}) {
    if (routineSubtaskCounts.containsKey(id)) {
      return routineSubtaskCounts[id]!;
    }

    routineSubtaskCounts[id] = ValueNotifier<int>(0);
    setSubtaskCount(id: id, limit: limit);
    return routineSubtaskCounts[id]!;
  }

  Future<void> setSubtaskCount(
      {required int id, int limit = Constants.maxNumTasks, int? count}) async {
    count = count ??
        await _subtaskRepo.getTaskSubtasksCount(taskID: id, limit: limit);
    if (routineSubtaskCounts.containsKey(id)) {
      routineSubtaskCounts[id]?.value = count;
    } else {
      routineSubtaskCounts[id] = ValueNotifier<int>(count);
    }
  }

  // Refactor this please - RoutineModel.
  Future<void> createRoutine({
    required String name,
    int? expectedDuration,
    int? realDuration,
    int? weight,
    int? times,
    List<Subtask>? subtasks,
  }) async {
    times = times ?? 0;
    subtasks =
        subtasks ?? await _subtaskRepo.getRepoByTaskID(id: Constants.intMax);
    weight = weight ?? await getWeight(taskID: Constants.intMax);
    expectedDuration = expectedDuration ?? (const Duration(hours: 1)).inSeconds;
    realDuration = realDuration ??
        calculateRealDuration(weight: weight, duration: expectedDuration);

    curRoutine = Routine(
        name: name,
        weight: weight,
        expectedDuration: expectedDuration,
        realDuration: realDuration,
        subtasks: subtasks,
        lastUpdated: DateTime.now());

    try {
      curRoutine = await _routineRepo.create(curRoutine!);
      await _updateSubtasks(subtasks: subtasks, taskID: curRoutine!.id);
    } on FailureToCreateException catch (e) {
      log(e.cause);
      return Future.error(e);
    } on FailureToUploadException catch (e) {
      log(e.cause);
      curRoutine!.isSynced = false;
      return updateRoutine();
    }

    routineSubtaskCounts[Constants.intMax]!.value = 0;
    setDailyRoutine(timeOfDay: times, routine: curRoutine);
    notifyListeners();
  }

  Future<void> updateRoutine({Routine? routine, int? times}) async {
    routine = routine ?? curRoutine;
    await updateRoutineAsync(routine: routine);
    if (null != times) {
      unsetDailyRoutine(id: routine!.id);
      setDailyRoutine(timeOfDay: times, routine: routine);
    }
    notifyListeners();
  }

  Future<void> updateRoutineAsync({Routine? routine}) async {
    routine = routine ?? curRoutine!;
    routine.lastUpdated = DateTime.now();

    try {
      curRoutine = await _routineRepo.update(routine);
    } on FailureToUploadException catch (e) {
      log(e.cause);
      return Future.error(e);
    } on FailureToUpdateException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
  }

  Future<void> updateBatch({List<Routine>? routines}) async {
    routines = routines ?? this.routines;
    for (Routine routine in routines) {
      routine.lastUpdated = DateTime.now();
    }
    try {
      await _routineRepo.updateBatch(routines);
    } on FailureToUploadException catch (e) {
      log(e.cause);
      return Future.error(e);
    } on FailureToUpdateException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
    notifyListeners();
  }

  Future<void> _updateSubtasks(
      {required List<Subtask> subtasks, required int taskID}) async {
    int i = 0;

    // This eliminates empty subtasks.
    for (Subtask st in subtasks) {
      if (st.name != "") {
        st.taskID = taskID;
        st.customViewIndex = i++;
        st.lastUpdated = DateTime.now();
      } else {
        st.toDelete = true;
      }
    }
    try {
      await _subtaskRepo.updateBatch(subtasks);
    } on FailureToUploadException catch (e) {
      log(e.cause);
      return Future.error(e);
    } on FailureToUpdateException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
  }

  Future<void> deleteRoutine({Routine? routine}) async {
    if (null == routine) {
      return;
    }
    try {
      await _routineRepo.delete(routine);
    } on FailureToDeleteException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
    notifyListeners();
  }

  Future<void> removeRoutine({Routine? routine}) async {
    if (null == routine) {
      return;
    }
    try {
      await _routineRepo.remove(routine);
    } on FailureToDeleteException catch (e) {
      log(e.cause);
      return Future.error(e);
    }

    notifyListeners();
  }

  Future<void> restoreRoutine({Routine? routine}) async {
    if (null == routine) {
      return;
    }
    routine.toDelete = false;
    try {
      curRoutine = await _routineRepo.update(routine);
    } on FailureToUploadException catch (e) {
      log(e.cause);
      return Future.error(e);
    } on FailureToUpdateException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
    notifyListeners();
  }

  Future<void> emptyTrash() async {
    try {
      List<int> ids = await _routineRepo.emptyTrash();
      for (int id in ids) {
        List<Subtask> subtasks = await _subtaskRepo.getRepoByTaskID(id: id);
        for (Subtask subtask in subtasks) {
          subtask.toDelete = true;
        }
        await _subtaskRepo.updateBatch(subtasks);
        routineSubtaskCounts.remove(id);
      }
    } on FailureToDeleteException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
    notifyListeners();
  }

  Future<List<Routine>> reorderRoutines(
      {List<Routine>? routines,
      required int oldIndex,
      required int newIndex}) async {
    routines = routines ?? this.routines;
    if (oldIndex < newIndex) {
      newIndex--;
    }
    Routine routine = routines.removeAt(oldIndex);
    routines.insert(newIndex, routine);
    for (int i = 0; i < routines.length; i++) {
      routines[i].customViewIndex = i;
    }
    try {
      await _routineRepo.updateBatch(routines);
      return routines;
    } on FailureToUpdateException catch (e) {
      log(e.cause);
      return Future.error(e);
    } on FailureToUploadException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
  }

  Future<void> resetRoutineSubtasks({Routine? routine}) async {
    if (null == routine) {
      return;
    }
    List<Subtask> subtasks = await _subtaskRepo.getRepoByTaskID(id: routine.id);
    for (Subtask subtask in subtasks) {
      subtask.completed = false;
    }
    try {
      await _subtaskRepo.updateBatch(subtasks);
    } on FailureToUpdateException catch (e) {
      log(e.cause);
      return Future.error(e);
    } on FailureToUploadException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
  }

  // This is to be called once per day after midnight;
  Future<void> resetDailyRoutines() async {
    if (null != curMorning) {
      resetRoutineSubtasks(routine: curMorning);
    }
    if (null != curAfternoon) {
      resetRoutineSubtasks(routine: curAfternoon);
    }
    if (null != curEvening) {
      resetRoutineSubtasks(routine: curEvening);
    }
    notifyListeners();
  }

  Future<List<Routine>> getRoutines({int limit = 50, int offset = 0}) async =>
      await _routineRepo.getRepoList(limit: limit, offset: offset);

  Future<List<Subtask>> getSubtasks({
    required int id,
    int limit = Constants.maxNumTasks,
  }) async =>
      await _subtaskRepo.getRepoByTaskID(id: id, limit: limit);

  // Future<void> setRoutineList({int limit = 50, int offset = 0}) async =>
  //     await _routineRepo.getRepoList(limit: limit, offset: offset);

  Future<List<Routine>> getRoutinesBy({int limit = 50, int offset = 0}) async =>
      await _routineRepo.getRepoListBy(
          sorter: sorter, limit: limit, offset: offset);

  Future<List<Routine>> getDeleted(
          {int limit = Constants.minLimitPerQuery, int offset = 0}) async =>
      await _routineRepo.getDeleted(limit: limit, offset: offset);

  // Future<void> setRoutineListBy({int limit = 50, int offset = 0}) async =>
  //     await _routineRepo.getRepoListBy(
  //         sorter: sorter, limit: limit, offset: offset);

  Future<List<Routine>> searchRoutines(
          {required String searchString, bool toDelete = false}) async =>
      await _routineRepo.search(searchString: searchString, toDelete: toDelete);

  Future<List<Routine>> mostRecent({int limit = 5}) async =>
      await _routineRepo.mostRecent(limit: 5);

  Future<Routine?> getRoutineByID({int? id}) async {
    if (null == id) {
      return null;
    }
    return await _routineRepo.getByID(id: id);
  }

// Future<void> setRoutineByID({required int id}) async =>
//     curRoutine = await _routineRepo.getByID(id: id) ??
//         Routine(
//             name: '',
//             expectedDuration: 0,
//             realDuration: 0,
//             subtasks: List.filled(
//                 Constants.maxNumTasks, Subtask(lastUpdated: DateTime.now())),
//             lastUpdated: DateTime.now());
}
