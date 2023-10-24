import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../model/task/routine.dart';
import '../../../providers/routine_provider.dart';
import '../../../util/constants.dart';
import '../../../util/enums.dart';
import '../../widgets/listview_header.dart';
import '../../widgets/listviews.dart';
import '../../widgets/paginating_listview.dart';
import '../../widgets/tiles.dart';
import '../sub_views/create_routine.dart';

class RoutinesListScreen extends StatefulWidget {
  const RoutinesListScreen({Key? key}) : super(key: key);

  @override
  State<RoutinesListScreen> createState() => _RoutinesListScreen();
}

class _RoutinesListScreen extends State<RoutinesListScreen> {
  late bool checkDelete;

  late final RoutineProvider routineProvider;

  @override
  void initState() {
    super.initState();
    initializeProviders();
    initializeParameters();
  }

  void initializeProviders() {
    routineProvider = Provider.of<RoutineProvider>(context, listen: false);
  }

  void initializeParameters() {
    checkDelete = true;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool largeScreen = (width >= Constants.largeScreen);
    bool smallScreen = (width <= Constants.smallScreen);

    return Padding(
      padding: const EdgeInsets.all(Constants.innerPadding),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListViewHeader<Routine>(
            header: "Routines",
            sorter: routineProvider.sorter,
            leadingIcon: const Icon(Icons.repeat_rounded),
            onChanged: (SortMethod? method) {
              if (null == method) {
                return;
              }
              if (mounted) {
                setState(() {
                  routineProvider.sortMethod = method;
                });
              }
            }),
        Tiles.createNew(
          context: context,
          onTap: () async => await showDialog(
            barrierDismissible: false,
            context: context,
            builder: (BuildContext context) => const CreateRoutineScreen(),
          ),
        ),
        Flexible(
          child: PaginatingListview<Routine>(
              items: routineProvider.routines,
              query: routineProvider.getRoutinesBy,
              offset: (routineProvider.rebuild)
                  ? 0
                  : routineProvider.routines.length,
              limit: Constants.minLimitPerQuery,
              rebuildNotifiers: [routineProvider],
              rebuildCallback: ({required List<Routine> items}) {
                routineProvider.routines = items;
                routineProvider.rebuild = false;
              },
              paginateButton: false,
              listviewBuilder: (
                  {required BuildContext context,
                  required List<Routine> items}) {
                if (routineProvider.sortMethod == SortMethod.none) {
                  return ListViews.reorderableRoutines(
                    context: context,
                    routines: items,
                    checkDelete: checkDelete,
                  );
                }
                return ListViews.immutableRoutines(
                  context: context,
                  routines: items,
                  checkDelete: checkDelete,
                );
              }),
        ),
      ]),
    );
  }
}
