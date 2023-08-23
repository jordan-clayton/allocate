import "dart:math";

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
import "../../../model/task/todo.dart";
import "../../../providers/group_provider.dart";
import "../../../providers/todo_provider.dart";
import "../../../providers/user_provider.dart";
import "../../../util/constants.dart";
import "../../../util/enums.dart";
import "../../../util/exceptions.dart";
import "../../../util/numbers.dart";
import "../../widgets/paddedDivider.dart";

class UpdateToDoScreen extends StatefulWidget {
  const UpdateToDoScreen({Key? key}) : super(key: key);

  @override
  State<UpdateToDoScreen> createState() => _UpdateToDoScreen();
}

class _UpdateToDoScreen extends State<UpdateToDoScreen> {
  late bool checkClose;
  late bool checkDelete;
  late final UserProvider userProvider;
  late final ToDoProvider toDoProvider;
  late final GroupProvider groupProvider;

  // Cache for repeating events
  late final ToDo prevToDo;

  // Scrolling
  late final ScrollController mainScrollController;
  late final ScrollController subScrollControllerLeft;
  late final ScrollController subScrollControllerRight;
  late final ScrollPhysics scrollPhysics;

  // Name
  late final TextEditingController nameEditingController;
  String? nameErrorText;

  // Group
  late final TextEditingController groupEditingController;
  late List<MapEntry<String, int>> searchHistory;

  // Description
  late final TextEditingController descriptionEditingController;

  final MaterialStateProperty<Icon?> completedIcon = MaterialStateProperty.resolveWith(
      (states) => (states.contains(MaterialState.selected) ? const Icon(Icons.task_alt) : null));

  // Repeat
  late TextEditingController repeatSkipEditingController;

  late final List<TextEditingController> subTaskEditingController;
  late int shownTasks;

  // This is just a convenience method to avoid extra typing
  ToDo get toDo => toDoProvider.curToDo!;

  @override
  Future<void> initState() async {
    super.initState();
    initializeProviders();
    initializeParams();
    await initializeControllers();
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

  void initializeParams() {
    prevToDo = toDo.copy();
    shownTasks = toDo.subTasks.indexOf(SubTask()) + 1;
  }

  Future<void> initializeControllers() async {
    mainScrollController = ScrollController();
    subScrollControllerLeft = ScrollController();
    subScrollControllerRight = ScrollController();
    scrollPhysics = const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());

    nameEditingController = TextEditingController(text: toDo.name);
    nameEditingController.addListener(() {
      checkClose = true;
      String newText = nameEditingController.text;
      SemanticsService.announce(newText, Directionality.of(context));
      toDo.name = newText;
    });

    String? groupText;
    if (null != toDo.groupID) {
      await groupProvider.getGroupByID(id: toDo.groupID!).then((group) => groupText = group?.name);
    }

    groupEditingController = TextEditingController(text: groupText);
    groupEditingController.addListener(() {
      checkClose = true;
      String newText = nameEditingController.text;
      SemanticsService.announce(newText, Directionality.of(context));
    });

    descriptionEditingController = TextEditingController(text: toDo.description);
    descriptionEditingController.addListener(() {
      checkClose = true;
      String newText = descriptionEditingController.text;
      SemanticsService.announce(newText, Directionality.of(context));
      toDo.description = newText;
    });

    repeatSkipEditingController = TextEditingController(text: toDo.repeatSkip.toString());
    repeatSkipEditingController.addListener(() {
      checkClose = true;
      String newText = descriptionEditingController.text;
      SemanticsService.announce(newText, Directionality.of(context));
      toDo.repeatSkip = int.tryParse(newText) ?? toDo.repeatSkip;
      toDo.repeatSkip = max(toDo.repeatSkip, 1);
    });

    subTaskEditingController = List.generate(
        toDo.subTasks.length, (i) => TextEditingController(text: toDo.subTasks[i].name));
    for (int i = 0; i < subTaskEditingController.length; i++) {
      subTaskEditingController[i].addListener(() {
        checkClose = true;
        String newText = subTaskEditingController[i].text;
        SemanticsService.announce(newText, Directionality.of(context));
      });
    }
  }

  void handleGroupSelection({required Group group, required SearchController controller}) {
    // Controller logic
    controller.closeView(group.name);
    setState(() {
      checkClose = true;
      toDo.groupID = group.id;
      if (searchHistory.length >= Constants.historyLength) {
        searchHistory.removeLast();
      }

      searchHistory.insert(0, MapEntry(group.name, group.id));
    });
  }

  void handleHistorySelection(
      {required MapEntry<String, int> groupData, required SearchController controller}) {
    controller.closeView(groupData.key);
    setState(() {
      checkClose = true;
      toDo.groupID = groupData.value;
    });
  }

  bool validateData() {
    bool valid = true;
    if (groupEditingController.text.isEmpty) {
      toDo.groupID = null;
    }
    if (nameEditingController.text.isEmpty) {
      valid = false;
      nameErrorText = "Enter Task Name";
    }
    if (toDo.frequency == Frequency.custom) {
      if (!toDo.repeatDays.contains(true)) {
        for (int i = 0; i < toDo.repeatDays.length; i++) {
          toDo.repeatDays[i] = prevToDo.repeatDays[i];
        }
      }
    } else {
      toDo.customFreq = CustomFrequency.weekly;
    }

    return valid;
  }

  Icon getBatteryIcon({required int weight, required bool selected}) {
    // Icon is scaled for sum-weight.
    weight = (toDo.taskType == TaskType.small)
        ? weight
        : remap(
                x: weight,
                inMin: 0,
                inMax: (Constants.maxTaskWeight * Constants.numTasks[toDo.taskType]!),
                outMin: 0,
                outMax: 5)
            .toInt();

    if (selected) {
      return Constants.selectedBatteryIcons[weight]!;
    }
    return Constants.batteryIcons[weight]!;
  }

  // This should return a dialog widget.
  @override
  Widget build(BuildContext context) {
    final Color errorColor = Theme.of(context).colorScheme.error;

    bool largeScreen = (MediaQuery.of(context).size.width >= Constants.largeScreen);
    bool smallScreen = (MediaQuery.of(context).size.width <= Constants.smallScreen);
    return (largeScreen)
        ? buildDesktopDialog(context, smallScreen, errorColor)
        : buildMobileDialog(context, smallScreen, errorColor);
  }

  Dialog buildDesktopDialog(BuildContext context, bool smallScreen, Color errorColor) {
    return Dialog(
      insetPadding: const EdgeInsets.all(Constants.outerDialogPadding),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: Constants.maxLandscapeDialogHeight),
        child: Padding(
          padding: const EdgeInsets.all(Constants.padding),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title && Close Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Constants.padding),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Flexible(
                      child: AutoSizeText(
                        "Edit Task",
                        overflow: TextOverflow.visible,
                        style: Constants.headerStyle,
                        minFontSize: Constants.medium,
                        softWrap: true,
                        maxLines: 1,
                      ),
                    ),
                    (toDo.expectedDuration > 0)
                        ? Flexible(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Tooltip(
                                    message: "Expected Task Duration",
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: Constants.padding),
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
                                                Duration(seconds: toDo.expectedDuration)
                                                    .toString()
                                                    .split(".")
                                                    .first,
                                                minFontSize: Constants.medium,
                                                overflow: TextOverflow.visible,
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
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: Constants.padding),
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
                                                Duration(seconds: toDo.realDuration)
                                                    .toString()
                                                    .split(".")
                                                    .first,
                                                minFontSize: Constants.medium,
                                                overflow: TextOverflow.visible,
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
                    buildCloseButton(context),
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
                              padding: const EdgeInsets.symmetric(horizontal: Constants.padding),
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
                                  child: buildNameTile(smallScreen: smallScreen),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: Constants.padding),
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
                                // Subtasks
                                (toDo.taskType != TaskType.small)
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: Constants.innerPadding),
                                        child: Card(
                                          clipBehavior: Clip.antiAlias,
                                          elevation: 0,
                                          color: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                              side: BorderSide(
                                                  color: Theme.of(context).colorScheme.outline,
                                                  strokeAlign: BorderSide.strokeAlignInside),
                                              borderRadius: const BorderRadius.all(
                                                  Radius.circular(Constants.roundedCorners))),
                                          child: ExpansionTile(
                                            title: const AutoSizeText("Steps",
                                                maxLines: 1,
                                                overflow: TextOverflow.visible,
                                                softWrap: false,
                                                minFontSize: Constants.small),
                                            collapsedShape: const RoundedRectangleBorder(
                                                side: BorderSide(
                                                    strokeAlign: BorderSide.strokeAlignOutside),
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(Constants.roundedCorners))),
                                            shape: const RoundedRectangleBorder(
                                                side: BorderSide(
                                                    strokeAlign: BorderSide.strokeAlignOutside),
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(Constants.roundedCorners))),
                                            children: [
                                              buildSubTasksList(
                                                  smallScreen: smallScreen, physics: scrollPhysics),
                                              (shownTasks < Constants.numTasks[toDo.taskType]!)
                                                  ? ListTile(
                                                      leading: const Icon(Icons.add_outlined),
                                                      title: const AutoSizeText("Add a step",
                                                          maxLines: 1,
                                                          overflow: TextOverflow.visible,
                                                          softWrap: false,
                                                          minFontSize: Constants.small),
                                                      onTap: () => setState(() {
                                                            shownTasks++;
                                                            shownTasks = min(
                                                                shownTasks, Constants.maxNumTasks);
                                                          }))
                                                  : const SizedBox.shrink(),
                                            ],
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),

                                const PaddedDivider(padding: Constants.padding),
                                // My Day
                                buildMyDayTile(),
                                const PaddedDivider(padding: Constants.padding),
                                // Priority
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: Constants.padding),
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
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: Constants.padding),
                                  child: buildPriorityTile(smallScreen: smallScreen),
                                ),

                                // const Padding(
                                //   padding: EdgeInsets.symmetric(vertical: 8.0),
                                //   child: PaddedDivider(padding: Constants.innerPadding),
                                // )
                              ]),
                        ),
                        Expanded(
                          child: ListView(
                              controller: subScrollControllerRight,
                              physics: scrollPhysics,
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(horizontal: Constants.padding),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(Constants.padding),
                                  child: buildGroupBar(),
                                ),

                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: Constants.padding),
                                  child: PaddedDivider(padding: Constants.innerPadding),
                                ),

                                // Description
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: Constants.padding),
                                  child: buildDescriptionTile(smallScreen: smallScreen),
                                ),

                                const PaddedDivider(padding: Constants.innerPadding),
                                // Expected Duration / RealDuration -> Show status, on click, open a dialog.
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: Constants.padding),
                                  child: buildDurationTile(context, smallScreen: smallScreen),
                                ),

                                const PaddedDivider(padding: Constants.innerPadding),
                                // DateTime -> Show status, on click, open a dialog.
                                //startDate
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: Constants.padding),
                                  child: buildDateTile(context),
                                ),

                                const PaddedDivider(padding: Constants.innerPadding),
                                // Time
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: Constants.padding),
                                  child: buildTimeTile(),
                                ),

                                const PaddedDivider(padding: Constants.innerPadding),
                                // Repeatable Stuff -> Show status, on click, open a dialog.
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: Constants.padding),
                                  child: buildRepeatableTile(context, smallScreen: smallScreen),
                                ),
                              ]),
                        )
                      ]),
                ),

                const PaddedDivider(padding: Constants.padding),
                // Create Button - could be a stack
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Constants.padding),
                  child: buildCreateButton(context, errorColor),
                )
              ]),
        ),
      ),
    );
  }

  IconButton buildCloseButton(BuildContext context) {
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
                            // const Icon(Icons.drag_handle_rounded),
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
                                padding: const EdgeInsets.all(Constants.padding),
                                child: FilledButton.tonalIcon(
                                  onPressed: () => Navigator.pop(context, false),
                                  label: const Text("Continue Editing"),
                                  icon: const Icon(
                                    Icons.edit_note_outlined,
                                  ),
                                ))
                          ]));
                }).then((willDiscard) {
              if (willDiscard ?? false) {
                // If discarding changes, reset back to the cached ToDo.
                toDoProvider.curToDo = prevToDo;
                Navigator.pop(context);
              }
            });
            setState(() => checkClose = false);
          } else {
            Navigator.pop(context);
          }
        },
        icon: const Icon(Icons.close_outlined),
        selectedIcon: const Icon(Icons.close));
  }

  Row buildNameTile({bool smallScreen = false}) {
    return Row(
      children: [
        Transform.scale(
          scale: (smallScreen) ? Constants.largeCheckboxMinScale : Constants.largeCheckboxScale,
          child: Checkbox(
              splashRadius: 15,
              value: toDo.completed,
              onChanged: (bool? value) => setState(() {
                    checkClose = true;
                    toDo.completed = value!;
                  }),
              shape: const CircleBorder()),
        ),
        Expanded(
            child: Padding(
          padding: const EdgeInsets.all(Constants.padding),
          child: buildTaskName(smallScreen: smallScreen),
        )),
      ],
    );
  }

  AutoSizeTextField buildTaskName({bool smallScreen = false, bool largeScreen = false}) {
    return AutoSizeTextField(
      maxLines: 1,
      minFontSize: Constants.medium,
      decoration: InputDecoration(
        isDense: smallScreen,
        suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              nameEditingController.clear();
              setState(() => toDo.name = "");
            }),
        contentPadding: const EdgeInsets.all(Constants.innerPadding),
        border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(Constants.roundedCorners)),
            borderSide: BorderSide(
              strokeAlign: BorderSide.strokeAlignOutside,
            )),
        hintText: "Task name",
        errorText: nameErrorText,
      ),
      controller: nameEditingController,
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
            const Expanded(
              child: AutoSizeText("Task Strain",
                  minFontSize: Constants.medium,
                  maxLines: 1,
                  softWrap: true,
                  style: Constants.headerStyle),
            ),
            Expanded(
              child: Tooltip(
                  message: "How draining is this task?",
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: FittedBox(
                      fit: BoxFit.fitHeight,
                      child: Transform.rotate(
                          angle: -pi / 2,
                          child: getBatteryIcon(weight: toDo.weight, selected: false)),
                    ),
                  )),
            ),
            (smallScreen) ? const SizedBox.shrink() : const Spacer(),
          ],
        ),
      ),
      (toDo.taskType == TaskType.small)
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Icon(Icons.battery_full),
                Expanded(
                  child: Slider(
                    value: toDo.weight.toDouble(),
                    max: Constants.maxTaskWeight.toDouble(),
                    label: (toDo.weight > (Constants.maxTaskWeight / 2).floor())
                        ? " ${toDo.weight} ${Constants.lowBattery}"
                        : " ${toDo.weight} ${Constants.fullBattery}",
                    divisions: Constants.maxTaskWeight,
                    onChanged: (value) => setState(() {
                      checkClose = true;
                      toDo.weight = value.toInt();
                      toDo.realDuration = toDoProvider.calculateRealDuration(
                          weight: toDo.weight, duration: toDo.expectedDuration);
                    }),
                  ),
                ),
                const Icon(Icons.battery_1_bar),
              ],
            )
          : const SizedBox.shrink(),
    ]);
  }

  ListView buildSubTasksList(
      {bool smallScreen = false, ScrollPhysics physics = const BouncingScrollPhysics()}) {
    return ListView.separated(
      // Possibly need scroll controller.
      physics: physics,
      shrinkWrap: true,
      itemCount: min(Constants.numTasks[toDo.taskType]!, shownTasks),
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (BuildContext context, int index) {
        return CheckboxListTile(
            checkboxShape: const CircleBorder(),
            controlAffinity: ListTileControlAffinity.leading,
            shape: const CircleBorder(),
            title: Row(
              children: [
                IconButton(
                  icon: Constants.batteryIcons[toDo.subTasks[index].weight]!,
                  selectedIcon: Constants.selectedBatteryIcons[toDo.subTasks[index].weight]!,
                  onPressed: () {
                    showModalBottomSheet<void>(
                        showDragHandle: true,
                        context: context,
                        builder: (BuildContext context) {
                          return StatefulBuilder(
                            builder: (context, setState) => Center(
                                heightFactor: 1,
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // const Icon(Icons.drag_handle_rounded),
                                      const Text("Task Strain", style: Constants.headerStyle),
                                      Padding(
                                          padding: const EdgeInsets.all(Constants.padding),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              const Icon(Icons.battery_full),
                                              Expanded(
                                                child: Slider(
                                                  value: toDo.subTasks[index].weight.toDouble(),
                                                  max: Constants.maxTaskWeight.toDouble(),
                                                  label: (toDo.subTasks[index].weight >
                                                          (Constants.maxTaskWeight / 2).floor())
                                                      ? " ${toDo.subTasks[index].weight} ${Constants.lowBattery}"
                                                      : " ${toDo.subTasks[index].weight} ${Constants.fullBattery}",
                                                  divisions: Constants.maxTaskWeight,
                                                  onChanged: (value) => setState(() {
                                                    checkClose = true;
                                                    toDo.subTasks[index].weight = value.toInt();
                                                  }),
                                                ),
                                              ),
                                              const Icon(Icons.battery_1_bar),
                                            ],
                                          )),
                                    ])),
                          );
                        }).whenComplete(() => setState(() {
                          // TODO: refactor, there's no "Calculate Weight yet".
                          toDo.weight = toDo.subTasks.fold(0, (p, c) => p + c.weight);
                          toDo.realDuration = toDoProvider.calculateRealDuration(
                              weight: toDo.weight, duration: toDo.expectedDuration);
                        }));
                  },
                ),
                Expanded(
                  child: AutoSizeTextField(
                      controller: subTaskEditingController[index],
                      maxLines: 1,
                      minFontSize: Constants.small,
                      decoration: InputDecoration(
                        isDense: smallScreen,
                        hintText: "Step name",
                      ),
                      onChanged: (value) {
                        toDo.subTasks[index].name = value;
                        subTaskEditingController[index].value =
                            subTaskEditingController[index].value.copyWith(
                                  text: value,
                                  selection: TextSelection.collapsed(offset: value.length),
                                );
                      }),
                ),
              ],
            ),
            value: toDo.subTasks[index].completed,
            onChanged: (bool? value) => setState(() {
                  checkClose = true;
                  toDo.subTasks[index].completed = value!;
                }),

            // Delete Subtask
            secondary: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => setState(() {
                      // TEST: potential bug
                      toDo.subTasks.setRange(index, toDo.subTasks.length - 1,
                          toDo.subTasks.getRange(index + 1, toDo.subTasks.length));
                      toDo.subTasks.last = SubTask();

                      for (int i = 0; i < toDo.subTasks.length; i++) {
                        subTaskEditingController[i].value =
                            subTaskEditingController[i].value.copyWith(text: toDo.subTasks[i].name);
                      }

                      shownTasks--;
                      shownTasks = max(shownTasks, 0);
                      // TODO: refactor, provider method.
                      toDo.weight = toDo.subTasks.fold(0, (p, c) => p + c.weight);
                    })));
      },
    );
  }

  ListTile buildMyDayTile() {
    return ListTile(
        title: AutoSizeText(
          (toDo.myDay)
              ? "Added to my Day"
              : (userProvider.myDayTotal + toDo.weight <=
                      (userProvider.curUser?.bandwidth ?? Constants.maxBandwidth))
                  ? "Add to My Day?"
                  : "Don't overload yourself, you deserve a rest",
          overflow: TextOverflow.visible,
          softWrap: true,
          minFontSize: Constants.medium,
          maxLines: 2,
        ),
        leading: (toDo.myDay)
            ? IconButton.filledTonal(
                icon: const Icon(Icons.wb_sunny),
                onPressed: () => setState(() {
                      checkClose = true;
                      toDo.myDay = !toDo.myDay;
                    }))
            : (userProvider.myDayTotal + toDo.weight <=
                    (userProvider.curUser?.bandwidth ?? Constants.maxBandwidth)
                ? IconButton.outlined(
                    icon: const Icon(Icons.wb_sunny_outlined),
                    onPressed: () => setState(() {
                          checkClose = true;
                          toDo.myDay = !toDo.myDay;
                        }))
                : const Icon(Icons.block_outlined)));
  }

  SegmentedButton<Priority> buildPriorityTile({bool smallScreen = false}) {
    return SegmentedButton<Priority>(
        selectedIcon: const Icon(Icons.flag_circle),
        style: ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.adaptivePlatformDensity,
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
        selected: <Priority>{toDo.priority},
        onSelectionChanged: (Set<Priority> newSelection) => setState(() {
              checkClose = true;
              toDo.priority = newSelection.first;
            }));
  }

  SearchAnchor buildGroupBar() {
    return SearchAnchor.bar(
        isFullScreen: false,
        barSide: MaterialStatePropertyAll(BorderSide(
            strokeAlign: BorderSide.strokeAlignOutside,
            color: Theme.of(context).colorScheme.outline)),
        barBackgroundColor: const MaterialStatePropertyAll(Colors.transparent),
        barElevation: const MaterialStatePropertyAll(0),
        viewConstraints: const BoxConstraints(maxHeight: Constants.maxSearchHeightBeforeScroll),
        barHintText: "Search Groups",
        suggestionsBuilder: (context, SearchController controller) {
          if (controller.text.isEmpty) {
            if (searchHistory.isNotEmpty) {
              return searchHistory
                  .map((MapEntry<String, int> groupData) => ListTile(
                        leading: const Icon(Icons.history),
                        title: AutoSizeText(
                          groupData.key,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                        ),
                        onTap: () =>
                            handleHistorySelection(groupData: groupData, controller: controller),
                      ))
                  .toList();
            }
            final searchFuture = groupProvider.mostRecent(limit: 5);
            return [buildGroupList(searchFuture, controller)];
          }
          // Search query iterable.
          final searchFuture = groupProvider.searchGroups(searchString: controller.text);
          return [buildGroupList(searchFuture, controller)];
        });
  }

  FutureBuilder<List<Group>> buildGroupList(
      Future<List<Group>> searchFuture, SearchController controller) {
    return FutureBuilder(
        future: searchFuture,
        builder: (context, snapshot) {
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
                        onTap: () =>
                            handleGroupSelection(group: groups[index], controller: controller));
                  });
            }
            // This is what to render if no data.
          }
          return const CircularProgressIndicator();
        });
  }

  AutoSizeTextField buildDescriptionTile({bool smallScreen = false}) {
    return AutoSizeTextField(
        controller: descriptionEditingController,
        maxLines: Constants.descripMaxLinesBeforeScroll,
        minLines:
            (smallScreen) ? Constants.descripMinLinesMobile : Constants.descripMinLinesDesktop,
        minFontSize: Constants.medium,
        decoration: InputDecoration(
          isDense: smallScreen,
          contentPadding: const EdgeInsets.all(Constants.innerPadding),
          hintText: "Description",
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(Constants.roundedCorners)),
              borderSide: BorderSide(
                strokeAlign: BorderSide.strokeAlignOutside,
              )),
        ));
  }

  ListTile buildDurationTile(BuildContext context, {bool smallScreen = false}) {
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: (toDo.expectedDuration > 0)
          ? Row(
              children: [
                Flexible(
                  child: AutoSizeText(
                      (smallScreen)
                          ? Duration(seconds: toDo.expectedDuration).toString().split(".").first
                          : "Expected: ${Duration(seconds: toDo.expectedDuration).toString().split(".").first}",
                      overflow: TextOverflow.visible,
                      minFontSize: Constants.small,
                      maxLines: 2,
                      softWrap: true),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Constants.innerPadding),
                  child: Icon(
                    Icons.timer,
                  ),
                ),
                Flexible(
                  child: AutoSizeText(
                      (smallScreen)
                          ? Duration(seconds: toDo.realDuration).toString().split(".").first
                          : "Actual: ${Duration(seconds: toDo.realDuration).toString().split(".").first}",
                      overflow: TextOverflow.visible,
                      minFontSize: Constants.small,
                      maxLines: 2,
                      softWrap: true),
                ),
              ],
            )
          : const AutoSizeText("Expected Duration Until Completion: ",
              overflow: TextOverflow.visible,
              minFontSize: Constants.small,
              maxLines: 2,
              softWrap: true),
      trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
                toDo.expectedDuration = 0;
                toDo.realDuration = 0;
              })),
      onTap: () => showDialog<int>(
          context: context,
          builder: (BuildContext context) {
            int time = toDo.expectedDuration;
            int hours = time ~/ 3600;
            time %= 3600;
            int minutes = time ~/ 60;
            time %= 60;
            int seconds = time;
            return StatefulBuilder(
              builder: (context, setState) {
                return Dialog(
                    child: Padding(
                        padding: const EdgeInsets.all(Constants.innerPadding),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                        child: AutoSizeText(
                                      "Hours",
                                      maxLines: 1,
                                      minFontSize: Constants.small,
                                      softWrap: false,
                                      overflow: TextOverflow.visible,
                                      textAlign: TextAlign.center,
                                    )),
                                    Expanded(
                                        child: AutoSizeText(
                                      "Minutes",
                                      maxLines: 1,
                                      minFontSize: Constants.small,
                                      softWrap: false,
                                      overflow: TextOverflow.visible,
                                      textAlign: TextAlign.center,
                                    )),
                                    Expanded(
                                        child: AutoSizeText(
                                      "Seconds",
                                      maxLines: 1,
                                      minFontSize: Constants.small,
                                      softWrap: false,
                                      overflow: TextOverflow.visible,
                                      textAlign: TextAlign.center,
                                    ))
                                  ]),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: NumberPicker(
                                      textStyle: Constants.numberPickerSecondary(context: context),
                                      selectedTextStyle:
                                          Constants.numberPickerPrimary(context: context),
                                      minValue: 0,
                                      maxValue: 100,
                                      value: hours,
                                      haptics: true,
                                      onChanged: (value) {
                                        SemanticsService.announce(
                                            "$value, hours", Directionality.of(context));
                                        setState(() => hours = value);
                                      },
                                    ),
                                  ),
                                  const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: Constants.padding),
                                      child: Text(":", style: Constants.timeColon)),
                                  Expanded(
                                    child: NumberPicker(
                                      textStyle: Constants.numberPickerSecondary(context: context),
                                      selectedTextStyle:
                                          Constants.numberPickerPrimary(context: context),
                                      minValue: 0,
                                      maxValue: 59,
                                      value: minutes,
                                      haptics: true,
                                      onChanged: (value) {
                                        SemanticsService.announce(
                                            "$value, minutes", Directionality.of(context));
                                        setState(() => minutes = value);
                                      },
                                    ),
                                  ),
                                  const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: Constants.padding),
                                      child: Text(":", style: Constants.timeColon)),
                                  Expanded(
                                    child: NumberPicker(
                                      textStyle: Constants.numberPickerSecondary(context: context),
                                      selectedTextStyle:
                                          Constants.numberPickerPrimary(context: context),
                                      minValue: 0,
                                      maxValue: 59,
                                      value: seconds,
                                      haptics: true,
                                      onChanged: (value) {
                                        SemanticsService.announce(
                                            "$value, seconds", Directionality.of(context));
                                        setState(() => seconds = value);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: Constants.padding),
                                    child: FilledButton.tonalIcon(
                                        icon: const Icon(Icons.close_outlined),
                                        onPressed: () => Navigator.pop(context, 0),
                                        label: const AutoSizeText("Cancel",
                                            softWrap: false,
                                            overflow: TextOverflow.visible,
                                            maxLines: 1,
                                            minFontSize: Constants.small)),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: Constants.padding),
                                    child: FilledButton.icon(
                                      icon: const Icon(Icons.done_outlined),
                                      onPressed: () {
                                        Navigator.pop(
                                            context, (hours * 3600) + (minutes * 60) + seconds);
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
              },
            );
          }).then((value) {
        setState(() {
          checkClose = true;
          toDo.expectedDuration = value ?? toDo.expectedDuration;
          toDo.realDuration = toDoProvider.calculateRealDuration(
              weight: toDo.weight, duration: toDo.expectedDuration);
          // int tmp = toDo.expectedDuration;
          // hours = tmp ~/ 3600;
          // tmp %= 3600;
          // minutes = tmp ~/ 60;
          // tmp %= 60;
          // seconds = tmp;
        });
      }),
    );
  }

  ListTile buildDateTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.today_outlined),
      // TODO: finish start and end + time.
      title: (null == toDo.startDate && null == toDo.dueDate)
          ? const AutoSizeText(
              "Add Dates",
              softWrap: true,
              overflow: TextOverflow.visible,
              maxLines: 2,
              minFontSize: Constants.small,
            )
          : Row(
              children: [
                (null == toDo.startDate)
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
                            Jiffy.parseFromDateTime(toDo.startDate!).format(
                              pattern: "MMM d",
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                            maxLines: 2,
                            minFontSize: Constants.small)),
                const Flexible(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Constants.padding),
                    child: AutoSizeText(
                      "-",
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      maxLines: 1,
                      minFontSize: Constants.small,
                    ),
                  ),
                ),
                (null == toDo.dueDate)
                    ? const Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(right: Constants.padding),
                          child: Flexible(child: Icon(Icons.today_outlined)),
                        ),
                      )
                    : const Flexible(
                        child: Padding(
                        padding: EdgeInsets.only(right: Constants.padding),
                        child: Icon(Icons.event_outlined),
                      )),
                (null == toDo.dueDate)
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
                            Jiffy.parseFromDateTime(toDo.dueDate).format(pattern: "MMM d"),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                            maxLines: 2,
                            minFontSize: Constants.small),
                      )
              ],
            ),
      trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
                // TODO: Handle this, need a dummy date for "no date"
                toDo.startDate = toDo.startDate;
                toDo.dueDate = toDo.dueDate;
              })),
      onTap: () {
        showDialog<void>(
            context: context,
            builder: (BuildContext context) {
              DateTime? tmpStart = toDo.startDate;
              DateTime? tmpDue = toDo.dueDate;
              DateTime initDate = tmpStart ?? tmpDue ?? DateTime.now();
              bool setStart = false;
              final int numDays = (toDo.dueDate?.difference(initDate).inDays ?? 0) + 1;
              List<DateTime?> showDates =
                  List.generate(numDays, (i) => initDate.add(Duration(days: i)));

              // List ->
              return StatefulBuilder(
                  builder: (context, setState) => Dialog(
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                          child: Icon(Icons.date_range_outlined,
                                              size: Constants.medIconSize)),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: Constants.innerPadding),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Expanded(
                                        flex: 10,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(Constants.roundedCorners),
                                            border: Border.all(
                                                strokeAlign: BorderSide.strokeAlignOutside),
                                          ),
                                          child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Expanded(
                                                  child: TextButton(
                                                      onPressed: () =>
                                                          setState(() => setStart = true),
                                                      child: (null != tmpStart)
                                                          ? AutoSizeText(
                                                              Jiffy.parseFromDateTime(tmpStart!)
                                                                  .format(pattern: "yMMMMd"),
                                                              softWrap: false,
                                                              overflow: TextOverflow.visible,
                                                              maxLines: 1,
                                                              minFontSize: Constants.small,
                                                            )
                                                          : const AutoSizeText("Start Date",
                                                              softWrap: true,
                                                              overflow: TextOverflow.visible,
                                                              maxLines: 1,
                                                              minFontSize: Constants.small)),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.close_outlined),
                                                  selectedIcon: const Icon(Icons.close),
                                                  onPressed: () => setState(() => tmpStart = null),
                                                )
                                              ]),
                                        ),
                                      ),
                                      const Flexible(
                                        flex: 1,
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: Constants.halfPadding),
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
                                            borderRadius:
                                                BorderRadius.circular(Constants.roundedCorners),
                                            border: Border.all(
                                                strokeAlign: BorderSide.strokeAlignOutside),
                                          ),
                                          child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Expanded(
                                                  child: TextButton(
                                                      onPressed: () =>
                                                          setState(() => setStart = false),
                                                      child: (null != tmpDue)
                                                          ? AutoSizeText(
                                                              Jiffy.parseFromDateTime(tmpDue!)
                                                                  .format(pattern: "yMMMMd"),
                                                              softWrap: false,
                                                              overflow: TextOverflow.visible,
                                                              maxLines: 1,
                                                              minFontSize: Constants.small,
                                                            )
                                                          : const AutoSizeText("Due Date",
                                                              softWrap: true,
                                                              overflow: TextOverflow.visible,
                                                              maxLines: 1,
                                                              minFontSize: Constants.small)),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.close_outlined),
                                                  selectedIcon: const Icon(Icons.close),
                                                  onPressed: () => setState(() => tmpDue = null),
                                                )
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
                                          calendarType: CalendarDatePicker2Type.range,
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: Constants.padding),
                                        child: FilledButton.tonalIcon(
                                            icon: const Icon(Icons.close_outlined),
                                            onPressed: () => Navigator.pop(context),
                                            label: const AutoSizeText("Cancel",
                                                softWrap: false,
                                                overflow: TextOverflow.visible,
                                                maxLines: 1,
                                                minFontSize: Constants.small)),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: Constants.padding),
                                        child: FilledButton.icon(
                                          icon: const Icon(Icons.done_outlined),
                                          onPressed: () {
                                            setState(() {
                                              toDo.startDate = tmpStart!.copyWith(
                                                  hour: toDo.startDate.hour,
                                                  minute: toDo.startDate.minute);
                                              toDo.dueDate = tmpDue!.copyWith(
                                                  hour: toDo.dueDate.hour,
                                                  minute: toDo.dueDate.minute);
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

  ListTile buildTimeTile() {
    // TODO: possibly factor these out as nullable params.
    TimeOfDay? startTime = TimeOfDay(hour: toDo.startDate.hour, minute: toDo.startDate.minute);
    TimeOfDay? dueTime = TimeOfDay(hour: toDo.dueDate.hour, minute: toDo.dueDate.minute);
    return ListTile(
        leading: const Icon(Icons.schedule_outlined),
        title: (null == startTime && null == dueTime)
            // TODO: Need a dummy value for hour/minute
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
                        child: AutoSizeText(
                        "Start @: ${startTime.format(context).toString()}",
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        maxLines: 2,
                        minFontSize: Constants.small,
                      )),
                (null == dueTime)
                    ? const Flexible(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: Constants.padding),
                          child: FittedBox(
                              fit: BoxFit.fill, child: Icon(Icons.history_toggle_off_outlined)),
                        ),
                      )
                    : const Flexible(
                        child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: Constants.padding),
                        child: FittedBox(fit: BoxFit.fill, child: Icon(Icons.schedule_outlined)),
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
                        child: AutoSizeText(
                          "Due @: ${dueTime.format(context).toString()}",
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          maxLines: 2,
                          minFontSize: Constants.small,
                        ),
                      ),
              ]),
        onTap: () {
          showDialog<void>(
              context: context,
              builder: (BuildContext context) {
                return StatefulBuilder(
                    builder: (context, setState) => Dialog(
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                            child: Icon(Icons.schedule_outlined,
                                                size: Constants.medIconSize)),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: Constants.innerPadding),
                                  child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Expanded(
                                          flex: 10,
                                          child: OutlinedButton(
                                              onPressed: () async {
                                                final TimeOfDay? picked = await showTimePicker(
                                                    context: context,
                                                    initialTime: startTime ??
                                                        const TimeOfDay(hour: 0, minute: 0));
                                                if (null != picked) {
                                                  setState(() => dueTime = picked);
                                                }
                                              },
                                              child: (null != startTime)
                                                  ? AutoSizeText(
                                                      startTime!.format(context).toString(),
                                                      softWrap: false,
                                                      overflow: TextOverflow.visible,
                                                      maxLines: 1,
                                                      minFontSize: Constants.small,
                                                    )
                                                  : const AutoSizeText("Start Time",
                                                      softWrap: true,
                                                      overflow: TextOverflow.visible,
                                                      maxLines: 1,
                                                      minFontSize: Constants.small)),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: Constants.halfPadding),
                                          child: Text("|", style: Constants.timeColon),
                                        ),
                                        Expanded(
                                          flex: 10,
                                          child: OutlinedButton(
                                              onPressed: () async {
                                                final TimeOfDay? picked = await showTimePicker(
                                                    context: context,
                                                    initialTime: dueTime ??
                                                        const TimeOfDay(hour: 0, minute: 0));
                                                if (null != picked) {
                                                  setState(() => dueTime = picked);
                                                }
                                              },
                                              child: (null != dueTime)
                                                  ? AutoSizeText(
                                                      dueTime!.format(context).toString(),
                                                      softWrap: false,
                                                      overflow: TextOverflow.visible,
                                                      maxLines: 1,
                                                      minFontSize: Constants.small,
                                                    )
                                                  : const AutoSizeText("Due Time",
                                                      softWrap: true,
                                                      overflow: TextOverflow.visible,
                                                      maxLines: 1,
                                                      minFontSize: Constants.small)),
                                        ),
                                      ]),
                                ),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: Constants.padding),
                                          child: FilledButton.tonalIcon(
                                              icon: const Icon(Icons.close_outlined),
                                              onPressed: () => Navigator.pop(context),
                                              label: const AutoSizeText("Cancel",
                                                  softWrap: false,
                                                  overflow: TextOverflow.visible,
                                                  maxLines: 1,
                                                  minFontSize: Constants.small)),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: Constants.padding),
                                          child: FilledButton.icon(
                                            icon: const Icon(Icons.done_outlined),
                                            onPressed: () {
                                              setState(() {
                                                startTime = startTime ??
                                                    const TimeOfDay(hour: 0, minute: 0);
                                                dueTime =
                                                    dueTime ?? const TimeOfDay(hour: 0, minute: 0);
                                                toDo.startDate = toDo.startDate.copyWith(
                                                    hour: startTime!.hour,
                                                    minute: startTime!.minute);
                                                toDo.dueDate = toDo.dueDate.copyWith(
                                                    hour: dueTime!.hour, minute: dueTime!.minute);
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
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            startTime = null;
            dueTime = null;
          }),
        ));
  }

  ListTile buildRepeatableTile(BuildContext context, {bool smallScreen = false}) {
    return ListTile(
        leading: const Icon(Icons.event_repeat_outlined),
        title: (toDo.frequency == Frequency.once)
            ? const AutoSizeText("Set Recurring?",
                overflow: TextOverflow.visible,
                minFontSize: Constants.small,
                maxLines: 2,
                softWrap: true)
            : AutoSizeText(toBeginningOfSentenceCase(toDo.frequency.name)!,
                overflow: TextOverflow.visible,
                minFontSize: Constants.small,
                maxLines: 1,
                softWrap: false),
        onTap: () {
          // TODO: figure out dummy values for gui.
          // TODO: Consider caching the set of weekdays and validating on update.
          showDialog(
              context: context,
              builder: (BuildContext context) {
                Frequency cacheFreq = toDo.frequency;
                CustomFrequency cacheCustom = toDo.customFreq;
                Set<int> cacheWeekdays = {};
                for (int i = 0; i < toDo.repeatDays.length; i++) {
                  if (toDo.repeatDays[i]) {
                    cacheWeekdays.add(i);
                  }
                }

                if (cacheWeekdays.isEmpty) {
                  int day = (null != toDo.startDate)
                      ? max(toDo.startDate!.weekday - 1, 0)
                      : max(DateTime.now().weekday - 1, 0);
                  cacheWeekdays.add(day);
                }

                int cacheSkip = toDo.repeatSkip;

                return StatefulBuilder(builder: (context, setState) {
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                          child: Icon(Icons.repeat_outlined,
                                              size: Constants.medIconSize)),
                                    ),
                                  ],
                                ),
                                // This is a hacky override until m3 Has width-scaling for DropdownMenu
                                Padding(
                                  padding:
                                      (cacheFreq != Frequency.once && cacheFreq != Frequency.daily)
                                          ? const EdgeInsets.fromLTRB(
                                              Constants.innerPadding,
                                              Constants.innerPadding,
                                              Constants.innerPadding,
                                              Constants.halfPadding)
                                          : const EdgeInsets.all(Constants.innerPadding),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(
                                          gapPadding: 1,
                                          borderRadius:
                                              BorderRadius.all(Radius.circular(Constants.circular)),
                                          borderSide: BorderSide(
                                              strokeAlign: BorderSide.strokeAlignOutside)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<Frequency>(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: Constants.padding),
                                        isDense: true,
                                        isExpanded: true,
                                        // TODO: Abstract this reference.
                                        dropdownColor: Theme.of(context).colorScheme.surfaceVariant,
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(Constants.roundedCorners)),
                                        value: cacheFreq,
                                        onChanged: (Frequency? value) =>
                                            setState(() => cacheFreq = value ?? cacheFreq),
                                        items: Frequency.values
                                            .map((Frequency frequency) =>
                                                DropdownMenuItem<Frequency>(
                                                  value: frequency,
                                                  child: AutoSizeText(
                                                    "${toBeginningOfSentenceCase(frequency.name)}",
                                                    softWrap: false,
                                                    maxLines: 1,
                                                    minFontSize: Constants.small,
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ),

                                (cacheFreq == Frequency.custom)
                                    ? Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: Constants.innerPadding),
                                            child: InputDecorator(
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(
                                                    gapPadding: 0,
                                                    borderRadius: BorderRadius.all(
                                                        Radius.circular(Constants.circular)),
                                                    borderSide: BorderSide(
                                                        strokeAlign:
                                                            BorderSide.strokeAlignOutside)),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<CustomFrequency>(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: Constants.padding),
                                                  isDense: true,
                                                  isExpanded: true,
                                                  dropdownColor:
                                                      Theme.of(context).colorScheme.surfaceVariant,
                                                  borderRadius: const BorderRadius.all(
                                                      Radius.circular(Constants.roundedCorners)),
                                                  value: cacheCustom,
                                                  onChanged: (CustomFrequency? value) => setState(
                                                      () => cacheCustom = value ?? cacheCustom),
                                                  items: CustomFrequency.values
                                                      .map((CustomFrequency customFreq) =>
                                                          DropdownMenuItem<CustomFrequency>(
                                                            value: customFreq,
                                                            child: AutoSizeText(
                                                              "${toBeginningOfSentenceCase(customFreq.name)}",
                                                              softWrap: false,
                                                              maxLines: 1,
                                                              minFontSize: Constants.small,
                                                            ),
                                                          ))
                                                      .toList(),
                                                ),
                                              ),
                                            ),
                                          ),
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
                                                runAlignment: WrapAlignment.center,
                                                children: Constants.weekDays
                                                    .map((weekDay) => InputChip(
                                                        backgroundColor: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceVariant,
                                                        shape: const RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.all(
                                                              Radius.circular(Constants.circular)),
                                                          side: BorderSide(
                                                            strokeAlign:
                                                                BorderSide.strokeAlignOutside,
                                                          ),
                                                        ),
                                                        label: AutoSizeText(weekDay.key,
                                                            minFontSize: Constants.small,
                                                            maxLines: 1,
                                                            softWrap: false,
                                                            overflow: TextOverflow.visible),
                                                        selected:
                                                            cacheWeekdays.contains(weekDay.value),
                                                        onSelected: (bool selected) => setState(() {
                                                              if (selected) {
                                                                cacheWeekdays.add(weekDay.value);
                                                              } else {
                                                                cacheWeekdays.remove(weekDay.value);
                                                                if (cacheWeekdays.isEmpty) {
                                                                  int day = (null != toDo.startDate)
                                                                      ? max(
                                                                          toDo.startDate!.weekday -
                                                                              1,
                                                                          0)
                                                                      : max(
                                                                          DateTime.now().weekday -
                                                                              1,
                                                                          0);
                                                                  cacheWeekdays.add(day);
                                                                }
                                                              }
                                                            })))
                                                    .toList()),
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),

                                // Repeat Skip
                                (cacheFreq != Frequency.once && cacheFreq != Frequency.daily)
                                    ? Padding(
                                        padding: const EdgeInsets.all(Constants.innerPadding),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
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
                                                    textStyle: Constants.numberPickerSecondary(
                                                        context: context),
                                                    selectedTextStyle:
                                                        Constants.numberPickerPrimary(
                                                            context: context),
                                                    minValue: 1,
                                                    maxValue: 100,
                                                    value: cacheSkip,
                                                    haptics: true,
                                                    onChanged: (value) {
                                                      SemanticsService.announce(
                                                          "Skip value: $value",
                                                          Directionality.of(context));
                                                      setState(() => cacheSkip = value);
                                                    })),
                                            Flexible(
                                              child: AutoSizeText(
                                                (cacheFreq == Frequency.custom)
                                                    ? cacheCustom.name.replaceAll(
                                                        "ly", (cacheSkip > 1) ? "s." : ".")
                                                    : cacheFreq.name.replaceAll(
                                                        "ly", (cacheSkip > 1) ? "s." : "."),
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: Constants.padding),
                                          child: FilledButton.tonalIcon(
                                              icon: const Icon(Icons.close_outlined),
                                              onPressed: () => Navigator.pop(context),
                                              label: const AutoSizeText("Cancel",
                                                  softWrap: false,
                                                  overflow: TextOverflow.visible,
                                                  maxLines: 1,
                                                  minFontSize: Constants.small)),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: Constants.padding),
                                          child: FilledButton.icon(
                                            icon: const Icon(Icons.done_outlined),
                                            onPressed: () {
                                              setState(() {
                                                toDo.frequency = cacheFreq;
                                                toDo.customFreq = cacheCustom;
                                                toDo.repeatSkip = cacheSkip;
                                                // TODO: Consider validating this on update.
                                                //weekDayList = cacheWeekdays;
                                                if (cacheWeekdays.isEmpty) {
                                                  cacheWeekdays.add(toDo.startDate.weekday - 1);
                                                }
                                                for (int i = 0; i < toDo.repeatDays.length; i++) {
                                                  toDo.repeatDays[i] = cacheWeekdays.contains(i);
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
                                    ])
                              ])));
                });
              }).then((_) => setState(() {}));
        },
        trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
                  toDo.frequency = Frequency.once;
                  toDo.customFreq = CustomFrequency.weekly;
                  // for(int i = 0; i < toDo.repeatDays.length; i++)
                  //   {
                  //     toDo.repeatDays[i] = false;
                  //   }

                  toDo.repeatDays.fillRange(0, toDo.repeatDays.length, false);

                  toDo.repeatSkip = 1;
                })));
  }

  Row buildCreateButton(BuildContext context, Color errorColor) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      FilledButton.icon(
          label: const Text("Create Task"),
          icon: const Icon(Icons.add),
          onPressed: () async {
            bool validData = validateData();
            if (validData) {
              // TODO: figure out whether to cache date/time.
              //mergeDateTimes();

              // TODO: figure out whether to cache weekday List.
              // for (int index in weekDayList) {
              //   weekDays[index] = true;
              // }

              // TODO: validation logic for repeatable.
              /// If an object's repeatable status has changed to once && is still repeatable, mutate.
              /// If an object is newly repeatable, do nothing.
              /// If an object is repeatable: compare with the previously cached ToDo.
              ///   If they are the same, just proceed.
              ///   If they are different -> Show modal bottom drawer: for one, for all
              ///   For one: Delete all future todos && generate the next from the cached ToDo.
              ///   For all: Delete all future todos.

              await toDoProvider.updateToDo().then((value) => Navigator.pop(context)).catchError(
                  (e) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
                  content: Text(e.cause,
                      overflow: TextOverflow.ellipsis, style: TextStyle(color: errorColor)),
                  action: SnackBarAction(label: "Dismiss", onPressed: () {}),
                  duration: const Duration(milliseconds: 1500),
                  behavior: SnackBarBehavior.floating,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(Constants.roundedCorners)),
                  ),
                  width: (MediaQuery.sizeOf(context).width) / 2,
                  padding: const EdgeInsets.symmetric(horizontal: Constants.padding),
                ));
              }, test: (e) => e is FailureToCreateException || e is FailureToUploadException);
            }
            // Then save.
          })
    ]);
  }
}
