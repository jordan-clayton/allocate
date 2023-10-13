import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../../util/constants.dart';

class TimeDialog extends StatefulWidget {
  const TimeDialog({Key? key, this.startTime, this.dueTime}) : super(key: key);

  final TimeOfDay? startTime;
  final TimeOfDay? dueTime;

  @override
  State<TimeDialog> createState() => _TimeDialog();
}

class _TimeDialog extends State<TimeDialog> {
  late TimeOfDay? startTime;
  late TimeOfDay? dueTime;

  @override
  void initState() {
    startTime = widget.startTime;
    dueTime = widget.dueTime;
    super.initState();
  }

  @override
  Widget build(context) {
    return Dialog(
        insetPadding: const EdgeInsets.all(Constants.innerPadding),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.only(right: Constants.padding),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    Constants.roundedCorners),
                                border: Border.all(
                                    width: 2,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                    strokeAlign: BorderSide.strokeAlignOutside),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Expanded(
                                    child: TextButton(
                                        onPressed: () async {
                                          final TimeOfDay? picked =
                                              await showTimePicker(
                                                  context: context,
                                                  initialTime: startTime ??
                                                      Constants.midnight);
                                          if (null != picked) {
                                            setState(() => startTime = picked);
                                          }
                                        },
                                        child: (null != startTime)
                                            ? AutoSizeText(
                                                startTime!
                                                    .format(context)
                                                    .toString(),
                                                softWrap: false,
                                                overflow: TextOverflow.visible,
                                                maxLines: 1,
                                                minFontSize: Constants.huge,
                                              )
                                            : const AutoSizeText("Start Time",
                                                softWrap: true,
                                                overflow: TextOverflow.visible,
                                                maxLines: 1,
                                                minFontSize: Constants.huge)),
                                  ),
                                  (startTime != null)
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded),
                                          selectedIcon: const Icon(Icons.clear),
                                          onPressed: () => setState(() {
                                            startTime = null;
                                          }),
                                        )
                                      : const SizedBox.shrink(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.only(left: Constants.padding),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    Constants.roundedCorners),
                                border: Border.all(
                                    width: 2,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                    strokeAlign: BorderSide.strokeAlignOutside),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Expanded(
                                    child: TextButton(
                                        onPressed: () async {
                                          final TimeOfDay? picked =
                                              await showTimePicker(
                                                  context: context,
                                                  initialTime: dueTime ??
                                                      Constants.midnight);
                                          if (null != picked) {
                                            setState(() => dueTime = picked);
                                          }
                                        },
                                        child: (null != dueTime)
                                            ? AutoSizeText(
                                                dueTime!
                                                    .format(context)
                                                    .toString(),
                                                softWrap: false,
                                                overflow: TextOverflow.visible,
                                                maxLines: 1,
                                                minFontSize: Constants.huge,
                                              )
                                            : const AutoSizeText("Due Time",
                                                softWrap: true,
                                                overflow: TextOverflow.visible,
                                                maxLines: 1,
                                                minFontSize: Constants.huge)),
                                  ),
                                  (dueTime != null)
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded),
                                          selectedIcon: const Icon(Icons.clear),
                                          onPressed: () => setState(() {
                                            dueTime = null;
                                          }),
                                        )
                                      : const SizedBox.shrink(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.only(right: Constants.padding),
                          child: FilledButton.tonalIcon(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              label: const AutoSizeText("Cancel",
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                  maxLines: 1,
                                  minFontSize: Constants.small)),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.only(left: Constants.padding),
                          child: FilledButton.icon(
                            icon: const Icon(Icons.done_rounded),
                            onPressed: () {
                              Navigator.pop(context, [startTime, dueTime]);
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
        ));
  }
}