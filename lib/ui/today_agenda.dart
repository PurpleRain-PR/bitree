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
    final summary = entries.isEmpty
        ? '暂无待办'
        : '${entries.length}项${entries.every((entry) => entry.isDeadline) ? '待办' : '日程'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Semantics(
            label: '${agendaDateLabel(now)}，$summary',
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${now.month}月${now.day}日',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(summary, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 8.0;
                  final columns =
                      ((constraints.maxWidth + gap) / (scale.scale(108) + gap))
                          .floor()
                          .clamp(1, 4);
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;

                  return SizedBox(
                    height: scale.scale(13) * 1.4 + scale.scale(12) * 1.4 + 24,
                    child: ScrollConfiguration(
                      behavior: behavior.copyWith(
                        scrollbars: false,
                        dragDevices: {
                          ...behavior.dragDevices,
                          PointerDeviceKind.mouse,
                        },
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
                                  onTap: () => showAgendaEntry(
                                    context,
                                    controller,
                                    entry,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          entry.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
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
                                            height: 1.4,
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
            ),
          ],
        ],
      ),
    );
  }
}
