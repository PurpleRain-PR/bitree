import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../agenda/calendar.dart';
import '../schedule/layout.dart';
import '../schedule/model.dart';
import '../schedule/time_position.dart';
import 'timetable_grid.dart';
import 'timetable_header.dart';

class Timetable extends StatefulWidget {
  const Timetable({
    super.key,
    required this.controller,
    required this.week,
    required this.initialScrollOffset,
    required this.onScroll,
    this.timeRevealRequest,
    this.onTimeRevealHandled,
  });

  final AppController controller;
  final int week;
  final double initialScrollOffset;
  final ValueChanged<double> onScroll;
  final int? timeRevealRequest;
  final VoidCallback? onTimeRevealHandled;

  @override
  State<Timetable> createState() => _TimetableState();
}

class _TimetableState extends State<Timetable> {
  late final ScrollController _vertical;
  int? _handledTimeReveal;

  void _revealCurrentTime(double rowHeight) {
    final request = widget.timeRevealRequest;
    if (request == null || request == _handledTimeReveal) return;
    _handledTimeReveal = request;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.timeRevealRequest != request ||
          widget.controller.week != widget.week ||
          !_vertical.hasClients) {
        return;
      }
      widget.onTimeRevealHandled?.call();
      final now = campusNow();
      final schedule = widget.controller.schedule;
      if (schedule == null || schedule.weekAt(now) != widget.week) return;
      final offset = sectionOffsetAt(now);

      final position = _vertical.position;
      if (!position.hasContentDimensions || position.viewportDimension <= 0) {
        return;
      }
      // Leave context above and below the line; clamp near the day's edges.
      final target = (offset * rowHeight - position.viewportDimension / 2)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      _vertical.jumpTo(target);
    });
  }

  @override
  void initState() {
    super.initState();
    _vertical = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
      keepScrollOffset: false,
    )..addListener(_rememberScroll);
  }

  void _rememberScroll() => widget.onScroll(_vertical.offset);

  @override
  void dispose() {
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final schedule = controller.schedule!;
    final monday = schedule.mondayAt(widget.week);
    final today = calendarDate(campusNow());
    final currentWeek = schedule.weekAt(today) == widget.week;
    final todayColumn = currentWeek ? today.weekday - 1 : null;
    final todayBackground = Theme.of(context).colorScheme.primary
        .withValues(alpha: 0.12);
    final scale = MediaQuery.textScalerOf(context).scale(1);

    final days = [
      for (var day = 0; day < 7; day++)
        calendarItemsOn(
          monday.add(Duration(days: day)),
          schedule,
          controller.agenda.entries,
        ),
    ];
    final pinned = [
      for (var day = 0; day < 7; day++)
        days[day]
            .where(
              (item) =>
                  item.pinned ||
                  outsideTimetable(item, monday.add(Duration(days: day))),
            )
            .toList(),
    ];
    final layouts = [
      for (var day = 0; day < 7; day++)
        groupCalendarItems(
          days[day].where((item) => !pinned[day].contains(item)).toList(),
          monday.add(Duration(days: day)),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutterWidth = 30.0 * scale;
        final dateHeight = 46.0 * scale;
        final pinnedHeight = pinned.any((items) => items.isNotEmpty)
            ? 32.0 * scale
            : 0.0;
        final rowHeight = math.max(
          48.0 * scale,
          (constraints.maxHeight - dateHeight - pinnedHeight) /
              sectionTimes.length,
        );
        _revealCurrentTime(rowHeight);

        return Column(
          children: [
            TimetableHeader(
              controller: controller,
              monday: monday,
              today: today,
              days: days,
              pinned: pinned,
              gutterWidth: gutterWidth,
              dateHeight: dateHeight,
              pinnedHeight: pinnedHeight,
              todayBackground: todayBackground,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _vertical,
                child: RepaintBoundary(
                  child: TimetableGrid(
                    controller: controller,
                    monday: monday,
                    layouts: layouts,
                    gutterWidth: gutterWidth,
                    rowHeight: rowHeight,
                    todayColumn: todayColumn,
                    todayBackground: todayBackground,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
