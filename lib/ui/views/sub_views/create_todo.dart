import "dart:math";

import "package:another_flushbar/flushbar.dart";
import "package:auto_size_text/auto_size_text.dart";
import "package:auto_size_text_field/auto_size_text_field.dart";
import "package:calendar_date_picker2/calendar_date_picker2.dart";
import "package:flutter/material.dart";
import "package:flutter/semantics.dart";
import "package:intl/intl.dart";
import "package:jiffy/jiffy.dart";
import "package:numberpicker/numberpicker.dart";
import "package:provider/provider.dart";

import "../../../model/task/group.dart";
import "../../../model/task/subtask.dart";
import "../../../providers/group_provider.dart";
import "../../../providers/todo_provider.dart";
import "../../../providers/user_provider.dart";
import "../../../util/constants.dart";
import "../../../util/enums.dart";
import "../../../util/exceptions.dart";
import "../../../util/numbers.dart";
import "../../widgets/flushbars.dart";
import "../../widgets/padded_divider.dart";

class CreateToDoScreen extends StatefulWidget {
  final int? groupID;

  const CreateToDoScreen({Key? key, this.groupID}) : super(key: key);

  @override
  State<CreateToDoScreen> createState() => _CreateToDoScreen();
}

class _CreateToDoScreen extends State<CreateToDoScreen> {
  late bool checkClose;
  late bool expanded;

  // Provider (Needs user values) -> Refactor to DI for testing.
  late final UserProvider userProvider;
  late final ToDoProvider toDoProvider;
  late final GroupProvider groupProvider;

  // Scrolling
  late final ScrollController mainScrollController;
  late final ScrollController subScrollControllerLeft;
  late final ScrollController subScrollControllerRight;
  late final ScrollPhysics scrollPhysics;

  // Param fields.
  late TaskType taskType;

  late String name;
  late final TextEditingController nameEditingController;
  String? nameErrorText;

  // Group -> Tbh, not super sure what to do with this.
  late final SearchController groupEditingController;
  late List<MapEntry<String, int>> searchHistory;
  int? groupID;

  // Description
  late String description;
  late final TextEditingController descriptionEditingController;

  // Weight
  late int weight;

  // Only update this on subtask weight change
  late int sumWeight;

  // ExpectedDuration & Real Duration
  late int expectedDuration;
  late int realDuration;

  late Priority priority;

  // Status
  late bool completed;
  late bool myDay;

  // DateTimes
  DateTime? startDate;
  TimeOfDay? startTime;
  DateTime? dueDate;
  TimeOfDay? dueTime;

  // Repeat
  late Frequency frequency;

  late TextEditingController repeatSkipEditingController;
  late int repeatSkip;

  late Set<int> weekDayList;
  late List<bool> weekDays;

  late final List<TextEditingController> subTaskEditingController;
  late final List<SubTask> subTasks;
  late int shownTasks;

  @override
  void initState() {
    super.initState();
    initializeProviders();

    initializeParameters();

    initializeControllers().whenComplete(() {});
  }

  void initializeParameters() {
    // Refactor this into the user provider class.
    checkClose = false;
    expanded = false;
    taskType = TaskType.small;

    name = "";
    description = "";

    weight = 0;
    sumWeight = 0;

    priority = Priority.low;

    completed = false;
    myDay = false;
    expectedDuration = 0;
    realDuration = 0;

    searchHistory = List.empty(growable: true);

    frequency = Frequency.once;

    repeatSkip = 1;

    subTasks = List.generate(Constants.maxNumTasks, (_) => SubTask());
    shownTasks = 0;
    weekDayList = {};
    weekDays = List.generate(7, (_) => false);
    groupID = widget.groupID;
  }

  Future<void> initializeControllers() async {
    mainScrollController = ScrollController();
    subScrollControllerLeft = ScrollController();
    subScrollControllerRight = ScrollController();
    scrollPhysics =
        const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());
    nameEditingController = TextEditingController();
    nameEditingController.addListener(() {
      nameErrorText = null;
      checkClose = true;
      String newText = nameEditingController.text;
      SemanticsService.announce(newText, Directionality.of(context));
      setState(() => name = newText);
    });

    groupEditingController = SearchController();
    groupProvider
        .getGroupByID(id: groupID)
        .then((group) =>
            setState(() => groupEditingController.text = group?.name ?? ""))
        .catchError((_) {
      Flushbar? error;

      error = Flushbars.createError(
        message: "Error with Group Retrieval",
        context: context,
        dismissCallback: () => error?.dismiss(),
      );

      error.show(context);
    });
    groupEditingController.addListener(() {
      checkClose = true;
      String newText = nameEditingController.text;
      SemanticsService.announce(newText, Directionality.of(context));
    });

    descriptionEditingController = TextEditingController();
    descriptionEditingController.addListener(() {
      checkClose = true;
      String newText = descriptionEditingController.text;
      SemanticsService.announce(newText, Directionality.of(context));
      description = newText;
    });

    repeatSkipEditingController = TextEditingController();
    repeatSkipEditingController.addListener(() {
      checkClose = true;
      String newText = descriptionEditingController.text;
      SemanticsService.announce(newText, Directionality.of(context));
      repeatSkip = int.tryParse(newText) ?? repeatSkip;
      repeatSkip = max(repeatSkip, 1);
    });

    subTaskEditingController =
        List.generate(subTasks.length, (_) => TextEditingController());
    for (int i = 0; i < subTaskEditingController.length; i++) {
      subTaskEditingController[i].addListener(() {
        checkClose = true;
        String newText = subTaskEditingController[i].text;
        SemanticsService.announce(newText, Directionality.of(context));
      });
    }
  }

  void initializeProviders() {
    userProvider = Provider.of<UserProvider>(context, listen: false);
    toDoProvider = Provider.of<ToDoProvider>(context, listen: false);
    groupProvider = Provider.of<GroupProvider>(context, listen: false);
  }

  @override
  void dispose() {
    nameEditingController.dispose();
    groupEditingController.dispose();
    descriptionEditingController.dispose();
    repeatSkipEditingController.dispose();
    for (TextEditingController controller in subTaskEditingController) {
      controller.dispose();
    }
    super.dispose();
  }

  void handleGroupSelection(
      {required Group group, required SearchController controller}) {
    // Controller logic
    controller.closeView(group.name);
    setState(() {
      checkClose = true;
      groupID = group.localID;
      if (searchHistory.length >= Constants.historyLength) {
        searchHistory.removeLast();
      }

      searchHistory.insert(0, MapEntry(group.name, group.localID!));
    });
  }

  void handleHistorySelection(
      {required MapEntry<String, int> groupData,
      required SearchController controller}) {
    controller.closeView(groupData.key);
    setState(() {
      checkClose = true;
      groupID = groupData.value;
    });
  }

  bool validateData() {
    bool valid = true;
    if (groupEditingController.text.isEmpty) {
      groupID = widget.groupID;
    }
    if (nameEditingController.text.isEmpty) {
      valid = false;
      setState(() => nameErrorText = "Enter Task Name");
    }
    if (frequency == Frequency.custom) {
      if (weekDayList.isEmpty) {
        weekDayList
            .add(min(((startDate?.weekday ?? DateTime.now().weekday) - 1), 0));
      }
    }

    return valid;
  }

  // This is likely totally unnecessary.
  Icon getBatteryIcon({required int weight, required bool selected}) {
    // Icon is scaled for sum-weight.
    weight = (taskType == TaskType.small)
        ? weight
        : remap(
                x: weight,
                inMin: 0,
                inMax: Constants.maxWeight,
                outMin: 0,
                outMax: 5)
            .toInt();

    if (selected) {
      return Constants.selectedBatteryIcons[weight]!;
    }
    return Constants.batteryIcons[weight]!;
  }

  void mergeDateTimes() {
    startDate = startDate ?? DateTime.now();
    startTime = startTime ?? Constants.midnight;

    startDate =
        startDate!.copyWith(hour: startTime!.hour, minute: startTime!.minute);

    dueDate = dueDate ?? DateTime.now();
    dueTime = dueTime ?? Constants.midnight;

    dueDate = dueDate!.copyWith(hour: dueTime!.hour, minute: dueTime!.minute);
  }

  Future<void> handleCreate({required BuildContext context}) async {
    mergeDateTimes();

    for (int index in weekDayList) {
      weekDays[index] = true;
    }

    await toDoProvider
        .createToDo(
          groupID: groupID,
          taskType: taskType,
          name: name,
          description: description,
          weight: (taskType == TaskType.small) ? weight : sumWeight,
          expectedDuration: expectedDuration,
          realDuration: realDuration,
          priority: priority,
          startDate: startDate,
          dueDate: dueDate,
          myDay: myDay,
          completed: completed,
          repeatable: frequency != Frequency.once,
          frequency: frequency,
          repeatDays: weekDays,
          repeatSkip: repeatSkip,
          subTasks: subTasks,
        )
        .whenComplete(() => Navigator.pop(context))
        .catchError((e) {
      Flushbar? error;

      error = Flushbars.createError(
        message: e.cause,
        context: context,
        dismissCallback: () => error?.dismiss(),
      );

      error.show(context);
    },
            test: (e) =>
                e is FailureToCreateException || e is FailureToUploadException);
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool largeScreen = (width >= Constants.largeScreen);
    bool smallScreen = (width <= Constants.smallScreen);
    bool hugeScreen = (width >= Constants.hugeScreen);

    bool showTimeTile = (null != startDate || null != dueDate);
    return (largeScreen)
        ? buildDesktopDialog(
            context: context,
            showTimeTile: showTimeTile,
            smallScreen: smallScreen,
            hugeScreen: hugeScreen)
        : buildMobileDialog(
            context: context,
            showTimeTile: showTimeTile,
            smallScreen: smallScreen);
  }

  Dialog buildDesktopDialog(
      {required BuildContext context,
      bool smallScreen = false,
      bool showTimeTile = false,
      bool hugeScreen = false}) {
    return Dialog(
      insetPadding: const EdgeInsets.all(Constants.outerDialogPadding),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxHeight: Constants.maxLandscapeDialogHeight),
        child: Padding(
          padding: const EdgeInsets.all(Constants.padding),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title && Close Button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: Constants.padding),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: AutoSizeText(
                            "New Task",
                            overflow: TextOverflow.visible,
                            style: Constants.headerStyle,
                            minFontSize: Constants.medium,
                            softWrap: true,
                            maxLines: 1,
                          ),
                        ),
                        (expectedDuration > 0)
                            ? Flexible(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Tooltip(
                                        message: "Expected",
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: Constants.padding),
                                          child: Row(
                                            children: [
                                              const Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.fill,
                                                  child: Icon(
                                                    Icons.timer_outlined,
                                                  ),
                                                ),
                                              ),
                                              Flexible(
                                                child: AutoSizeText(
                                                    Duration(
                                                            seconds:
                                                                expectedDuration)
                                                        .toString()
                                                        .split(".")
                                                        .first,
                                                    minFontSize:
                                                        Constants.medium,
                                                    overflow:
                                                        TextOverflow.visible,
                                                    softWrap: false,
                                                    maxLines: 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: Tooltip(
                                        message: "Projected",
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: Constants.padding),
                                          child: Row(
                                            children: [
                                              const Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.fill,
                                                  child: Icon(
                                                    Icons.timer_rounded,
                                                  ),
                                                ),
                                              ),
                                              Flexible(
                                                child: AutoSizeText(
                                                    Duration(
                                                            seconds:
                                                                realDuration)
                                                        .toString()
                                                        .split(".")
                                                        .first,
                                                    minFontSize:
                                                        Constants.medium,
                                                    overflow:
                                                        TextOverflow.visible,
                                                    softWrap: false,
                                                    maxLines: 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                        buildCloseButton(context: context),
                      ]),
                ),
                const PaddedDivider(padding: Constants.padding),
                Expanded(
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ListView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Constants.padding),
                              shrinkWrap: true,
                              controller: subScrollControllerLeft,
                              physics: scrollPhysics,
                              children: [
                                // Title + status
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: (smallScreen)
                                          ? Constants.padding
                                          : Constants.innerPadding),
                                  child:
                                      buildNameTile(smallScreen: smallScreen),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: Constants.padding),
                                  child:
                                      buildWeightTile(smallScreen: smallScreen),
                                ),
                                const PaddedDivider(
                                    padding: Constants.innerPadding),
                                // TaskType
                                const Row(children: [
                                  Expanded(
                                    child: AutoSizeText("Task Type",
                                        maxLines: 1,
                                        softWrap: true,
                                        textAlign: TextAlign.center,
                                        minFontSize: Constants.medium,
                                        style: Constants.headerStyle),
                                  )
                                ]),
                                Padding(
                                  padding: const EdgeInsets.all(
                                      Constants.innerPadding),
                                  child: buildTaskTypeButton(
                                      smallScreen: smallScreen),
                                ),
                                // Subtasks
                                (taskType != TaskType.small)
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: Constants.innerPadding),
                                        child: buildSubTasksTile(
                                            context: context,
                                            smallScreen: smallScreen),
                                      )
                                    : const SizedBox.shrink(),

                                const PaddedDivider(padding: Constants.padding),
                                // My Day
                                buildMyDayTile(),
                                const PaddedDivider(padding: Constants.padding),
                                // Priority
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: Constants.padding),
                                  child: Row(children: [
                                    Expanded(
                                        child: AutoSizeText("Priority",
                                            style: Constants.headerStyle,
                                            maxLines: 1,
                                            softWrap: true,
                                            textAlign: TextAlign.center,
                                            minFontSize: Constants.medium))
                                  ]),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: Constants.padding),
                                  child: buildPriorityTile(
                                      smallScreen: smallScreen),
                                ),
                              ]),
                        ),
                        Expanded(
                          flex: (hugeScreen) ? 2 : 1,
                          child: ListView(
                              controller: subScrollControllerRight,
                              physics: scrollPhysics,
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Constants.padding),
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.all(Constants.padding),
                                  child: buildGroupBar(),
                                ),

                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: Constants.padding),
                                  child: PaddedDivider(
                                      padding: Constants.innerPadding),
                                ),

                                // Description
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: Constants.padding),
                                  child: buildDescriptionTile(
                                      smallScreen: smallScreen),
                                ),

                                const PaddedDivider(
                                    padding: Constants.innerPadding),
                                // Expected Duration / RealDuration -> Show status, on click, open a dialog.
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: Constants.padding),
                                  child: buildDurationTile(
                                      context: context,
                                      smallScreen: smallScreen),
                                ),

                                const PaddedDivider(
                                    padding: Constants.innerPadding),
                                // DateTime -> Show status, on click, open a dialog.
                                //startDate
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: Constants.padding),
                                  child: buildDateTile(context: context),
                                ),

                                const PaddedDivider(
                                    padding: Constants.innerPadding),
                                // Time
                                (showTimeTile)
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: Constants.padding),
                                        child: buildTimeTile(),
                                      )
                                    : const SizedBox.shrink(),

                                (showTimeTile)
                                    ? const PaddedDivider(
                                        padding: Constants.innerPadding)
                                    : const SizedBox.shrink(),
                                // Repeatable Stuff -> Show status, on click, open a dialog.
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: Constants.padding),
                                  child: buildRepeatableTile(
                                      context: context,
                                      smallScreen: smallScreen),
                                ),
                              ]),
                        )
                      ]),
                ),

                const PaddedDivider(padding: Constants.padding),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: Constants.padding),
                  child: buildCreateButton(context: context),
                )
              ]),
        ),
      ),
    );
  }

  Card buildSubTasksTile(
      {required BuildContext context, bool smallScreen = false}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
          side: BorderSide(
              width: 2,
              color: Theme.of(context).colorScheme.outlineVariant,
              strokeAlign: BorderSide.strokeAlignInside),
          borderRadius: const BorderRadius.all(
              Radius.circular(Constants.roundedCorners))),
      child: ExpansionTile(
        initiallyExpanded: expanded,
        onExpansionChanged: (value) => setState(() => expanded = value),
        title: const AutoSizeText("Steps",
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            minFontSize: Constants.small),
        subtitle: AutoSizeText(
            "${min(shownTasks, Constants.numTasks[taskType]!)}/${Constants.numTasks[taskType]!} Steps",
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            minFontSize: Constants.small),
        collapsedShape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.roundedCorners))),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.roundedCorners))),
        children: [
          buildReorderableSubTasks(
              smallScreen: smallScreen, physics: scrollPhysics),
          (shownTasks < Constants.numTasks[taskType]!)
              ? ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: const AutoSizeText("Add a step",
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      minFontSize: Constants.small),
                  onTap: () => setState(() {
                        shownTasks++;
                        shownTasks = min(shownTasks, Constants.maxNumTasks);
                      }))
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  Dialog buildMobileDialog(
      {required BuildContext context,
      bool smallScreen = false,
      showTimeTile = false}) {
    return Dialog(
      insetPadding: const EdgeInsets.all(Constants.outerDialogPadding),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxHeight: Constants.maxLandscapeDialogHeight),
        child: Padding(
          padding: const EdgeInsets.all(Constants.padding),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title && Close Button
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Constants.padding),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: AutoSizeText(
                              "New Task",
                              overflow: TextOverflow.visible,
                              style: Constants.headerStyle,
                              minFontSize: Constants.medium,
                              softWrap: true,
                              maxLines: 1,
                            ),
                          ),
                          (expectedDuration > 0)
                              ? Flexible(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Tooltip(
                                          message: "Expected Task Duration",
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: Constants.padding),
                                            child: Row(
                                              children: [
                                                const Flexible(
                                                  child: FittedBox(
                                                    fit: BoxFit.fill,
                                                    child: Icon(
                                                      Icons.timer_outlined,
                                                    ),
                                                  ),
                                                ),
                                                Flexible(
                                                  child: AutoSizeText(
                                                      Duration(
                                                              seconds:
                                                                  expectedDuration)
                                                          .toString()
                                                          .split(".")
                                                          .first,
                                                      minFontSize:
                                                          Constants.medium,
                                                      overflow:
                                                          TextOverflow.visible,
                                                      softWrap: false,
                                                      maxLines: 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: Tooltip(
                                          message: "Actual Task Duration",
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: Constants.padding),
                                            child: Row(
                                              children: [
                                                const Flexible(
                                                  child: FittedBox(
                                                    fit: BoxFit.fill,
                                                    child: Icon(
                                                      Icons.timer,
                                                    ),
                                                  ),
                                                ),
                                                Flexible(
                                                  child: AutoSizeText(
                                                      Duration(
                                                              seconds:
                                                                  realDuration)
                                                          .toString()
                                                          .split(".")
                                                          .first,
                                                      minFontSize:
                                                          Constants.medium,
                                                      overflow:
                                                          TextOverflow.visible,
                                                      softWrap: false,
                                                      maxLines: 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                          buildCloseButton(context: context),
                        ]),
                  ),
                ),
                const PaddedDivider(padding: Constants.padding),
                Expanded(
                  flex: 10,
                  child: ListView(
                    shrinkWrap: true,
                    controller: mainScrollController,
                    physics: scrollPhysics,
                    children: [
                      // Title + status
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: (smallScreen)
                                ? Constants.padding
                                : Constants.innerPadding),
                        child: buildNameTile(smallScreen: smallScreen),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Constants.padding),
                        child: buildWeightTile(smallScreen: smallScreen),
                      ),
                      const PaddedDivider(padding: Constants.innerPadding),
                      // TaskType
                      const Row(children: [
                        Expanded(
                          child: AutoSizeText("Task Type",
                              maxLines: 1,
                              softWrap: true,
                              textAlign: TextAlign.center,
                              minFontSize: Constants.medium,
                              style: Constants.headerStyle),
                        )
                      ]),
                      Padding(
                        padding: const EdgeInsets.all(Constants.innerPadding),
                        child: buildTaskTypeButton(smallScreen: smallScreen),
                      ),
                      // Subtasks
                      (taskType != TaskType.small)
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Constants.innerPadding),
                              child: buildSubTasksTile(
                                  context: context, smallScreen: smallScreen),
                            )
                          : const SizedBox.shrink(),

                      const PaddedDivider(padding: Constants.padding),
                      // My Day
                      buildMyDayTile(),
                      const PaddedDivider(padding: Constants.padding),
                      // Priority
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: Constants.padding),
                        child: Row(children: [
                          Expanded(
                              child: AutoSizeText("Priority",
                                  style: Constants.headerStyle,
                                  maxLines: 1,
                                  softWrap: true,
                                  textAlign: TextAlign.center,
                                  minFontSize: Constants.medium))
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Constants.padding),
                        child: buildPriorityTile(smallScreen: smallScreen),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: PaddedDivider(padding: Constants.innerPadding),
                      ),

                      // Group Picker
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Constants.padding),
                        child: buildGroupBar(),
                      ),

                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: Constants.padding),
                        child: PaddedDivider(padding: Constants.innerPadding),
                      ),

                      // Description
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Constants.padding),
                        child: buildDescriptionTile(smallScreen: smallScreen),
                      ),

                      const PaddedDivider(padding: Constants.innerPadding),
                      // Expected Duration / RealDuration -> Show status, on click, open a dialog.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Constants.padding),
                        child: buildDurationTile(
                            context: context, smallScreen: smallScreen),
                      ),

                      const PaddedDivider(padding: Constants.innerPadding),
                      // DateTime -> Show status, on click, open a dialog.
                      //startDate
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Constants.padding),
                        child: buildDateTile(context: context),
                      ),

                      const PaddedDivider(padding: Constants.innerPadding),
                      // Time
                      (showTimeTile)
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Constants.padding),
                              child: buildTimeTile(),
                            )
                          : const SizedBox.shrink(),

                      (showTimeTile)
                          ? const PaddedDivider(padding: Constants.innerPadding)
                          : const SizedBox.shrink(),
                      // Repeatable Stuff -> Show status, on click, open a dialog.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Constants.padding),
                        child: buildRepeatableTile(
                            context: context, smallScreen: smallScreen),
                      ),
                    ],
                  ),
                ),

                const PaddedDivider(padding: Constants.padding),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: Constants.padding),
                  child: buildCreateButton(context: context),
                )
              ]),
        ),
      ),
    );
  }

  Row buildCreateButton({required BuildContext context}) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      FilledButton.icon(
          label: const Text("Create"),
          icon: const Icon(Icons.add),
          onPressed: () async {
            bool validData = validateData();
            if (validData) {
              await handleCreate(context: context);
            }
            // Then save.
          })
    ]);
  }

  ListTile buildRepeatableTile(
      {required BuildContext context, bool smallScreen = false}) {
    return ListTile(
        leading: const Icon(Icons.event_repeat_rounded),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.roundedCorners))),
        title: (frequency == Frequency.once)
            ? const AutoSizeText("Set Recurring?",
                overflow: TextOverflow.visible,
                minFontSize: Constants.small,
                maxLines: 2,
                softWrap: true)
            : AutoSizeText(toBeginningOfSentenceCase(frequency.name)!,
                overflow: TextOverflow.visible,
                minFontSize: Constants.small,
                maxLines: 1,
                softWrap: false),
        onTap: () {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                Frequency cacheFreq = frequency;
                Set<int> cacheWeekdays = Set.from(weekDayList);
                if (cacheWeekdays.isEmpty) {
                  int day = (null != startDate)
                      ? max(startDate!.weekday - 1, 0)
                      : max(DateTime.now().weekday - 1, 0);
                  cacheWeekdays.add(day);
                }

                int cacheSkip = repeatSkip;
                return StatefulBuilder(builder: (BuildContext context,
                    void Function(void Function()) setState) {
                  return Dialog(
                      child: Padding(
                          padding: const EdgeInsets.all(Constants.innerPadding),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: AutoSizeText(
                                          "Set Recurring",
                                          softWrap: false,
                                          maxLines: 1,
                                          minFontSize: Constants.medium,
                                          overflow: TextOverflow.visible,
                                          style: Constants.headerStyle,
                                        ),
                                      )
                                    ]),
                                const Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: AutoSizeText(
                                        "Repeat:",
                                        softWrap: false,
                                        maxLines: 1,
                                        minFontSize: Constants.medium,
                                        overflow: TextOverflow.visible,
                                        style: Constants.largeHeaderStyle,
                                      ),
                                    ),
                                    Flexible(
                                      child: FittedBox(
                                          fit: BoxFit.fill,
                                          child: Icon(Icons.repeat_rounded,
                                              size: Constants.medIconSize)),
                                    ),
                                  ],
                                ),
                                // This is a hacky override until m3 Has width-scaling for DropdownMenu
                                Padding(
                                  padding: (cacheFreq != Frequency.once &&
                                          cacheFreq != Frequency.daily)
                                      ? const EdgeInsets.fromLTRB(
                                          Constants.innerPadding,
                                          Constants.innerPadding,
                                          Constants.innerPadding,
                                          Constants.halfPadding)
                                      : const EdgeInsets.all(
                                          Constants.innerPadding),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        width: 2,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                        strokeAlign:
                                            BorderSide.strokeAlignOutside,
                                      ),
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(Constants.circular)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                          Constants.innerPadding),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<Frequency>(
                                          focusColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: Constants.padding),
                                          isDense: true,
                                          isExpanded: true,
                                          dropdownColor: Constants.dialogColor(
                                              context: context),
                                          borderRadius: const BorderRadius.all(
                                              Radius.circular(
                                                  Constants.roundedCorners)),
                                          value: cacheFreq,
                                          onChanged: (Frequency? value) =>
                                              setState(() => cacheFreq =
                                                  value ?? cacheFreq),
                                          items: Frequency.values
                                              .map((Frequency frequency) =>
                                                  DropdownMenuItem<Frequency>(
                                                    value: frequency,
                                                    child: AutoSizeText(
                                                      "${toBeginningOfSentenceCase(frequency.name)}",
                                                      softWrap: false,
                                                      maxLines: 1,
                                                      minFontSize:
                                                          Constants.small,
                                                    ),
                                                  ))
                                              .toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                (cacheFreq == Frequency.custom)
                                    ? Column(
                                        children: [
                                          // Days of the week - Wrap in padding and a container
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                Constants.innerPadding,
                                                Constants.innerPadding,
                                                Constants.innerPadding,
                                                0),
                                            child: Wrap(
                                                spacing: 5,
                                                runSpacing: 5,
                                                alignment: WrapAlignment.center,
                                                runAlignment:
                                                    WrapAlignment.center,
                                                children: Constants.weekDays
                                                    .map((weekDay) => InputChip(
                                                        backgroundColor:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .surfaceVariant,
                                                        shape:
                                                            const RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                  Radius.circular(
                                                                      Constants
                                                                          .circular)),
                                                          side: BorderSide(
                                                            strokeAlign: BorderSide
                                                                .strokeAlignOutside,
                                                          ),
                                                        ),
                                                        label: AutoSizeText(
                                                            weekDay.key,
                                                            minFontSize:
                                                                Constants.small,
                                                            maxLines: 1,
                                                            softWrap: false,
                                                            overflow:
                                                                TextOverflow
                                                                    .visible),
                                                        selected: cacheWeekdays
                                                            .contains(
                                                                weekDay.value),
                                                        onSelected:
                                                            (bool selected) =>
                                                                setState(() {
                                                                  if (selected) {
                                                                    cacheWeekdays
                                                                        .add(weekDay
                                                                            .value);
                                                                  } else {
                                                                    cacheWeekdays
                                                                        .remove(
                                                                            weekDay.value);
                                                                    if (cacheWeekdays
                                                                        .isEmpty) {
                                                                      int day = (null !=
                                                                              startDate)
                                                                          ? max(
                                                                              startDate!.weekday -
                                                                                  1,
                                                                              0)
                                                                          : max(
                                                                              DateTime.now().weekday - 1,
                                                                              0);
                                                                      cacheWeekdays
                                                                          .add(
                                                                              day);
                                                                    }
                                                                  }
                                                                })))
                                                    .toList()),
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),

                                // Repeat Skip
                                (cacheFreq != Frequency.once &&
                                        cacheFreq != Frequency.daily)
                                    ? Padding(
                                        padding: const EdgeInsets.all(
                                            Constants.innerPadding),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Flexible(
                                                child: AutoSizeText(
                                              "Every",
                                              minFontSize: Constants.small,
                                              style: Constants.headerStyle,
                                              overflow: TextOverflow.visible,
                                              softWrap: false,
                                              maxLines: 1,
                                            )),
                                            Expanded(
                                                child: NumberPicker(
                                                    itemCount: 1,
                                                    textStyle: Constants
                                                        .numberPickerSecondary(
                                                            context: context),
                                                    selectedTextStyle: Constants
                                                        .numberPickerPrimary(
                                                            context: context),
                                                    minValue: 1,
                                                    maxValue: 100,
                                                    value: cacheSkip,
                                                    haptics: true,
                                                    onChanged: (value) {
                                                      SemanticsService.announce(
                                                          "Skip value: $value",
                                                          Directionality.of(
                                                              context));
                                                      setState(() =>
                                                          cacheSkip = value);
                                                    })),
                                            Flexible(
                                              child: AutoSizeText(
                                                (cacheFreq == Frequency.custom)
                                                    ? "week${(cacheSkip > 1) ? "s." : "."}"
                                                    : cacheFreq.name.replaceAll(
                                                        "ly",
                                                        (cacheSkip > 1)
                                                            ? "s."
                                                            : "."),
                                                minFontSize: Constants.small,
                                                style: Constants.headerStyle,
                                                overflow: TextOverflow.visible,
                                                softWrap: false,
                                                maxLines: 1,
                                                textAlign: TextAlign.end,
                                              ),
                                            )
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(),

                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: Constants.padding),
                                          child: FilledButton.tonalIcon(
                                              icon: const Icon(
                                                  Icons.close_rounded),
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              label: const AutoSizeText(
                                                  "Cancel",
                                                  softWrap: false,
                                                  overflow:
                                                      TextOverflow.visible,
                                                  maxLines: 1,
                                                  minFontSize:
                                                      Constants.small)),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              left: Constants.padding),
                                          child: FilledButton.icon(
                                            icon:
                                                const Icon(Icons.done_rounded),
                                            onPressed: () {
                                              setState(() {
                                                frequency = cacheFreq;
                                                weekDayList = cacheWeekdays;
                                                repeatSkip = cacheSkip;
                                              });
                                              Navigator.pop(context);
                                            },
                                            label: const AutoSizeText("Done",
                                                softWrap: false,
                                                overflow: TextOverflow.visible,
                                                maxLines: 1,
                                                minFontSize: Constants.small),
                                          ),
                                        ),
                                      )
                                    ])
                              ])));
                });
              }).then((_) => setState(() {}));
        },
        trailing: (frequency != Frequency.once)
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() {
                      checkClose = true;
                      frequency = Frequency.once;
                      weekDayList.clear();
                      repeatSkip = 1;
                    }))
            : null);
  }

  ListTile buildTimeTile() {
    return ListTile(
        leading: const Icon(Icons.schedule_rounded),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.roundedCorners))),
        title: (null == startTime && null == dueTime)
            ? const AutoSizeText(
                "Add Times",
                overflow: TextOverflow.visible,
                minFontSize: Constants.small,
                maxLines: 2,
                softWrap: true,
              )
            : Row(children: [
                (null == startTime)
                    ? const Flexible(
                        child: AutoSizeText(
                        "Start Time",
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        maxLines: 2,
                        minFontSize: Constants.small,
                      ))
                    : Flexible(
                        child: Tooltip(
                        message: "Start at",
                        child: AutoSizeText(
                          startTime!.format(context).toString(),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          maxLines: 2,
                          minFontSize: Constants.small,
                        ),
                      )),
                (null == dueTime)
                    ? const Flexible(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: Constants.padding),
                          child: FittedBox(
                              fit: BoxFit.fill,
                              child: Icon(Icons.history_toggle_off_rounded)),
                        ),
                      )
                    : const Flexible(
                        child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: Constants.padding),
                        child: FittedBox(
                            fit: BoxFit.fill,
                            child: Icon(Icons.schedule_rounded)),
                      )),
                (null == dueTime)
                    ? const Flexible(
                        child: AutoSizeText(
                          "Due Time",
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          maxLines: 2,
                          minFontSize: Constants.small,
                        ),
                      )
                    : Flexible(
                        child: Tooltip(
                          message: "Due at",
                          child: AutoSizeText(
                            dueTime!.format(context).toString(),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                            maxLines: 2,
                            minFontSize: Constants.small,
                          ),
                        ),
                      ),
              ]),
        onTap: () {
          showDialog<void>(
              context: context,
              builder: (BuildContext context) {
                TimeOfDay? tmpStart = startTime;
                TimeOfDay? tmpDue = dueTime;
                return StatefulBuilder(
                    builder: (BuildContext context,
                            void Function(void Function()) setState) =>
                        Dialog(
                            child: Padding(
                          padding: const EdgeInsets.all(Constants.innerPadding),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                        child: AutoSizeText(
                                          "Select Times",
                                          style: Constants.headerStyle,
                                          softWrap: true,
                                          overflow: TextOverflow.visible,
                                          maxLines: 2,
                                          minFontSize: Constants.medium,
                                        ),
                                      )
                                    ]),
                                const Flexible(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Flexible(
                                          child: AutoSizeText(
                                        "Start | Due ",
                                        style: Constants.largeHeaderStyle,
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                        maxLines: 1,
                                        minFontSize: Constants.large,
                                      )),
                                      Flexible(
                                        child: FittedBox(
                                            fit: BoxFit.fill,
                                            child: Icon(Icons.schedule_rounded,
                                                size: Constants.medIconSize)),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: Constants.innerPadding),
                                  child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Expanded(
                                          flex: 10,
                                          child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  width: 2,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outlineVariant,
                                                ),
                                                shape: const RoundedRectangleBorder(
                                                    borderRadius: BorderRadius
                                                        .all(Radius.circular(
                                                            Constants
                                                                .roundedCorners))),
                                              ),
                                              onPressed: () async {
                                                final TimeOfDay? picked =
                                                    await showTimePicker(
                                                        context: context,
                                                        initialTime: tmpStart ??
                                                            Constants.midnight);
                                                if (null != picked) {
                                                  setState(
                                                      () => tmpStart = picked);
                                                }
                                              },
                                              child: (null != tmpStart)
                                                  ? AutoSizeText(
                                                      tmpStart!
                                                          .format(context)
                                                          .toString(),
                                                      softWrap: false,
                                                      overflow:
                                                          TextOverflow.visible,
                                                      maxLines: 1,
                                                      minFontSize:
                                                          Constants.small,
                                                    )
                                                  : const AutoSizeText(
                                                      "Start Time",
                                                      softWrap: true,
                                                      overflow:
                                                          TextOverflow.visible,
                                                      maxLines: 1,
                                                      minFontSize:
                                                          Constants.small)),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  Constants.halfPadding),
                                          child: Text("|",
                                              style: Constants.timeColon),
                                        ),
                                        Expanded(
                                          flex: 10,
                                          child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  width: 2,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outlineVariant,
                                                ),
                                                shape: const RoundedRectangleBorder(
                                                    borderRadius: BorderRadius
                                                        .all(Radius.circular(
                                                            Constants
                                                                .roundedCorners))),
                                              ),
                                              onPressed: () async {
                                                final TimeOfDay? picked =
                                                    await showTimePicker(
                                                        context: context,
                                                        initialTime: tmpDue ??
                                                            Constants.midnight);
                                                if (null != picked) {
                                                  setState(
                                                      () => tmpDue = picked);
                                                }
                                              },
                                              child: (null != tmpDue)
                                                  ? AutoSizeText(
                                                      tmpDue!
                                                          .format(context)
                                                          .toString(),
                                                      softWrap: false,
                                                      overflow:
                                                          TextOverflow.visible,
                                                      maxLines: 1,
                                                      minFontSize:
                                                          Constants.small,
                                                    )
                                                  : const AutoSizeText(
                                                      "Due Time",
                                                      softWrap: true,
                                                      overflow:
                                                          TextOverflow.visible,
                                                      maxLines: 1,
                                                      minFontSize:
                                                          Constants.small)),
                                        ),
                                      ]),
                                ),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: Constants.padding),
                                          child: FilledButton.tonalIcon(
                                              icon: const Icon(
                                                  Icons.close_rounded),
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              label: const AutoSizeText(
                                                  "Cancel",
                                                  softWrap: false,
                                                  overflow:
                                                      TextOverflow.visible,
                                                  maxLines: 1,
                                                  minFontSize:
                                                      Constants.small)),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              left: Constants.padding),
                                          child: FilledButton.icon(
                                            icon:
                                                const Icon(Icons.done_rounded),
                                            onPressed: () {
                                              setState(() {
                                                startTime = tmpStart;
                                                dueTime = tmpDue;
                                              });
                                              Navigator.pop(context);
                                            },
                                            label: const AutoSizeText("Done",
                                                softWrap: false,
                                                overflow: TextOverflow.visible,
                                                maxLines: 1,
                                                minFontSize: Constants.small),
                                          ),
                                        ),
                                      )
                                    ]),
                              ]),
                        )));
              }).then((_) => setState(() {}));
        },
        trailing: (startTime != null || dueTime != null)
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() {
                  checkClose = true;
                  startTime = null;
                  dueTime = null;
                }),
              )
            : null);
  }

  ListTile buildDateTile({required BuildContext context}) {
    return ListTile(
      leading: const Icon(Icons.today_rounded),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(Constants.roundedCorners))),
      title: (null == startDate && null == dueDate)
          ? const AutoSizeText(
              "Add Dates",
              softWrap: true,
              overflow: TextOverflow.visible,
              maxLines: 2,
              minFontSize: Constants.small,
            )
          : Row(
              children: [
                (null == startDate)
                    ? const Flexible(
                        child: AutoSizeText(
                          "Start Date",
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          maxLines: 2,
                          minFontSize: Constants.small,
                        ),
                      )
                    : Flexible(
                        child: AutoSizeText(
                            Jiffy.parseFromDateTime(startDate!)
                                .toLocal()
                                .format(
                                  pattern: "MMM d",
                                ),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                            maxLines: 2,
                            minFontSize: Constants.small)),
                const Flexible(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: Constants.padding),
                    child: AutoSizeText(
                      "-",
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      maxLines: 1,
                      minFontSize: Constants.small,
                    ),
                  ),
                ),
                (null == dueDate)
                    ? const Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(right: Constants.padding),
                          child: Icon(Icons.today_rounded),
                        ),
                      )
                    : const Flexible(
                        child: Padding(
                        padding: EdgeInsets.only(right: Constants.padding),
                        child: Icon(Icons.event_rounded),
                      )),
                (null == dueDate)
                    ? const Flexible(
                        child: AutoSizeText(
                          "Due Date",
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          maxLines: 2,
                          minFontSize: Constants.small,
                        ),
                      )
                    : Flexible(
                        child: AutoSizeText(
                            Jiffy.parseFromDateTime(dueDate!)
                                .toLocal()
                                .format(pattern: "MMM d"),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                            maxLines: 2,
                            minFontSize: Constants.small),
                      )
              ],
            ),
      trailing: (startDate != null || dueDate != null)
          ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() {
                    checkClose = true;
                    startDate = null;
                    dueDate = null;
                  }))
          : null,
      onTap: () {
        showDialog<void>(
            context: context,
            builder: (BuildContext context) {
              DateTime? tmpStart = startDate;
              DateTime? tmpDue = dueDate;
              DateTime initDate = tmpStart ?? tmpDue ?? DateTime.now();
              bool setStart = false;
              final int numDays =
                  (tmpDue?.difference(initDate).inDays ?? 0) + 1;
              List<DateTime?> showDates = List.generate(
                  numDays, (i) => initDate.copyWith(day: initDate.day + 1));

              // List ->
              return StatefulBuilder(
                  builder: (BuildContext context,
                          void Function(void Function()) setState) =>
                      Dialog(
                          child: Padding(
                        padding: const EdgeInsets.all(Constants.innerPadding),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: AutoSizeText(
                                        "Select Dates",
                                        style: Constants.headerStyle,
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                        maxLines: 2,
                                        minFontSize: Constants.medium,
                                      ),
                                    )
                                  ]),
                              const Flexible(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Flexible(
                                        child: AutoSizeText(
                                      "Start | Due ",
                                      style: Constants.largeHeaderStyle,
                                      softWrap: true,
                                      overflow: TextOverflow.visible,
                                      maxLines: 1,
                                      minFontSize: Constants.large,
                                    )),
                                    Flexible(
                                      child: FittedBox(
                                          fit: BoxFit.fill,
                                          child: Icon(Icons.date_range_rounded,
                                              size: Constants.medIconSize)),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: Constants.innerPadding),
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Expanded(
                                        flex: 10,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                                Constants.roundedCorners),
                                            border: Border.all(
                                                width: 2,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outlineVariant,
                                                strokeAlign: BorderSide
                                                    .strokeAlignOutside),
                                          ),
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Expanded(
                                                  child: TextButton(
                                                      onPressed: () =>
                                                          setState(() {
                                                            setStart = true;
                                                            tmpStart =
                                                                tmpStart ??
                                                                    DateTime
                                                                        .now();
                                                          }),
                                                      child: (null != tmpStart)
                                                          ? AutoSizeText(
                                                              Jiffy.parseFromDateTime(
                                                                      tmpStart!)
                                                                  .toLocal()
                                                                  .format(
                                                                      pattern:
                                                                          "yMMMMd"),
                                                              softWrap: false,
                                                              overflow:
                                                                  TextOverflow
                                                                      .visible,
                                                              maxLines: 1,
                                                              minFontSize:
                                                                  Constants
                                                                      .small,
                                                            )
                                                          : const AutoSizeText(
                                                              "Start Date",
                                                              softWrap: true,
                                                              overflow:
                                                                  TextOverflow
                                                                      .visible,
                                                              maxLines: 1,
                                                              minFontSize:
                                                                  Constants
                                                                      .small)),
                                                ),
                                                (tmpStart != null)
                                                    ? IconButton(
                                                        icon: const Icon(Icons
                                                            .clear_rounded),
                                                        selectedIcon:
                                                            const Icon(
                                                                Icons.clear),
                                                        onPressed: () =>
                                                            setState(() {
                                                          checkClose = true;
                                                          showDates
                                                              .remove(tmpStart);
                                                          tmpStart = null;
                                                        }),
                                                      )
                                                    : const SizedBox.shrink(),
                                              ]),
                                        ),
                                      ),
                                      const Flexible(
                                        flex: 1,
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  Constants.halfPadding),
                                          child: AutoSizeText("|",
                                              style: Constants.largeHeaderStyle,
                                              softWrap: false,
                                              overflow: TextOverflow.visible,
                                              maxLines: 1,
                                              minFontSize: Constants.small),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 10,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                                Constants.roundedCorners),
                                            border: Border.all(
                                                width: 2,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outlineVariant,
                                                strokeAlign: BorderSide
                                                    .strokeAlignOutside),
                                          ),
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Expanded(
                                                  child: TextButton(
                                                      onPressed: () =>
                                                          setState(() {
                                                            setStart = false;
                                                            tmpDue = tmpDue ??
                                                                DateTime.now();
                                                          }),
                                                      child: (null != tmpDue)
                                                          ? AutoSizeText(
                                                              Jiffy.parseFromDateTime(
                                                                      tmpDue!)
                                                                  .toLocal()
                                                                  .format(
                                                                      pattern:
                                                                          "yMMMMd"),
                                                              softWrap: false,
                                                              overflow:
                                                                  TextOverflow
                                                                      .visible,
                                                              maxLines: 1,
                                                              minFontSize:
                                                                  Constants
                                                                      .small,
                                                            )
                                                          : const AutoSizeText(
                                                              "Due Date",
                                                              softWrap: true,
                                                              overflow:
                                                                  TextOverflow
                                                                      .visible,
                                                              maxLines: 1,
                                                              minFontSize:
                                                                  Constants
                                                                      .small)),
                                                ),
                                                (tmpDue != null)
                                                    ? IconButton(
                                                        icon: const Icon(Icons
                                                            .clear_rounded),
                                                        selectedIcon:
                                                            const Icon(
                                                                Icons.clear),
                                                        onPressed: () =>
                                                            setState(() {
                                                          checkClose = true;
                                                          showDates
                                                              .remove(tmpDue);
                                                          tmpDue = null;
                                                        }),
                                                      )
                                                    : const SizedBox.shrink(),
                                              ]),
                                        ),
                                      ),
                                    ]),
                              ),

                              // Calendar view.
                              Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CalendarDatePicker2(
                                        config: CalendarDatePicker2Config(
                                          calendarType:
                                              CalendarDatePicker2Type.range,
                                          firstDate: DateTime(1970),
                                          lastDate: DateTime(3000),
                                        ),
                                        value: showDates,
                                        onValueChanged: (dates) {
                                          setState(() {
                                            if (dates.length > 1) {
                                              tmpStart = dates.first;
                                              tmpDue = dates.last;
                                            } else {
                                              (setStart)
                                                  ? tmpStart = dates.first
                                                  : tmpDue = dates.first;
                                            }
                                            showDates = dates;
                                          });
                                        }),
                                  ]),

                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            right: Constants.padding),
                                        child: FilledButton.tonalIcon(
                                            icon:
                                                const Icon(Icons.close_rounded),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            label: const AutoSizeText("Cancel",
                                                softWrap: false,
                                                overflow: TextOverflow.visible,
                                                maxLines: 1,
                                                minFontSize: Constants.small)),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            left: Constants.padding),
                                        child: FilledButton.icon(
                                          icon: const Icon(Icons.done_rounded),
                                          onPressed: () {
                                            setState(() {
                                              startDate = tmpStart;
                                              dueDate = tmpDue;

                                              if (null != startDate &&
                                                  null != dueDate &&
                                                  startDate!
                                                      .isAfter(dueDate!)) {
                                                startDate = dueDate;
                                              }
                                            });
                                            Navigator.pop(context);
                                          },
                                          label: const AutoSizeText("Done",
                                              softWrap: false,
                                              overflow: TextOverflow.visible,
                                              maxLines: 1,
                                              minFontSize: Constants.small),
                                        ),
                                      ),
                                    )
                                  ]),
                            ]),
                      )));
              // This is to update the main context after updating.
            }).then((_) => setState(() {}));
      },
    );
  }

  Column buildWeightTile({bool smallScreen = false}) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Constants.padding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: AutoSizeText("Energy Drain: ",
                  minFontSize: Constants.medium,
                  maxLines: 1,
                  softWrap: true,
                  style: Constants.hugeHeaderStyle),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Constants.innerPadding),
                child: buildDrainBar(
                    weight: (taskType == TaskType.small) ? weight : sumWeight,
                    context: context),
              ),
            ),
            //(smallScreen) ? const SizedBox.shrink() : const Spacer(),
          ],
        ),
      ),
      (taskType == TaskType.small)
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Icon(Icons.battery_full),
                Expanded(
                  child: Slider(
                    value: weight.toDouble(),
                    max: Constants.maxTaskWeight.toDouble(),
                    label: (weight > (Constants.maxTaskWeight / 2).floor())
                        ? " $weight ${Constants.lowBattery}"
                        : " $weight ${Constants.fullBattery}",
                    divisions: Constants.maxTaskWeight,
                    onChanged: (value) => setState(() {
                      checkClose = true;
                      weight = value.toInt();
                      realDuration = toDoProvider.calculateRealDuration(
                          weight: weight, duration: expectedDuration);
                    }),
                  ),
                ),
                const Icon(Icons.battery_1_bar),
              ],
            )
          : const SizedBox.shrink(),
    ]);
  }

  Widget buildDrainBar({required int weight, required BuildContext context}) {
    double max = (taskType == TaskType.small)
        ? Constants.maxTaskWeight.toDouble()
        : Constants.maxWeight.toDouble();
    double offset = weight.toDouble() / max;
    return Stack(alignment: Alignment.center, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Constants.padding),
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 3,
                  strokeAlign: BorderSide.strokeAlignCenter),
              shape: BoxShape.rectangle,
              // TODO: This should probably move to constants class.
              borderRadius: const BorderRadius.all(Radius.circular(10))),
          child: Padding(
            padding: const EdgeInsets.all(Constants.halfPadding),
            child: LinearProgressIndicator(
                color: (offset < 0.8) ? null : Colors.redAccent,
                minHeight: 50,
                value: 1 - offset,
                // Possibly remove
                borderRadius: const BorderRadius.all(Radius.circular(10))),
          ),
        ),
      ),
      Align(
          alignment: Alignment.centerRight,
          child: Container(
              height: 40,
              width: 8,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(2)),
                color: Theme.of(context).colorScheme.outline,
              ))),
      AutoSizeText("$weight",
          minFontSize: Constants.large,
          softWrap: false,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: Constants.hugeHeaderStyle),
    ]);
  }

  ReorderableListView buildReorderableSubTasks(
      {bool smallScreen = false,
      ScrollPhysics physics = const BouncingScrollPhysics()}) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      physics: physics,
      shrinkWrap: true,
      itemCount: min(Constants.numTasks[taskType]!, shownTasks),
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          checkClose = true;
          if (oldIndex < newIndex) {
            newIndex--;
          }
          SubTask st = subTasks.removeAt(oldIndex);
          subTasks.insert(newIndex, st);
          TextEditingController ct =
              subTaskEditingController.removeAt(oldIndex);
          // ct.value = ct.value.copyWith(text: st.name);
          subTaskEditingController.insert(newIndex, ct);
        });
      },
      itemBuilder: (BuildContext context, int index) {
        return CheckboxListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: Constants.innerPadding),
            key: ValueKey(index),
            checkboxShape: const CircleBorder(),
            controlAffinity: ListTileControlAffinity.leading,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                    Radius.circular(Constants.roundedCorners))),
            title: Row(
              children: [
                IconButton(
                  icon: Constants.batteryIcons[subTasks[index].weight]!,
                  selectedIcon:
                      Constants.selectedBatteryIcons[subTasks[index].weight]!,
                  onPressed: () {
                    showModalBottomSheet<void>(
                        showDragHandle: true,
                        context: context,
                        builder: (BuildContext context) {
                          return StatefulBuilder(
                            builder: (BuildContext context,
                                    void Function(void Function()) setState) =>
                                Center(
                                    heightFactor: 1,
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // const Icon(Icons.drag_handle_rounded),
                                          const Text("Step Drain",
                                              style: Constants.headerStyle),
                                          Padding(
                                              padding: const EdgeInsets.all(
                                                  Constants.padding),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,
                                                children: [
                                                  const Icon(Icons
                                                      .battery_full_rounded),
                                                  Expanded(
                                                    child: Slider(
                                                      value: subTasks[index]
                                                          .weight
                                                          .toDouble(),
                                                      max: Constants
                                                          .maxTaskWeight
                                                          .toDouble(),
                                                      label: (subTasks[index]
                                                                  .weight >
                                                              (Constants.maxTaskWeight /
                                                                      2)
                                                                  .floor())
                                                          ? " ${subTasks[index].weight} ${Constants.lowBattery}"
                                                          : " ${subTasks[index].weight} ${Constants.fullBattery}",
                                                      divisions: Constants
                                                          .maxTaskWeight,
                                                      onChanged: (value) =>
                                                          setState(() {
                                                        checkClose = true;
                                                        subTasks[index].weight =
                                                            value.toInt();
                                                      }),
                                                    ),
                                                  ),
                                                  const Icon(Icons
                                                      .battery_1_bar_rounded),
                                                ],
                                              )),
                                        ])),
                          );
                        }).whenComplete(() => setState(() {
                          checkClose = true;
                          sumWeight = toDoProvider.calculateWeight(
                              subTasks: List.generate(
                                  Constants.numTasks[taskType]!,
                                  (index) => subTasks[index]));
                          realDuration = toDoProvider.calculateRealDuration(
                              weight: sumWeight, duration: expectedDuration);
                        }));
                  },
                ),
                Expanded(
                  child: AutoSizeTextField(
                      controller: subTaskEditingController[index],
                      maxLines: 1,
                      minFontSize: Constants.small,
                      decoration: const InputDecoration.collapsed(
                        hintText: "Step name",
                      ),
                      onChanged: (value) {
                        subTasks[index].name = value;
                        subTaskEditingController[index].value =
                            subTaskEditingController[index].value.copyWith(
                                  text: value,
                                  selection: TextSelection.collapsed(
                                      offset: value.length),
                                );
                      }),
                ),
              ],
            ),
            value: subTasks[index].completed,
            onChanged: (bool? value) => setState(() {
                  checkClose = true;
                  subTasks[index].completed = value!;
                }),

            // Delete Subtask
            secondary: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Constants.innerPadding),
                  child: IconButton(
                      icon: const Icon(Icons.delete_rounded),
                      onPressed: () => setState(() {
                            SubTask st = subTasks.removeAt(index);
                            st = SubTask();
                            subTasks.add(st);
                            TextEditingController ct =
                                subTaskEditingController.removeAt(index);
                            ct.value = ct.value.copyWith(text: st.name);
                            subTaskEditingController.add(ct);

                            shownTasks--;
                            shownTasks = max(shownTasks, 0);
                            sumWeight = toDoProvider.calculateWeight(
                                subTasks: List.generate(
                                    Constants.numTasks[taskType]!,
                                    (index) => subTasks[index]));
                          })),
                ),
                ReorderableDragStartListener(
                    index: index, child: const Icon(Icons.drag_handle_rounded))
              ],
            ));
      },
    );
  }

  Row buildNameTile({bool smallScreen = false}) {
    return Row(
      children: [
        Transform.scale(
          scale: (smallScreen)
              ? Constants.largeCheckboxMinScale
              : Constants.largeCheckboxScale,
          child: Checkbox(
              splashRadius: 15,
              value: completed,
              onChanged: (bool? value) => setState(() {
                    checkClose = true;
                    completed = value!;
                  }),
              shape: const CircleBorder()),
        ),
        Expanded(
            child: Padding(
          padding: EdgeInsets.all(
              (smallScreen) ? Constants.halfPadding : Constants.padding),
          child: buildTaskName(smallScreen: smallScreen),
        )),
      ],
    );
  }

  ListTile buildMyDayTile() {
    return ListTile(
        title: AutoSizeText(
          (myDay)
              ? "Added to my Day"
              : (userProvider.myDayTotal + weight <=
                      (userProvider.curUser?.bandwidth ??
                          Constants.maxBandwidth))
                  ? "Add to My Day?"
                  : "Don't overload yourself, you deserve a rest",
          overflow: TextOverflow.visible,
          softWrap: true,
          minFontSize: Constants.medium,
          maxLines: 2,
        ),
        leading: (myDay)
            ? IconButton.filledTonal(
                icon: const Icon(Icons.wb_sunny),
                onPressed: () => setState(() {
                      checkClose = true;
                      myDay = !myDay;
                    }))
            : (userProvider.myDayTotal + weight <=
                    (userProvider.curUser?.bandwidth ?? Constants.maxBandwidth)
                ? IconButton.outlined(
                    icon: const Icon(Icons.wb_sunny_outlined),
                    onPressed: () => setState(() {
                          checkClose = true;
                          myDay = !myDay;
                        }))
                : const Icon(Icons.block_rounded)));
  }

  SegmentedButton<Priority> buildPriorityTile({bool smallScreen = false}) {
    return SegmentedButton<Priority>(
        selectedIcon: const Icon(Icons.flag_circle_rounded),
        style: ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          side: MaterialStatePropertyAll<BorderSide>(BorderSide(
            width: 2,
            color: Theme.of(context).colorScheme.outlineVariant,
          )),
        ),
        segments: Priority.values
            .map((Priority type) => ButtonSegment<Priority>(
                icon: Constants.priorityIcon[type],
                value: type,
                label: Text("${toBeginningOfSentenceCase(type.name)}",
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: (smallScreen) ? Constants.minBodyText : null)))
            .toList(growable: false),
        selected: <Priority>{priority},
        onSelectionChanged: (Set<Priority> newSelection) => setState(() {
              checkClose = true;
              priority = newSelection.first;
            }));
  }

  AutoSizeTextField buildDescriptionTile({bool smallScreen = false}) {
    return AutoSizeTextField(
        controller: descriptionEditingController,
        maxLines: Constants.descripMaxLinesBeforeScroll,
        minLines: (smallScreen)
            ? Constants.descripMinLinesMobile
            : Constants.descripMinLinesDesktop,
        minFontSize: Constants.medium,
        decoration: InputDecoration(
          isDense: smallScreen,
          contentPadding: const EdgeInsets.all(Constants.innerPadding),
          hintText: "Description",
          enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(
                  Radius.circular(Constants.roundedCorners)),
              borderSide: BorderSide(
                width: 2,
                color: Theme.of(context).colorScheme.outlineVariant,
                strokeAlign: BorderSide.strokeAlignOutside,
              )),
          border: const OutlineInputBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(Constants.roundedCorners)),
              borderSide: BorderSide(
                strokeAlign: BorderSide.strokeAlignOutside,
              )),
        ));
  }

  ListTile buildDurationTile(
      {required BuildContext context, bool smallScreen = false}) {
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(Constants.roundedCorners))),
      title: (expectedDuration > 0)
          ? Row(
              children: [
                Flexible(
                  child: AutoSizeText(
                      (smallScreen)
                          ? Duration(seconds: expectedDuration)
                              .toString()
                              .split(".")
                              .first
                          : "Expected: ${Duration(seconds: expectedDuration).toString().split(".").first}",
                      overflow: TextOverflow.visible,
                      minFontSize: Constants.small,
                      maxLines: 2,
                      softWrap: true),
                ),
                const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: Constants.innerPadding),
                  child: Icon(
                    Icons.timer_rounded,
                  ),
                ),
                Flexible(
                  child: AutoSizeText(
                      (smallScreen)
                          ? Duration(seconds: realDuration)
                              .toString()
                              .split(".")
                              .first
                          : "Actual: ${Duration(seconds: realDuration).toString().split(".").first}",
                      overflow: TextOverflow.visible,
                      minFontSize: Constants.small,
                      maxLines: 2,
                      softWrap: true),
                ),
              ],
            )
          : const AutoSizeText("Expected Task Duration: ",
              overflow: TextOverflow.visible,
              minFontSize: Constants.small,
              maxLines: 2,
              softWrap: true),
      trailing: (expectedDuration > 0)
          ? IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () => setState(() {
                    checkClose = true;
                    expectedDuration = 0;
                    realDuration = 0;
                  }))
          : const SizedBox.shrink(),
      onTap: () => showDialog<int>(
          context: context,
          builder: (BuildContext context) {
            int time = expectedDuration;
            int hours = time ~/ 3600;
            time %= 3600;
            int minutes = time ~/ 60;
            time %= 60;
            int seconds = time;

            return StatefulBuilder(
              builder: (BuildContext context,
                      void Function(void Function()) setState) =>
                  Dialog(
                      child: Padding(
                          padding: const EdgeInsets.all(Constants.innerPadding),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                        child: AutoSizeText(
                                          "Expected Duration",
                                          style: Constants.headerStyle,
                                          softWrap: true,
                                          overflow: TextOverflow.visible,
                                          maxLines: 2,
                                          minFontSize: Constants.medium,
                                        ),
                                      )
                                    ]),
                                const Flexible(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Flexible(
                                          child: AutoSizeText(
                                        "Hours | Minutes | Seconds ",
                                        style: Constants.largeHeaderStyle,
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                        maxLines: 1,
                                        minFontSize: Constants.large,
                                      )),
                                      Flexible(
                                        child: FittedBox(
                                            fit: BoxFit.fill,
                                            child: Icon(Icons.timer_outlined,
                                                size: Constants.medIconSize)),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: NumberPicker(
                                        textStyle:
                                            Constants.numberPickerSecondary(
                                                context: context),
                                        selectedTextStyle:
                                            Constants.numberPickerPrimary(
                                                context: context),
                                        minValue: 0,
                                        maxValue: 100,
                                        value: hours,
                                        haptics: true,
                                        onChanged: (value) {
                                          SemanticsService.announce(
                                              "$value, hours",
                                              Directionality.of(context));
                                          setState(() => hours = value);
                                        },
                                      ),
                                    ),
                                    const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: Constants.padding),
                                        child: Text(":",
                                            style: Constants.timeColon)),
                                    Expanded(
                                      child: NumberPicker(
                                        textStyle:
                                            Constants.numberPickerSecondary(
                                                context: context),
                                        selectedTextStyle:
                                            Constants.numberPickerPrimary(
                                                context: context),
                                        minValue: 0,
                                        maxValue: 59,
                                        value: minutes,
                                        haptics: true,
                                        onChanged: (value) {
                                          SemanticsService.announce(
                                              "$value, minutes",
                                              Directionality.of(context));
                                          setState(() => minutes = value);
                                        },
                                      ),
                                    ),
                                    const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: Constants.padding),
                                        child: Text(":",
                                            style: Constants.timeColon)),
                                    Expanded(
                                      child: NumberPicker(
                                        textStyle:
                                            Constants.numberPickerSecondary(
                                                context: context),
                                        selectedTextStyle:
                                            Constants.numberPickerPrimary(
                                                context: context),
                                        minValue: 0,
                                        maxValue: 59,
                                        value: seconds,
                                        haptics: true,
                                        onChanged: (value) {
                                          SemanticsService.announce(
                                              "$value, seconds",
                                              Directionality.of(context));
                                          setState(() => seconds = value);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: Constants.padding),
                                          child: FilledButton.tonalIcon(
                                              icon: const Icon(
                                                  Icons.close_rounded),
                                              onPressed: () =>
                                                  Navigator.pop(context, 0),
                                              label: const AutoSizeText(
                                                  "Cancel",
                                                  softWrap: false,
                                                  overflow:
                                                      TextOverflow.visible,
                                                  maxLines: 1,
                                                  minFontSize:
                                                      Constants.small)),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              left: Constants.padding),
                                          child: FilledButton.icon(
                                            icon:
                                                const Icon(Icons.done_rounded),
                                            onPressed: () {
                                              Navigator.pop(
                                                  context,
                                                  (hours * 3600) +
                                                      (minutes * 60) +
                                                      seconds);
                                            },
                                            label: const AutoSizeText("Done",
                                                softWrap: false,
                                                overflow: TextOverflow.visible,
                                                maxLines: 1,
                                                minFontSize: Constants.small),
                                          ),
                                        ),
                                      )
                                    ])
                              ]))),
            );
          }).then((value) {
        setState(() {
          checkClose = true;
          expectedDuration = value ?? expectedDuration;
          realDuration = toDoProvider.calculateRealDuration(
              weight: (taskType == TaskType.small) ? weight : sumWeight,
              duration: expectedDuration);
        });
      }),
    );
  }

  AutoSizeTextField buildTaskName({bool smallScreen = false}) {
    return AutoSizeTextField(
      maxLines: 1,
      minFontSize: Constants.medium,
      decoration: InputDecoration(
        isDense: smallScreen,
        suffixIcon: (name != "")
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  checkClose = true;
                  nameEditingController.clear();
                  setState(() => name = "");
                })
            : null,
        contentPadding: const EdgeInsets.all(Constants.innerPadding),
        enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(
                Radius.circular(Constants.roundedCorners)),
            borderSide: BorderSide(
              width: 2,
              color: Theme.of(context).colorScheme.outlineVariant,
              strokeAlign: BorderSide.strokeAlignOutside,
            )),
        border: const OutlineInputBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.roundedCorners)),
            borderSide: BorderSide(
              strokeAlign: BorderSide.strokeAlignOutside,
            )),
        hintText: "Task name",
        errorText: nameErrorText,
      ),
      controller: nameEditingController,
    );
  }

  IconButton buildCloseButton({required BuildContext context}) {
    return IconButton(
        onPressed: () {
          if (checkClose) {
            showModalBottomSheet<bool>(
                showDragHandle: true,
                context: context,
                builder: (BuildContext context) {
                  return Center(
                      heightFactor: 1,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(Constants.padding),
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.pop(context, true);
                                },
                                label: const Text("Discard"),
                                icon: const Icon(Icons.delete_forever_outlined),
                              ),
                            ),
                            Padding(
                                padding:
                                    const EdgeInsets.all(Constants.padding),
                                child: FilledButton.tonalIcon(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  label: const Text("Continue Editing"),
                                  icon: const Icon(
                                    Icons.edit_note_rounded,
                                  ),
                                ))
                          ]));
                }).then((willDiscard) {
              if (willDiscard ?? false) {
                Navigator.pop(context);
              }
            });
            setState(() => checkClose = false);
          } else {
            Navigator.pop(context);
          }
        },
        icon: const Icon(Icons.close_rounded),
        selectedIcon: const Icon(Icons.close_rounded));
  }

  SegmentedButton<TaskType> buildTaskTypeButton({bool smallScreen = false}) {
    return SegmentedButton<TaskType>(
        style: ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          side: MaterialStatePropertyAll<BorderSide>(BorderSide(
            width: 2,
            color: Theme.of(context).colorScheme.outlineVariant,
          )),
        ),
        segments: TaskType.values
            .map((TaskType type) => ButtonSegment<TaskType>(
                value: type,
                label: Text("${toBeginningOfSentenceCase(type.name)}",
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: (smallScreen) ? Constants.minBodyText : null)))
            .toList(growable: false),
        selected: <TaskType>{taskType},
        onSelectionChanged: (Set<TaskType> newSelection) {
          TaskType newType = newSelection.first;
          if (taskType != newType) {
            setState(() {
              checkClose = true;
              taskType = newSelection.first;
              realDuration = toDoProvider.calculateRealDuration(
                  weight: (taskType == TaskType.small) ? weight : sumWeight,
                  duration: expectedDuration);
            });
          }
        });
  }

  FutureBuilder<List<Group>> buildGroupList(
      {required Future<List<Group>> searchFuture,
      required SearchController controller}) {
    return FutureBuilder(
        future: searchFuture,
        builder: (BuildContext context, AsyncSnapshot<List<Group>> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final List<Group>? groups = snapshot.data;
            if (null != groups) {
              return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groups.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                        title: AutoSizeText(groups[index].name),
                        onTap: () => handleGroupSelection(
                            group: groups[index], controller: controller));
                  });
            }
            // This is what to render if no data.
            return const SizedBox.shrink();
          }
          return const Padding(
            padding: EdgeInsets.all(Constants.padding),
            child: CircularProgressIndicator(),
          );
        });
  }

  SearchAnchor buildGroupBar() {
    return SearchAnchor.bar(
        isFullScreen: false,
        barSide: MaterialStatePropertyAll(BorderSide(
            width: 2,
            strokeAlign: BorderSide.strokeAlignOutside,
            color: Theme.of(context).colorScheme.outlineVariant)),
        barBackgroundColor: const MaterialStatePropertyAll(Colors.transparent),
        barElevation: const MaterialStatePropertyAll(0),
        viewConstraints: const BoxConstraints(
            maxHeight: Constants.maxSearchHeightBeforeScroll),
        barHintText: "Search Groups",
        searchController: groupEditingController,
        suggestionsBuilder: (context, SearchController controller) {
          if (controller.text.isEmpty) {
            if (searchHistory.isNotEmpty) {
              return searchHistory
                  .map((MapEntry<String, int> groupData) => ListTile(
                        leading: const Icon(Icons.history_rounded),
                        title: AutoSizeText(
                          groupData.key,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                        ),
                        onTap: () => handleHistorySelection(
                            groupData: groupData, controller: controller),
                      ))
                  .toList();
            }
            final searchFuture = groupProvider.mostRecent(limit: 5);
            return [
              buildGroupList(searchFuture: searchFuture, controller: controller)
            ];
          }
          // Search query iterable.
          final searchFuture =
              groupProvider.searchGroups(searchString: controller.text);
          return [
            buildGroupList(searchFuture: searchFuture, controller: controller)
          ];
        });
  }
}
