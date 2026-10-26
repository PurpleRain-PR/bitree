import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../schedule/layout.dart';
import '../schedule/model.dart';
import 'conflicting_courses.dart';
import 'course_tile.dart';

class Timetable extends StatefulWidget {
  const Timetable({
    super.key,
    required this.controller,
    required this.week,
    required this.initialScrollOffset,
    required this.onScroll,
  });

  final AppController controller;
  final int week;
  final double initialScrollOffset;
  final ValueChanged<double> onScroll;

  @override
  State<Timetable> createState() => _TimetableState();
}

class _TimetableState extends State<Timetable> {
  late final ScrollController _vertical;

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
    final scheme = Theme.of(context).colorScheme;
    final currentWeek = schedule.weekAt(today) == widget.week;
    final todayColumn = currentWeek ? today.weekday - 1 : null;
    final todayBackground = scheme.primary.withValues(alpha: 0.12);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final layouts = [
      for (var day = 1; day <= 7; day++)
        groupOverlappingCourses(schedule.coursesAt(widget.week, weekday: day)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutterWidth = 30.0 * scale;
        final headerHeight = 46.0 * scale;
        final columnWidth = (constraints.maxWidth - gutterWidth) / 7;
        final gridWidth = columnWidth * 7;
        final rowHeight = math.max(
          48.0 * scale,
          (constraints.maxHeight - headerHeight) / sectionTimes.length,
        );
        final gridHeight = rowHeight * sectionTimes.length;
        return Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: gutterWidth,
                    child: Center(
                      child: Text(
                        '${monday.month}月',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        for (var day = 1; day <= 7; day++)
                          SizedBox(
                            width: columnWidth,
                            height: headerHeight,
                            child: _DateHeading(
                              date: monday.add(Duration(days: day - 1)),
                              today: today,
                              todayBackground: todayBackground,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _vertical,
                child: SizedBox(
                  height: gridHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: gutterWidth,
                        child: Column(
                          children: [
                            for (
                              var section = 1;
                              section <= sectionTimes.length;
                              section++
                            )
                              SizedBox(
                                height: rowHeight,
                                child: _PeriodLabel(section: section),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          width: gridWidth,
                          height: gridHeight,
                          child: Stack(
                            children: [
                              for (
                                var section = 0;
                                section < sectionTimes.length;
                                section++
                              )
                                for (var day = 0; day < 7; day++)
                                  Positioned(
                                    left: day * columnWidth + 2,
                                    top: section * rowHeight + 2,
                                    width: columnWidth - 4,
                                    height: rowHeight - 4,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: scheme.onSurface.withValues(
                                          alpha: section.isEven ? 0.025 : 0.045,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                              for (var day = 0; day < 7; day++)
                                if (day == todayColumn)
                                  Positioned(
                                    left: day * columnWidth + 2,
                                    width: columnWidth - 4,
                                    top: 0,
                                    bottom: 0,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: todayBackground,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              bottom: Radius.circular(6),
                                            ),
                                      ),
                                    ),
                                  ),
                              for (var day = 0; day < 7; day++)
                                for (final block in layouts[day])
                                  Positioned(
                                    key: ValueKey((day, block.startSection)),
                                    left: day * columnWidth + 2,
                                    width: columnWidth - 4,
                                    top:
                                        (block.startSection - 1) * rowHeight +
                                        2,
                                    height:
                                        (block.endSection -
                                                block.startSection +
                                                1) *
                                            rowHeight -
                                        4,
                                    child: block.courses.length == 1
                                        ? CourseTile(
                                            course: block.courses.single,
                                            controller: controller,
                                            isToday: day == todayColumn,
                                          )
                                        : ConflictingCourses(
                                            courses: block.courses,
                                            controller: controller,
                                            isToday: day == todayColumn,
                                          ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _DateHeading extends StatelessWidget {
  const _DateHeading({
    required this.date,
    required this.today,
    required this.todayBackground,
  });

  final DateTime date;
  final DateTime today;
  final Color todayBackground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = date == today;
    return Semantics(
      label:
          '${date.month}月${date.day}日${weekdays[date.weekday - 1]}${current ? '，今天' : ''}',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: current ? todayBackground : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdays[date.weekday - 1].substring(1),
                style: TextStyle(
                  fontSize: 12,
                  color: current ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: current ? scheme.primary : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                      color: current
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodLabel extends StatelessWidget {
  const _PeriodLabel({required this.section});

  final int section;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = sectionTimes[section - 1];
    return Semantics(
      label: '第 $section 节，${time.$1}–${time.$2}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$section',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${time.$1}\n${time.$2}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                height: 1.2,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
