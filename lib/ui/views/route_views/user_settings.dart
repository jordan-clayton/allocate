import "dart:io";

import "package:allocate/ui/widgets/check_delete_dialog.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";

import "../../../providers/application/layout_provider.dart";
import '../../../providers/application/theme_provider.dart';
import "../../../providers/model/deadline_provider.dart";
import "../../../providers/model/group_provider.dart";
import "../../../providers/model/reminder_provider.dart";
import "../../../providers/model/routine_provider.dart";
import "../../../providers/model/subtask_provider.dart";
import "../../../providers/model/todo_provider.dart";
import '../../../providers/model/user_provider.dart';
import "../../../providers/viewmodels/user_viewmodel.dart";
import "../../../util/constants.dart";
import "../../../util/enums.dart";
import "../../../util/numbers.dart";
import "../../widgets/screen_header.dart";
import "../../widgets/settings_screen_widgets.dart";
import "loading_screen.dart";

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreen();
}

class _UserSettingsScreen extends State<UserSettingsScreen> {
  // For testing
  late bool _mockOnline;

  late final UserProvider userProvider;
  late final UserViewModel vm;
  late final ToDoProvider toDoProvider;
  late final RoutineProvider routineProvider;
  late final ReminderProvider reminderProvider;
  late final DeadlineProvider deadlineProvider;
  late final GroupProvider groupProvider;
  late final SubtaskProvider subtaskProvider;

  late final ThemeProvider themeProvider;
  late final LayoutProvider layoutProvider;

  late final ScrollController mobileScrollController;
  late final ScrollController desktopScrollController;
  late final ScrollController desktopSideController;
  late final ScrollPhysics scrollPhysics;

  late MenuController _scaffoldController;
  late MenuController _sidebarController;

  // Factor out into functions.
  @override
  void initState() {
    userProvider = Provider.of<UserProvider>(context, listen: false);
    vm = Provider.of<UserViewModel>(context, listen: false);
    themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    layoutProvider = Provider.of<LayoutProvider>(context, listen: false);

    toDoProvider = Provider.of<ToDoProvider>(context, listen: false);
    routineProvider = Provider.of<RoutineProvider>(context, listen: false);
    reminderProvider = Provider.of<ReminderProvider>(context, listen: false);
    deadlineProvider = Provider.of<DeadlineProvider>(context, listen: false);
    groupProvider = Provider.of<GroupProvider>(context, listen: false);
    subtaskProvider = Provider.of<SubtaskProvider>(context, listen: false);

    _mockOnline = true;

    _scaffoldController = MenuController();
    _sidebarController = MenuController();

    mobileScrollController = ScrollController();
    desktopScrollController = ScrollController();
    desktopSideController = ScrollController();
    ScrollPhysics scrollBehaviour = (Platform.isMacOS || Platform.isIOS)
        ? const BouncingScrollPhysics()
        : const ClampingScrollPhysics();
    scrollPhysics = AlwaysScrollableScrollPhysics(parent: scrollBehaviour);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void anchorWatchScroll() {
    _scaffoldController.close();
    _sidebarController.close();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return (layoutProvider.wideView)
          ? buildWide(context: context)
          : buildRegular(context: context);
    });
  }

  Widget buildWide({required BuildContext context}) {
    return Padding(
      padding: const EdgeInsets.all(Constants.padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header.
                      _buildHeader(),
                      Flexible(
                        child: Scrollbar(
                          controller: desktopSideController,
                          child: ListView(
                            shrinkWrap: true,
                            physics: scrollPhysics,
                            controller: desktopSideController,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: Constants.quadPadding +
                                        Constants.doublePadding +
                                        Constants.padding),
                                child: _buildEnergyTile(),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: Constants.quadPadding,
                                  bottom: Constants.doublePadding,
                                ),
                                child: _buildQuickInfo(),
                              ),
                              const Padding(
                                padding:
                                    EdgeInsets.all(Constants.halfPadding - 1),
                                child: SizedBox.shrink(),
                              ),
                              _buildSignInOut(),
                              _buildDeleteAccount(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  flex: 2,
                  child: Scrollbar(
                    thumbVisibility: true,
                    controller: desktopScrollController,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Constants.doublePadding),
                      controller: desktopScrollController,
                      physics: scrollPhysics,
                      shrinkWrap: true,
                      children: [
                        _buildAccountSection(),
                        _buildGeneralSection(),
                        _buildAccessibilitySection(),
                        _buildThemeSection(),
                        _buildAboutSection(),
                        const Padding(
                          padding: EdgeInsets.all(Constants.padding),
                          child: SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRegular({required BuildContext context}) {
    return Padding(
        padding: const EdgeInsets.all(Constants.padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header.
            _buildHeader(),
            Flexible(
              child: Scrollbar(
                controller: mobileScrollController,
                thumbVisibility: true,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Constants.halfPadding),
                  shrinkWrap: true,
                  physics: scrollPhysics,
                  controller: mobileScrollController,
                  children: [
                    _buildEnergyTile(),
                    _buildQuickInfo(),
                    // ACCOUNT SETTNIGS
                    _buildAccountSection(),
                    // GENERAL SETTINGS
                    _buildGeneralSection(),
                    // ACCESSIBILITY
                    _buildAccessibilitySection(),
                    // THEME
                    _buildThemeSection(),
                    // ABOUT
                    _buildAboutSection(),
                    // SIGN OUT
                    _buildSignInOut(),

                    // DELETE ACCOUNT
                    _buildDeleteAccount(),
                    const Padding(
                      padding: EdgeInsets.all(Constants.padding),
                      child: SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ));
  }

  Widget _buildQuickInfo() {
    // TODO: implement a user switcher.
    // return Consumer<UserProvider>(
    //   builder: (BuildContext context, UserProvider value, Widget? child) {
    //     return Selector<UserViewModel, (String, String?, String?)>(
    //         selector: (BuildContext context, UserViewModel vm) =>
    //             (vm.username, vm.email, vm.uuid),
    //         builder: (BuildContext context,
    //             (String, String?, String?) watchInfo, Widget? child) {
    //           return SettingsScreenWidgets.userQuickInfo(
    //             context: context,
    //             // userProvider: value,
    //             viewModel: vm,
    //             outerPadding:
    //                 const EdgeInsets.only(bottom: Constants.halfPadding),
    //           );
    //         });
    //   },
    // );

    return Selector<UserViewModel, (String, String?, String?)>(
        selector: (BuildContext context, UserViewModel vm) =>
            (vm.username, vm.email, vm.uuid),
        builder: (BuildContext context, (String, String?, String?) watchInfo,
            Widget? child) {
          return SettingsScreenWidgets.userQuickInfo(
            context: context,
            // userProvider: value,
            viewModel: vm,
            outerPadding: const EdgeInsets.only(bottom: Constants.halfPadding),
          );
        });
  }

  Widget _buildEnergyTile({double maxScale = 1.5}) {
    return Selector<UserViewModel, int>(
        selector: (BuildContext context, UserViewModel vm) => vm.bandwidth,
        builder: (BuildContext context, int value, Widget? child) =>
            SettingsScreenWidgets.energyTile(
              weight: value.toDouble(),
              batteryScale: remap(
                      x: layoutProvider.width
                          .clamp(Constants.smallScreen, Constants.largeScreen),
                      inMin: Constants.smallScreen,
                      inMax: Constants.largeScreen,
                      outMin: 1,
                      outMax: maxScale)
                  .toDouble(),
              handleWeightChange: (newWeight) {
                if (null == newWeight) {
                  return;
                }
                vm.bandwidth = newWeight.toInt();
              },
            ));
  }

  Widget _buildAccountSection() {
    return Selector2<UserViewModel, UserProvider, (bool, int)>(
        selector: (BuildContext context, UserViewModel vm, UserProvider up) =>
            (vm.syncOnline, up.userCount),
        builder: (BuildContext context, (bool, int) value, Widget? child) =>
            SettingsScreenWidgets.settingsSection(
              context: context,
              title: "Account",
              entries: [
                (value.$1 || (kDebugMode && _mockOnline))
                    ? SettingsScreenWidgets.tapTile(
                        leading: const Icon(Icons.sync_rounded),
                        title: "Sync now",
                        onTap: () async {
                          //
                          print("Sync now");
                        })
                    : SettingsScreenWidgets.tapTile(
                        leading: const Icon(Icons.cloud_sync_rounded),
                        title: "Sign up for cloud backup",
                        onTap: () {
                          if (kDebugMode) {
                            setState(() {
                              _mockOnline = true;
                            });
                          }
                          print("Sign up");
                        }),
                if (value.$1 || (kDebugMode && _mockOnline))
                  SettingsScreenWidgets.tapTile(
                    leading: const Icon(Icons.email_rounded),
                    title: "Change email",
                    onTap: () {
                      print("Edit Email");
                    },
                  ),
                if (value.$1 || (kDebugMode && _mockOnline))
                  SettingsScreenWidgets.tapTile(
                      leading: const Icon(Icons.lock_reset_rounded),
                      title: "Reset password",
                      onTap: () {
                        print("Edit Password");
                      }),

                // This should also only appear with online connection.
                if (value.$2 < Constants.maxUserCount)
                  SettingsScreenWidgets.tapTile(
                      leading: const Icon(Icons.account_circle_rounded),
                      title: "Add new account",
                      onTap: () {
                        print("New Account");
                      })
              ],
            ));
  }

  Widget _buildGeneralSection() {
    return SettingsScreenWidgets.settingsSection(
      context: context,
      title: "General",
      entries: [
        //  Check close.
        Selector<UserViewModel, bool>(
          selector: (BuildContext context, UserViewModel vm) => vm.checkClose,
          builder: (BuildContext context, bool value, Widget? child) {
            return SettingsScreenWidgets.toggleTile(
                leading: const Icon(Icons.close_rounded),
                value: value,
                title: "Ask before closing",
                onChanged: (bool value) {
                  vm.checkClose = value;
                });
          },
        ),

        Selector<UserViewModel, bool>(
          selector: (BuildContext context, UserViewModel vm) => vm.checkDelete,
          builder: (BuildContext context, bool value, Widget? child) {
            return SettingsScreenWidgets.toggleTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: "Ask before deleting",
                value: value,
                onChanged: (bool value) {
                  vm.checkDelete = value;
                });
          },
        ),

        Selector<UserViewModel, DeleteSchedule>(
          selector: (BuildContext context, UserViewModel vm) =>
              vm.deleteSchedule,
          builder:
              (BuildContext context, DeleteSchedule value, Widget? child) =>
                  SettingsScreenWidgets.radioDropDown(
                      initiallyExpanded: false,
                      groupMember: value,
                      values: DeleteSchedule.values,
                      title: "Keep deleted items:",
                      getName: Constants.deleteScheduleType,
                      onChanged: (DeleteSchedule? newSchedule) {
                        if (null == newSchedule) {
                          return;
                        }
                        vm.deleteSchedule = newSchedule;
                      }),
        ),
      ],
    );
  }

  Widget _buildAccessibilitySection() {
    return SettingsScreenWidgets.settingsSection(
      context: context,
      title: "Accessibility",
      entries: [
        // Reduce motion.
        Selector<ThemeProvider, bool>(
          selector: (BuildContext context, ThemeProvider tp) => tp.reduceMotion,
          builder: (BuildContext context, bool value, Widget? child) =>
              SettingsScreenWidgets.toggleTile(
                  leading: const Icon(Icons.slow_motion_video_rounded),
                  title: "Reduce motion",
                  value: value,
                  onChanged: (bool reduceMotion) {
                    themeProvider.reduceMotion = reduceMotion;
                  }),
        ),
        // Use Ultra high Contrast.
        Selector<ThemeProvider, bool>(
          selector: (BuildContext context, ThemeProvider tp) =>
              tp.useUltraHighContrast,
          builder: (BuildContext context, bool value, Widget? child) =>
              SettingsScreenWidgets.toggleTile(
                  leading: const Icon(Icons.contrast_rounded),
                  title: "Ultra contrast",
                  value: value,
                  onChanged: (bool useHi) {
                    themeProvider.useUltraHighContrast = useHi;
                  }),
        ),
      ],
    );
  }

  Widget _buildThemeSection() {
    return SettingsScreenWidgets
        .settingsSection(context: context, title: "Theme", entries: [
      // ThemeType
      Selector<ThemeProvider, ThemeType>(
        selector: (BuildContext context, ThemeProvider tp) => tp.themeType,
        builder: (BuildContext context, ThemeType value, Widget? child) =>
            DefaultTabController(
          initialIndex: value.index,
          length: ThemeType.values.length,
          child: Padding(
            padding: const EdgeInsets.only(bottom: Constants.padding),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(
                    Radius.circular(Constants.roundedCorners)),
                color: Theme.of(context).colorScheme.onSecondary,
              ),
              child: TabBar(
                onTap: (newIndex) {
                  themeProvider.themeType = ThemeType.values[newIndex];
                },
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.all(
                        Radius.circular(Constants.roundedCorners))),
                splashBorderRadius: const BorderRadius.all(
                    Radius.circular(Constants.roundedCorners)),
                dividerColor: Colors.transparent,
                tabs: ThemeType.values
                    .map((ThemeType type) => Tab(
                          text: toBeginningOfSentenceCase(type.name),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),

      // Color seeds.
      Selector<ThemeProvider, Color>(
        selector: (BuildContext context, ThemeProvider tp) => tp.primarySeed,
        builder: (BuildContext context, Color value, Widget? child) =>
            SettingsScreenWidgets.colorSeedTile(
                context: context,
                recentColors: themeProvider.recentColors,
                color: value,
                onColorChanged: (Color newColor) {
                  themeProvider.primarySeed = newColor;
                },
                colorType: "Primary color",
                icon: const Icon(Icons.eject_rounded),
                showTrailing: Constants.defaultPrimaryColorSeed != value,
                restoreDefault: () {
                  Tooltip.dismissAllToolTips();
                  themeProvider.primarySeed =
                      const Color(Constants.defaultPrimaryColorSeed);
                }),
      ),
      Selector<ThemeProvider, Color?>(
        selector: (BuildContext context, ThemeProvider tp) => tp.secondarySeed,
        builder: (BuildContext context, Color? value, Widget? child) =>
            SettingsScreenWidgets.colorSeedTile(
                context: context,
                recentColors: themeProvider.recentColors,
                onColorChanged: (Color newColor) {
                  themeProvider.secondarySeed = newColor;
                },
                color: value,
                colorType: "Secondary color",
                showTrailing: null != value,
                restoreDefault: () {
                  Tooltip.dismissAllToolTips();
                  themeProvider.secondarySeed = null;
                }),
      ),
      Selector<ThemeProvider, Color?>(
        selector: (BuildContext context, ThemeProvider tp) => tp.tertiarySeed,
        builder: (BuildContext context, Color? value, Widget? child) =>
            SettingsScreenWidgets.colorSeedTile(
                context: context,
                recentColors: themeProvider.recentColors,
                onColorChanged: (Color newColor) {
                  themeProvider.tertiarySeed = newColor;
                },
                color: value,
                colorType: "Tertiary color",
                showTrailing: null != value,
                restoreDefault: () {
                  Tooltip.dismissAllToolTips();
                  themeProvider.tertiarySeed = null;
                }),
      ),

      // Tonemapping radiobutton
      Selector<ThemeProvider, ToneMapping>(
        selector: (BuildContext context, ThemeProvider tp) => tp.toneMapping,
        builder: (BuildContext context, ToneMapping value, Widget? child) =>
            SettingsScreenWidgets.radioDropDown(
                initiallyExpanded: false,
                leading: const Icon(Icons.colorize_rounded),
                title: "Tonemapping",
                groupMember: value,
                values: ToneMapping.values,
                onChanged: (ToneMapping? newMap) {
                  if (null == newMap) {
                    return;
                  }
                  themeProvider.toneMapping = newMap;
                }),
      ),

      // Window effects
      if (!layoutProvider.isMobile) ...[
        Selector<ThemeProvider, Effect>(
          selector: (BuildContext context, ThemeProvider tp) => tp.windowEffect,
          builder: (BuildContext context, Effect value, Widget? child) =>
              SettingsScreenWidgets.radioDropDown(
            initiallyExpanded: false,
            leading: const Icon(Icons.color_lens_outlined),
            title: "Window effect",
            children: getAvailableWindowEffects(),
            groupMember: value,
            values: Effect.values,
          ),
        ),
        // Transparency - use the dropdown slider.
        Selector<ThemeProvider, (double, bool)>(
          selector: (BuildContext context, ThemeProvider tp) =>
              (tp.sidebarOpacity, tp.useTransparency),
          builder:
              (BuildContext context, (double, bool) value, Widget? child) =>
                  SettingsScreenWidgets.sliderTile(
            title: "Sidebar opacity",
            leading: const Icon(Icons.gradient_rounded),
            label: "${(100 * value.$1).toInt()}",
            onOpen: () {
              desktopScrollController.addListener(anchorWatchScroll);
              mobileScrollController.addListener(anchorWatchScroll);
            },
            onClose: () {
              desktopScrollController.removeListener(anchorWatchScroll);
              mobileScrollController.removeListener(anchorWatchScroll);
            },
            onChanged: (value.$2)
                ? (double newOpacity) {
                    themeProvider.sidebarOpacity = newOpacity;
                  }
                : null,
            onChangeEnd: (double newOpacity) {
              themeProvider.sidebarOpacitySavePref = newOpacity;
              _sidebarController.close();
            },
            value: value.$1,
            controller: _sidebarController,
          ),
        ),

        Selector<ThemeProvider, (double, bool)>(
          selector: (BuildContext context, ThemeProvider tp) =>
              (tp.scaffoldOpacity, tp.useTransparency),
          builder:
              (BuildContext context, (double, bool) value, Widget? child) =>
                  SettingsScreenWidgets.sliderTile(
            title: "Window opacity",
            leading: const Icon(Icons.gradient_rounded),
            label: "${(100 * value.$1).toInt()}",
            onOpen: () {
              desktopScrollController.addListener(anchorWatchScroll);
              mobileScrollController.addListener(anchorWatchScroll);
            },
            onClose: () {
              desktopScrollController.removeListener(anchorWatchScroll);
              mobileScrollController.removeListener(anchorWatchScroll);
            },
            onChanged: (value.$2)
                ? (double newOpacity) {
                    themeProvider.scaffoldOpacity = newOpacity;
                  }
                : null,
            onChangeEnd: (double newOpacity) {
              themeProvider.scaffoldOpacitySavePref = newOpacity;
              _scaffoldController.close();
            },
            value: value.$1,
            controller: _scaffoldController,
          ),
        ),
      ],
    ]);
  }

  Widget _buildHeader() => Selector<UserViewModel, bool>(
        selector: (BuildContext context, UserViewModel vm) => vm.syncOnline,
        builder: (BuildContext context, bool value, Widget? child) =>
            const ScreenHeader(
          outerPadding: EdgeInsets.all(Constants.padding),
          leadingIcon: Icon(Icons.settings_rounded),
          header: "Settings",
        ),
      );

  Widget _buildAboutSection() {
    return SettingsScreenWidgets.settingsSection(
        context: context,
        title: "About",
        entries: [
          SettingsScreenWidgets.tapTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: "About",
              onTap: () async {
                // Future TODO: Implement MacOS specific code for opening "about" window.
                await showDialog(
                    context: context,
                    useRootNavigator: false,
                    builder: (BuildContext context) {
                      return SettingsScreenWidgets.aboutDialog(
                        packageInfo: layoutProvider.packageInfo,
                      );
                    });
              }),

          SettingsScreenWidgets.tapTile(
              leading: const Icon(Icons.medical_information_rounded),
              title: "Debug Information",
              onTap: () async {
                await showDialog(
                    context: context,
                    useRootNavigator: false,
                    builder: (BuildContext context) {
                      return SettingsScreenWidgets.debugInfoDialog(
                          viewModel: vm);
                    });
              }),
          SettingsScreenWidgets.tapTile(
              leading: const Icon(Icons.add_road_rounded),
              title: "Roadmap",
              onTap: () async {
                await showDialog(
                    context: context,
                    useRootNavigator: false,
                    builder: (BuildContext context) {
                      return SettingsScreenWidgets.roadmapDialog();
                    });
              }),
          // TODO: THIS MAY NEED AN EXTERNAL LICENSING SECTION.
        ]);
  }

  Widget _buildSignInOut() {
    return ValueListenableBuilder(
        valueListenable: userProvider.isConnected,
        builder: (BuildContext context, bool value, Widget? child) {
          if ((value || (kDebugMode && _mockOnline))) {
            return SettingsScreenWidgets.settingsSection(
              context: context,
              title: "",
              entries: [
                SettingsScreenWidgets.tapTile(
                    leading: Icon(Icons.highlight_off_rounded,
                        color: Theme.of(context).colorScheme.tertiary),
                    title: "Sign out",
                    onTap: () async {
                      if (kDebugMode) {
                        setState(() {
                          _mockOnline = false;
                        });
                      }
                      print("Sign out");
                      // Sign out of supabase, then push to account switcher.
                    }),
              ],
            );
          }
          // TODO: finish sign in dialog an hook up tile
          if (vm.syncOnline) {
            return SettingsScreenWidgets.tapTile(
                leading: const Icon(Icons.login_rounded),
                title: "Sign in",
                onTap: () async {
                  print("Sign in");
                });
          }

          return const SizedBox.shrink();
        });
  }

  // This should probably select userProvider.
  _buildDeleteAccount() {
    return SettingsScreenWidgets.settingsSection(
      context: context,
      title: "",
      entries: [
        SettingsScreenWidgets.tapTile(
            leading: Icon(Icons.delete_forever_rounded,
                color: Theme.of(context).colorScheme.error),
            textColor: Theme.of(context).colorScheme.error,
            title: "Delete account",
            onTap: () async {
              await showDialog<List<bool>?>(
                  context: context,
                  useRootNavigator: false,
                  builder: (BuildContext context) {
                    return const CheckDeleteDialog(
                      type: "Account",
                      showCheckbox: false,
                    );
                  }).then((deleteInfo) async {
                if (null == deleteInfo) {
                  return;
                }
                bool delete = deleteInfo[0];
                if (delete) {
                  // PUSH LOADING SCREEN TO CONTEXT.
                  // NUKE THE DB.
                  // RESTORE TO HOME SCRN w/default settings.
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (BuildContext context) =>
                            const LoadingScreen(),
                      ));
                  await Future.wait(
                    [
                      toDoProvider.clearDatabase(),
                      routineProvider.clearDatabase(),
                      reminderProvider.clearDatabase(),
                      deadlineProvider.clearDatabase(),
                      groupProvider.clearDatabase(),
                      subtaskProvider.clearDatabase(),

                      // This should notify -> resetting userVM, resets everything.
                      userProvider.deleteUser(),
                    ],
                  ).whenComplete(() {
                    layoutProvider.selectedPageIndex = 0;
                    Navigator.pop(context);
                  });
                }
              });
            }),
      ],
    );
  }

  List<Widget> getAvailableWindowEffects() {
    List<Widget> validEffects = List.empty(growable: true);

    bool filterWindows = (Platform.isWindows && !themeProvider.win11);
    for (Effect effect in Effect.values) {
      switch (effect) {
        case Effect.mica:
          if (Platform.isLinux || filterWindows) {
            continue;
          }
          break;
        case Effect.acrylic:
          if (Platform.isLinux || filterWindows) {
            continue;
          }
          break;
        case Effect.aero:
          if (Platform.isLinux) {
            continue;
          }
          break;
        case Effect.sidebar:
          if (!Platform.isMacOS) {
            continue;
          }
          break;
        default:
          break;
      }

      validEffects.add(
        SettingsScreenWidgets.radioTile<Effect>(
            member: effect,
            groupValue: themeProvider.windowEffect,
            onChanged: (newEffect) {
              if (null == newEffect) {
                return;
              }
              themeProvider.windowEffect = newEffect;
            }),
      );
    }
    return validEffects;
  }
}
