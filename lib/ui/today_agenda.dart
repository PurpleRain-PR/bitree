import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../agenda/model.dart';
import '../app_controller.dart';
import 'agenda_detail.dart';
import 'agenda_time.dart';

class TodayAgenda extends StatelessWidget {
  const TodayAgenda({
    super.key,
    required this.controller,
    required this.entries,
    required this.now,
  });

  final AppController controller;
  final List<AgendaEntry> entries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scale = MediaQuery.textScalerOf(context);
    final behavior = ScrollConfiguration.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final columns =
              ((constraints.maxWidth + gap) / (scale.scale(120) + gap))
                  .floor()
                  .clamp(1, 4);
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

          return SizedBox(
            height: scale.scale(12) * 2.9 + 20,
            child: ScrollConfiguration(
              behavior: behavior.copyWith(
                scrollbars: false,
                dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
              ),
              child: ListView.separated(
                primary: false,
                scrollDirection: Axis.horizontal,
                itemCount: entries.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: gap),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final caption = entry.isDeadline || entry.allDay
                      ? entry.timeLabel
                      : entry.startsAt.isAfter(now)
                      ? '${agendaClockLabel(entry)} 开始'
                      : '进行中';

                  return SizedBox(
                    width: width,
                    child: Tooltip(
                      message: '${entry.title}\n${entry.timeLabel}',
                      child: Material(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () =>
                              showAgendaEntry(context, controller, entry),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  entry.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.45,
                                    color: entry.overdue(now)
                                        ? scheme.error
                                        : scheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
