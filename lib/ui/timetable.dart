import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../agenda/calendar.dart';
import '../agenda/model.dart';
import '../schedule/layout.dart';
import '../schedule/model.dart';
import '../schedule/selection.dart';
import 'add_menu.dart';
import 'calendar_block.dart';
import 'calendar_list.dart';

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
  final _grid = GlobalKey();
  final _viewport = GlobalKey();
  ({int day, int anchor, int end})? _selection;
  Offset? _dragPosition;
  Timer? _scrollTimer;

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
    _scrollTimer?.cancel();
    _vertical.dispose();
    super.dispose();
  }

  bool _occupied(List<CalendarBlock> blocks, int section) =>
      blocks.any((block) => block.start < section && block.end > section - 1);

  void _beginSelection(
    Offset global,
    double columnWidth,
    double rowHeight,
    List<List<CalendarBlock>> layouts,
  ) {
    if (widget.controller.busy) return;
    final box = _grid.currentContext!.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(global);
    final day = (local.dx / columnWidth).floor().clamp(0, 6);
    final section =
        (local.dy / rowHeight).floor().clamp(0, sectionTimes.length - 1) + 1;
    if (_occupied(layouts[day], section)) return;
    setState(() => _selection = (day: day, anchor: section, end: section));
  }

  void _extendSelection(
    Offset global,
    double rowHeight,
    List<List<CalendarBlock>> layouts,
  ) {
    final selection = _selection;
    if (selection == null) return;
    final box = _grid.currentContext!.findRenderObject()! as RenderBox;
    final target =
        (box.globalToLocal(global).dy / rowHeight).floor().clamp(
          0,
          sectionTimes.length - 1,
        ) +
        1;
    var end = selection.anchor;
    final direction = target >= end ? 1 : -1;
    while (end != target) {
      if (_occupied(layouts[selection.day], end + direction)) break;
      end += direction;
    }
    if (end != selection.end) {
      setState(
        () => _selection = (
          day: selection.day,
          anchor: selection.anchor,
          end: end,
        ),
      );
    }
  }

  void _startDrag(
    Offset position,
    double columnWidth,
    double rowHeight,
    List<List<CalendarBlock>> layouts,
  ) {
    _beginSelection(position, columnWidth, rowHeight, layouts);
    if (_selection == null) return;
    HapticFeedback.selectionClick();
    _dragPosition = position;
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final box = _viewport.currentContext!.findRenderObject()! as RenderBox;
      final y = box.globalToLocal(_dragPosition!).dy;
      final delta = y < 36
          ? -6.0
          : y > box.size.height - 36
          ? 6.0
          : 0.0;
      if (delta != 0) {
        _vertical.jumpTo(
          (_vertical.offset + delta).clamp(
            _vertical.position.minScrollExtent,
            _vertical.position.maxScrollExtent,
          ),
        );
        _extendSelection(_dragPosition!, rowHeight, layouts);
      }
    });
  }

  Future<void> _finishSelection(Offset position) async {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _dragPosition = null;
    final selection = _selection;
    if (selection == null) return;
    final date = widget.controller.schedule!
        .mondayAt(widget.week)
        .add(Duration(days: selection.day));
    await showAddMenu(
      context,
      widget.controller,
      position,
      selection: TimetableSelection(
        date: date,
        startSection: math.min(selection.anchor, selection.end),
        endSection: math.max(selection.anchor, selection.end),
      ),
    );
    if (mounted) setState(() => _selection = null);
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
    final days = [
      for (var day = 1; day <= 7; day++)
        calendarItemsOn(
          monday.add(Duration(days: day - 1)),
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
        final headerHeight = 46.0 * scale;
        final pinnedHeight = pinned.any((items) => items.isNotEmpty)
            ? 32.0 * scale
            : 0.0;
        final columnWidth = (constraints.maxWidth - gutterWidth) / 7;
        final gridWidth = columnWidth * 7;
        final rowHeight = math.max(
          48.0 * scale,
          (constraints.maxHeight - headerHeight - pinnedHeight) /
              sectionTimes.length,
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
                            child: InkWell(
                              onTap: () => showCalendarItems(
                                context,
                                controller,
                                agendaDateLabel(
                                  monday.add(Duration(days: day - 1)),
                                ),
                                days[day - 1],
                              ),
                              child: _DateHeading(
                                date: monday.add(Duration(days: day - 1)),
                                today: today,
                                todayBackground: todayBackground,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (pinnedHeight > 0)
              SizedBox(
                height: pinnedHeight,
                child: Row(
                  children: [
                    SizedBox(width: gutterWidth),
                    for (var day = 0; day < 7; day++)
                      SizedBox(
                        width: columnWidth,
                        child: pinned[day].isEmpty
                            ? null
                            : Padding(
                                padding: const EdgeInsets.all(2),
                                child: Tooltip(
                                  message: pinned[day]
                                      .map((item) => item.title)
                                      .join('\n'),
                                  child: Material(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(4),
                                      onTap: () => showCalendarItems(
                                        context,
                                        controller,
                                        agendaDateLabel(
                                          monday.add(Duration(days: day)),
                                        ),
                                        pinned[day],
                                      ),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          child: Text(
                                            pinned[day].length == 1
                                                ? '${pinned[day].single.kindLabel} ${pinned[day].single.title}'
                                                : '${pinned[day].length} 项',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: scheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            Expanded(
              key: _viewport,
              child: SingleChildScrollView(
                controller: _vertical,
                child: RepaintBoundary(
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
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) {
                                _beginSelection(
                                  details.globalPosition,
                                  columnWidth,
                                  rowHeight,
                                  layouts,
                                );
                                _finishSelection(details.globalPosition);
                              },
                              onLongPressStart: (details) => _startDrag(
                                details.globalPosition,
                                columnWidth,
                                rowHeight,
                                layouts,
                              ),
                              onLongPressMoveUpdate: (details) {
                                _dragPosition = details.globalPosition;
                                _extendSelection(
                                  details.globalPosition,
                                  rowHeight,
                                  layouts,
                                );
                              },
                              onLongPressEnd: (details) =>
                                  _finishSelection(details.globalPosition),
                              onLongPressCancel: () {
                                _scrollTimer?.cancel();
                                _dragPosition = null;
                                setState(() => _selection = null);
                              },
                              child: Stack(
                                key: _grid,
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _TimetableBackground(
                                        rowHeight: rowHeight,
                                        surfaceColor: scheme.onSurface,
                                        todayColumn: todayColumn,
                                        todayBackground: todayBackground,
                                      ),
                                    ),
                                  ),
                                  for (var day = 0; day < 7; day++)
                                    for (final block in layouts[day])
                                      Positioned(
                                        key: ValueKey((day, block.start)),
                                        left: day * columnWidth + 2,
                                        width: columnWidth - 4,
                                        top: block.start * rowHeight + 2,
                                        height:
                                            (block.end - block.start) *
                                                rowHeight -
                                            4,
                                        child: CalendarBlockTile(
                                          items: block.items,
                                          controller: controller,
                                          isToday: day == todayColumn,
                                        ),
                                      ),
                                  if (_selection case final selection?)
                                    Positioned(
                                      left: selection.day * columnWidth + 2,
                                      width: columnWidth - 4,
                                      top:
                                          (math.min(
                                                    selection.anchor,
                                                    selection.end,
                                                  ) -
                                                  1) *
                                              rowHeight +
                                          2,
                                      height:
                                          ((selection.end - selection.anchor)
                                                      .abs() +
                                                  1) *
                                              rowHeight -
                                          4,
                                      child: IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: scheme.primary.withValues(
                                              alpha: 0.18,
                                            ),
                                            border: Border.all(
                                              color: scheme.primary,
                                              width: 1.5,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
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
                    ),
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

class _TimetableBackground extends CustomPainter {
  const _TimetableBackground({
    required this.rowHeight,
    required this.surfaceColor,
    required this.todayColumn,
    required this.todayBackground,
  });

  final double rowHeight;
  final Color surfaceColor;
  final int? todayColumn;
  final Color todayBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final columnWidth = size.width / 7;
    final paint = Paint();
    const radius = Radius.circular(6);

    for (var section = 0; section < sectionTimes.length; section++) {
      paint.color = surfaceColor.withValues(
        alpha: section.isEven ? 0.025 : 0.045,
      );
      for (var day = 0; day < 7; day++) {
        final cell = Rect.fromLTWH(
          day * columnWidth + 2,
          section * rowHeight + 2,
          columnWidth - 4,
          rowHeight - 4,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(cell, radius), paint);
      }
    }

    if (todayColumn != null) {
      final column = Rect.fromLTWH(
        todayColumn! * columnWidth + 2,
        0,
        columnWidth - 4,
        size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          column,
          bottomLeft: radius,
          bottomRight: radius,
        ),
        paint..color = todayBackground,
      );
    }
  }

  @override
  bool shouldRepaint(_TimetableBackground oldDelegate) =>
      rowHeight != oldDelegate.rowHeight ||
      surfaceColor != oldDelegate.surfaceColor ||
      todayColumn != oldDelegate.todayColumn ||
      todayBackground != oldDelegate.todayBackground;
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
