import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:jiffy/jiffy.dart';

import '../model/task/deadline.dart';
import '../model/user/user.dart';
import '../repositories/deadline_repo.dart';
import '../services/notification_service.dart';
import '../services/repeatable_service.dart';
import '../util/constants.dart';
import '../util/enums.dart';
import '../util/exceptions.dart';
import '../util/interfaces/repository/model/deadline_repository.dart';
import '../util/sorting/deadline_sorter.dart';

class DeadlineProvider extends ChangeNotifier {
  bool _rebuild = true;

  bool get rebuild => _rebuild;

  set rebuild(bool rebuild) {
    _rebuild = rebuild;
    if (_rebuild) {
      deadlines = [];
      secondaryDeadlines = [];
      notifyListeners();
    }
  }

  set softRebuild(bool rebuild) {
    _rebuild = rebuild;
    if (_rebuild) {
      deadlines = [];
      secondaryDeadlines = [];
    }
  }

  late Timer syncTimer;

  final DeadlineRepository _deadlineRepo;
  final RepeatableService _repeatService;

  final NotificationService _notificationService = NotificationService.instance;

  Deadline? curDeadline;

  List<Deadline> deadlines = [];
  List<Deadline> secondaryDeadlines = [];

  late DeadlineSorter sorter;

  User? user;

  DeadlineProvider(
      {this.user,
      DeadlineRepository? deadlineRepo,
      RepeatableService? repeatableService})
      : _deadlineRepo = deadlineRepo ?? DeadlineRepo.instance,
        _repeatService = repeatableService ?? RepeatableService.instance,
        sorter = user?.deadlineSorter ?? DeadlineSorter();

  void setUser({User? newUser}) {
    user = newUser;
    sorter = user?.deadlineSorter ?? sorter;
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
    user?.deadlineSorter = sorter;
    notifyListeners();
  }

  bool get descending => sorter.descending;

  List<SortMethod> get sortMethods => sorter.sortMethods;

  Future<void> createDeadline({
    required String name,
    String description = "",
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? warnDate,
    bool warnMe = false,
    Priority priority = Priority.low,
    bool? repeatable,
    Frequency? frequency,
    List<bool>? repeatDays,
    int? repeatSkip,
  }) async {
    if (null != startDate) {
      startDate = startDate.copyWith(second: 0, millisecond: 0, microsecond: 0);
    }
    if (null != dueDate) {
      dueDate = dueDate.copyWith(second: 0, microsecond: 0, millisecond: 0);
    }
    if (null != startDate && null != dueDate && startDate.isAfter(dueDate)) {
      dueDate = startDate.copyWith(
          day: dueDate.day + 1,
          hour: Constants.midnight.hour,
          minute: Constants.midnight.minute);
    }

    warnDate = warnDate?.copyWith(second: 0, millisecond: 0, microsecond: 0) ??
        dueDate;

    if (null != startDate && null != warnDate && startDate.isAfter(warnDate)) {
      warnDate = startDate.copyWith(minute: startDate.minute + 15);
    }

    curDeadline = Deadline(
        name: name,
        description: description,
        originalStart: startDate,
        startDate: startDate,
        dueDate: dueDate,
        originalDue: dueDate,
        originalWarn: warnDate,
        warnMe: warnMe,
        warnDate: warnDate,
        priority: priority,
        repeatable: repeatable ?? false,
        frequency: frequency ?? Frequency.once,
        repeatDays: repeatDays ?? List.filled(7, false),
        repeatSkip: repeatSkip ?? 1,
        lastUpdated: DateTime.now());

    curDeadline!.repeatID = Constants.generateID();
    curDeadline!.notificationID = Constants.generate32ID();
    try {
      curDeadline = await _deadlineRepo.create(curDeadline!);
      if (curDeadline!.repeatable) {
        await createTemplate(deadline: curDeadline!);
      }

      if (curDeadline!.warnMe &&
          validateWarnDate(warnDate: curDeadline!.warnDate)) {
        await scheduleNotification(deadline: curDeadline);
      }
    } on FailureToCreateException catch (e) {
      log(e.cause);
      await cancelNotification();
      return Future.error(e);
    } on FailureToUploadException catch (e) {
      log(e.cause);
      curDeadline!.isSynced = false;
      return await updateDeadline();
    }
    notifyListeners();
  }

  Future<void> updateDeadline({Deadline? deadline}) async {
    await updateDeadlineAsync(deadline: deadline);
    notifyListeners();
  }

  Future<void> updateDeadlineAsync({Deadline? deadline}) async {
    deadline = deadline ?? curDeadline!;
    deadline.lastUpdated = DateTime.now();
    if (deadline.warnMe && null == deadline.notificationID) {
      deadline.notificationID = Constants.generate32ID();
    }
    if (deadline.repeatable && null == deadline.repeatID) {
      deadline.repeatID = Constants.generateID();
    }

    try {
      curDeadline = await _deadlineRepo.update(curDeadline!);
      if (curDeadline!.repeatable) {
        Deadline? template =
            await _deadlineRepo.getTemplate(repeatID: curDeadline!.repeatID!);
        if (null == template) {
          curDeadline!.originalStart = curDeadline!.startDate;
          curDeadline!.originalDue = curDeadline!.dueDate;
          curDeadline!.originalWarn = curDeadline!.warnDate;
          await createTemplate(deadline: curDeadline!);
        }
      }
      await cancelNotification(deadline: curDeadline);
      if (deadline.warnMe &&
          validateWarnDate(warnDate: curDeadline!.warnDate)) {
        await scheduleNotification(deadline: deadline);
      }
    } on FailureToUploadException catch (e) {
      log(e.cause);
      return Future.error(e);
    } on FailureToUpdateException catch (e) {
      log(e.cause);
      await cancelNotification();
      return Future.error(e);
    }
  }

  Future<void> deleteDeadline({Deadline? deadline}) async {
    deadline = deadline ?? curDeadline!;
    await cancelNotification(deadline: deadline);
    try {
      await _deadlineRepo.delete(deadline);
    } on FailureToDeleteException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
    notifyListeners();
  }

  Future<void> removeDeadline({Deadline? deadline}) async {
    if (null == deadline) {
      return;
    }
    try {
      await _deadlineRepo.remove(deadline);
    } on FailureToDeleteException catch (e) {
      log(e.cause);
      return Future.error(e);
    }

    notifyListeners();
  }

  Future<void> restoreDeadline({Deadline? deadline}) async {
    if (null == deadline) {
      return;
    }
    deadline.repeatable = false;
    deadline.frequency = Frequency.once;
    deadline.toDelete = false;
    try {
      curDeadline = await _deadlineRepo.update(deadline);
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
      List<int> ids = await _deadlineRepo.emptyTrash();
      await _notificationService.cancelMultiple(ids: ids);
    } on FailureToDeleteException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
    notifyListeners();
  }

  Future<List<Deadline>> reorderDeadlines(
      {List<Deadline>? deadlines,
      required int oldIndex,
      required int newIndex}) async {
    if (oldIndex < newIndex) {
      newIndex--;
    }
    deadlines = deadlines ?? this.deadlines;
    Deadline deadline = deadlines.removeAt(oldIndex);
    deadlines.insert(newIndex, deadline);
    for (int i = 0; i < deadlines.length; i++) {
      deadlines[i].customViewIndex = i;
    }
    try {
      await _deadlineRepo.updateBatch(deadlines);
      return deadlines;
    } on FailureToUpdateException catch (e) {
      log(e.cause);
      return Future.error(e);
    } on FailureToUploadException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
  }

  Future<void> nextRepeat({Deadline? deadline}) async {
    try {
      await _repeatService.nextRepeat(model: deadline ?? curDeadline!);
    } on FailureToUpdateException catch (e) {
      log(e.cause);
      return Future.error(e);
    } on FailureToUploadException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
  }

  Future<void> handleRepeating(
      {Deadline? deadline, bool? single = false, bool delete = false}) async {
    try {
      return await _repeatService.handleRepeating(
          model: deadline, single: single, delete: delete);

      //TODO: Clear key -> run repeat routine.
    } on InvalidRepeatingException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
  }

  Future<void> createTemplate({Deadline? deadline}) async {
    if (null == deadline) {
      return;
    }
    Deadline template = deadline.copyWith(
        repeatableState: RepeatableState.template, lastUpdated: DateTime.now());
    await _deadlineRepo.create(template);
  }

  Future<List<int>> deleteFutures({Deadline? deadline}) async {
    try {
      return await _repeatService.deleteFutures(
          model: deadline ?? curDeadline!);
    } on FailureToUpdateException catch (e) {
      log(e.cause);
      return Future.error(e);
    } on FailureToUploadException catch (e) {
      log(e.cause);
      return Future.error(e);
    }
  }

  Future<void> deleteAndCancelFutures({Deadline? deadline}) async {
    List<int> cancelIDs = await deleteFutures(deadline: deadline);
    await _notificationService.cancelMultiple(ids: cancelIDs);
  }

  Future<List<Deadline>> getDeleted(
          {int limit = Constants.minLimitPerQuery, int offset = 0}) async =>
      await _deadlineRepo.getDeleted(limit: limit, offset: offset);

  Future<List<Deadline>> getDeadlines(
          {int limit = Constants.minLimitPerQuery, int offset = 0}) async =>
      await _deadlineRepo.getRepoListBy(
          sorter: sorter, limit: limit, offset: offset);

  Future<List<Deadline>> getDeadlinesBy(
          {int limit = Constants.minLimitPerQuery, int offset = 0}) async =>
      await _deadlineRepo.getRepoListBy(
          sorter: sorter, limit: limit, offset: offset);

  Future<List<Deadline>> getOverdues({int limit = 50, int offset = 0}) async =>
      await _deadlineRepo.getOverdues(limit: limit, offset: offset);

  Future<List<Deadline>> getUpcoming({int limit = 5, int offset = 0}) async =>
      await _deadlineRepo.getUpcoming(limit: limit, offset: offset);

  Future<List<Deadline>> searchDeadlines(
          {required String searchString, bool toDelete = false}) async =>
      await _deadlineRepo.search(
          searchString: searchString, toDelete: toDelete);

  Future<List<Deadline>> mostRecent({int limit = 5}) async =>
      await _deadlineRepo.mostRecent(limit: 5);

  Future<Deadline?> getDeadlineByID({int? id}) async {
    if (null == id) {
      return null;
    }
    return await _deadlineRepo.getByID(id: id);
  }

  Future<void> scheduleNotification({Deadline? deadline}) async {
    deadline = deadline ?? curDeadline!;
    if (null == deadline.dueDate || null == deadline.warnDate) {
      return;
    }
    String newDue = Jiffy.parseFromDateTime(deadline.dueDate!)
        .toLocal()
        .format(pattern: "MMM d, hh:mm a")
        .toString();
    await _notificationService.scheduleNotification(
        id: deadline.notificationID!,
        warnDate: deadline.warnDate!,
        message:
            "${deadline.name} is due on: $newDue\n It's okay to ask for more time.",
        payload: "DEADLINE\n${deadline.id}");
  }

  Future<void> cancelNotification({Deadline? deadline}) async {
    deadline = deadline ?? curDeadline!;
    if (null != deadline.notificationID) {
      return await _notificationService.cancelNotification(
          id: deadline.notificationID!);
    }
  }

  bool validateWarnDate({DateTime? warnDate}) =>
      _notificationService.validateNotificationDate(notificationDate: warnDate);

  Future<List<Deadline>> getDeadlinesBetween(
          {DateTime? start, DateTime? end}) async =>
      await _deadlineRepo.getRange(start: start, end: end);
}
