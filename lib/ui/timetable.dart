import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../schedule/controller.dart';
import '../schedule/layout.dart';
import '../schedule/model.dart';
import 'course_detail.dart';
import 'theme.dart';

class Timetable extends StatefulWidget {
  const Timetable({
    super.key,
    required this.controller,
    required this.week,
    required this.initialScrollOffset,
    required this.onScroll,
  });
  final ScheduleController controller;
  final int week;
  final double initialScrollOffset;
  final ValueChanged<double> onScroll;
  @override
  State<Timetable> createState() => _TimetableState();
}

class _TimetableState extends State<Timetable> {
  final _horizontal = ScrollController();
  final _dates = ScrollController();
  late final ScrollController _vertical;
  DateTime? _shownMonday;

  @override
  void initState() {
    super.initState();
    _horizontal.addListener(_alignDates);
    _vertical = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
      keepScrollOffset: false,
    )..addListener(_rememberScroll);
  }

  void _rememberScroll() => widget.onScroll(_vertical.offset);

  void _alignDates() {
    if (!_horizontal.hasClients || !_dates.hasClients) return;
    final offset = _horizontal.offset.clamp(
      _dates.position.minScrollExtent,
      _dates.position.maxScrollExtent,
    );
    if (_dates.offset != offset) _dates.jumpTo(offset);
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _dates.dispose();
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
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final layouts = [
      for (var day = 1; day <= 7; day++)
        layoutDayCourses(schedule.coursesAt(widget.week, weekday: day)),
    ];
    var minimumColumn = 42.0 * scale;
    for (final day in layouts) {
      for (final placement in day) {
        minimumColumn = math.max(minimumColumn, 42 * scale * placement.lanes);
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = 30.0 * scale;
        final headerHeight = 64.0 * scale;
        final column = math.max(
          minimumColumn,
          (constraints.maxWidth - gutter) / 7,
        );
        final width = column * 7;
        final viewport = constraints.maxWidth - gutter;
        final rowHeight = math.max(
          (constraints.maxWidth < 680 ? 76.0 : 52.0) * scale,
          (constraints.maxHeight - headerHeight) / sectionTimes.length,
        );
        final gridHeight = rowHeight * sectionTimes.length;
        if (_shownMonday != monday) {
          _shownMonday = monday;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_horizontal.hasClients) return;
            final current = schedule.weekAt(today) == widget.week;
            final offset = current ? today.weekday * column - viewport : 0.0;
            _horizontal.jumpTo(
              offset.clamp(0.0, _horizontal.position.maxScrollExtent),
            );
          });
        }
        return Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: gutter,
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
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        controller: _dates,
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Row(
                          children: [
                            for (var day = 1; day <= 7; day++)
                              SizedBox(
                                width: column,
                                height: headerHeight,
                                child: _DateHeading(
                                  date: monday.add(Duration(days: day - 1)),
                                  today: today,
                                ),
                              ),
                          ],
                        ),
                      ),
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
                        width: gutter,
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
                        child: Scrollbar(
                          controller: _horizontal,
                          thumbVisibility: width > viewport + 1,
                          child: SingleChildScrollView(
                            controller: _horizontal,
                            scrollDirection: Axis.horizontal,
                            physics: width > viewport + 1
                                ? const ClampingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            child: SizedBox(
                              width: width,
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
                                        left: day * column + 2,
                                        top: section * rowHeight + 2,
                                        width: column - 4,
                                        height: rowHeight - 4,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: scheme.onSurface.withValues(
                                              alpha: section.isEven
                                                  ? 0.025
                                                  : 0.045,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                      ),
                                  for (var day = 0; day < 7; day++)
                                    if (monday.add(Duration(days: day)) ==
                                        today)
                                      Positioned(
                                        left: day * column,
                                        width: column,
                                        top: 0,
                                        bottom: 0,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: scheme.primary.withValues(
                                              alpha: 0.045,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                      ),
                                  for (var day = 0; day < 7; day++)
                                    for (final placement in layouts[day])
                                      Positioned(
                                        key: ValueKey(placement.course.id),
                                        left:
                                            day * column +
                                            placement.lane *
                                                column /
                                                placement.lanes +
                                            2,
                                        width: column / placement.lanes - 4,
                                        top:
                                            (placement.course.startSection! -
                                                    1) *
                                                rowHeight +
                                            2,
                                        height:
                                            (placement.course.endSection! -
                                                    placement
                                                        .course
                                                        .startSection! +
                                                    1) *
                                                rowHeight -
                                            4,
                                        child: _CourseBlock(
                                          course: placement.course,
                                          controller: controller,
                                          isToday:
                                              monday.add(Duration(days: day)) ==
                                              today,
                                        ),
                                      ),
                                ],
                              ),
                            ),
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
  const _DateHeading({required this.date, required this.today});
  final DateTime date;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = date == today;
    return Semantics(
      label:
          '${date.month}月${date.day}日${weekdays[date.weekday - 1]}${current ? '，今天' : ''}',
      child: ExcludeSemantics(
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
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: current ? scheme.primary : null,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  color: current ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
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
            const SizedBox(height: 4),
            Text(
              '${time.$1}\n${time.$2}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                height: 1.35,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseBlock extends StatelessWidget {
  const _CourseBlock({
    required this.course,
    required this.controller,
    required this.isToday,
  });
  final Course course;
  final ScheduleController controller;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colors = courseColors(context, course.colorIndex);
    return Semantics(
      button: true,
      label:
          '${course.name}，${course.timeLabel}，${course.room}${isToday ? '，今天' : ''}，查看详情',
      child: ExcludeSemantics(
        child: Tooltip(
          message: '${course.name}\n${course.room}\n${course.teacher}',
          child: Material(
            color: colors.fill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: isToday
                  ? BorderSide(color: colors.accent, width: 1.5)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showCourse(context, controller, course),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 100;
                  final fontSize = narrow ? 12.0 : 14.0;
                  final scaler = MediaQuery.textScalerOf(context);
                  final titleHeight = scaler.scale(fontSize) * 1.35;
                  final roomLineHeight = scaler.scale(fontSize - 1) * 1.3;
                  final available = constraints.maxHeight - 12;
                  final roomLines = course.room.isEmpty
                      ? 0
                      : ((available - titleHeight * 2 - 8) / roomLineHeight)
                            .floor()
                            .clamp(0, narrow ? 4 : 2);
                  final roomStyle = TextStyle(
                    fontSize: fontSize - 1,
                    height: 1.3,
                    color: colors.text,
                  );
                  var roomHeight = 0.0;
                  if (roomLines > 0) {
                    final painter =
                        TextPainter(
                          text: TextSpan(
                            text: course.room,
                            style: DefaultTextStyle.of(
                              context,
                            ).style.merge(roomStyle),
                          ),
                          textDirection: Directionality.of(context),
                          textScaler: scaler,
                          maxLines: roomLines,
                        )..layout(
                          maxWidth: constraints.maxWidth - (narrow ? 6 : 20),
                        );
                    roomHeight = painter.height + 8;
                    painter.dispose();
                  }
                  final titleLines = ((available - roomHeight) / titleHeight)
                      .floor()
                      .clamp(1, 5);
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: narrow ? 3 : 10,
                      vertical: 6,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          course.name,
                          textAlign: TextAlign.center,
                          maxLines: titleLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: fontSize,
                            height: 1.35,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        if (roomLines > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            course.room,
                            textAlign: TextAlign.center,
                            maxLines: roomLines,
                            overflow: TextOverflow.ellipsis,
                            style: roomStyle,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
