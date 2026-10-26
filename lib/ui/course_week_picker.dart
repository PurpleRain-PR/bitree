import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _WeekPreset {
  all('全选'),
  none('全不选'),
  odd('单周'),
  even('双周');

  const _WeekPreset(this.label);

  final String label;

  Set<int> weeksIn(List<int> weeks) => switch (this) {
    all => weeks.toSet(),
    none => {},
    odd => weeks.where((week) => week.isOdd).toSet(),
    even => weeks.where((week) => week.isEven).toSet(),
  };
}

class CourseWeekPicker extends StatefulWidget {
  const CourseWeekPicker({
    super.key,
    required this.weeks,
    required this.selectedWeeks,
    required this.enabled,
    required this.onChanged,
    required this.onAddEarlierWeek,
  });

  final List<int> weeks;
  final Set<int> selectedWeeks;
  final bool enabled;
  final ValueChanged<Set<int>> onChanged;
  final VoidCallback onAddEarlierWeek;

  @override
  State<CourseWeekPicker> createState() => _CourseWeekPickerState();
}

class _CourseWeekPickerState extends State<CourseWeekPicker> {
  static const _spacing = 4.0;
  final _grid = GlobalKey();
  ({int start, int end, Set<int> before})? _range;
  Offset? _dragPosition;
  EdgeDraggingAutoScroller? _autoScroller;

  @override
  void didUpdateWidget(covariant CourseWeekPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _endRange();
  }

  @override
  void dispose() {
    _endRange();
    super.dispose();
  }

  ({int columns, double width, double height}) _dimensions(double width) {
    final fontSize = MediaQuery.textScalerOf(context).scale(14);
    final minimumWidth = math.max(48.0, fontSize * 2 + 16);
    final columns = ((width + _spacing) / (minimumWidth + _spacing))
        .floor()
        .clamp(1, 7);
    return (
      columns: columns,
      width: (width - (columns - 1) * _spacing) / columns,
      height: math.max(48.0, fontSize * 1.4 + 16),
    );
  }

  int _indexAt(Offset globalPosition) {
    final box = _grid.currentContext!.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(globalPosition);
    final dimensions = _dimensions(box.size.width);
    final x = Directionality.of(context) == TextDirection.ltr
        ? local.dx
        : box.size.width - local.dx;
    final column = (x / (dimensions.width + _spacing)).floor().clamp(
      0,
      dimensions.columns - 1,
    );
    final row = (local.dy / (dimensions.height + _spacing)).floor();
    return row * dimensions.columns + column;
  }

  void _startRange(Offset position) {
    final index = _indexAt(position);
    if (index < 0 || index >= widget.weeks.length) return;

    _range = (start: index, end: index, before: {...widget.selectedWeeks});
    _dragPosition = position;
    _autoScroller = EdgeDraggingAutoScroller(
      Scrollable.of(context),
      velocityScalar: 20,
      onScrollViewScrolled: () {
        final position = _dragPosition;
        if (position != null) _dragRange(position);
      },
    );
    HapticFeedback.selectionClick();
    widget.onChanged({widget.weeks[index]});
  }

  void _updateRange(Offset position) {
    final range = _range;
    if (range == null) return;
    final end = _indexAt(position).clamp(0, widget.weeks.length - 1);
    if (end == range.end) return;

    _range = (start: range.start, end: end, before: range.before);
    final first = math.min(range.start, end);
    final last = math.max(range.start, end);
    widget.onChanged(widget.weeks.sublist(first, last + 1).toSet());
    HapticFeedback.selectionClick();
  }

  void _dragRange(Offset position) {
    if (_range == null) return;
    _dragPosition = position;
    _updateRange(position);
    _autoScroller!.startAutoScrollIfNecessary(
      Rect.fromCenter(center: position, width: 1, height: 1),
    );
  }

  void _endRange() {
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
    _dragPosition = null;
    _range = null;
  }

  void _finishRange(Offset position) {
    _updateRange(position);
    _endRange();
  }

  void _cancelRange() {
    final before = _range?.before;
    _endRange();
    if (before != null) widget.onChanged(before);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weeks = widget.weeks;
    final selectedWeeks = widget.selectedWeeks;
    final enabled = widget.enabled;
    final onChanged = widget.onChanged;
    final selectedPreset = _WeekPreset.values
        .where((preset) => setEquals(preset.weeksIn(weeks), selectedWeeks))
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '上课周次',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: enabled ? widget.onAddEarlierWeek : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: theme.textTheme.labelMedium,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('增加小学期'),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: SegmentedButton<_WeekPreset>(
                segments: [
                  for (final preset in _WeekPreset.values)
                    ButtonSegment(value: preset, label: Text(preset.label)),
                ],
                selected: {?selectedPreset},
                emptySelectionAllowed: selectedPreset == null,
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: theme.textTheme.labelMedium,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  selectedForegroundColor: theme.colorScheme.onPrimaryContainer,
                  selectedBackgroundColor: theme.colorScheme.primaryContainer,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onSelectionChanged: enabled
                    ? (selection) => onChanged(selection.single.weeksIn(weeks))
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final dimensions = _dimensions(constraints.maxWidth);
            return GestureDetector(
              supportedDevices: const {PointerDeviceKind.mouse},
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onPanStart: enabled
                  ? (details) => _startRange(details.globalPosition)
                  : null,
              onPanUpdate: enabled
                  ? (details) => _dragRange(details.globalPosition)
                  : null,
              onPanEnd: enabled
                  ? (details) => _finishRange(details.globalPosition)
                  : null,
              onPanCancel: enabled ? _cancelRange : null,
              child: GestureDetector(
                key: _grid,
                supportedDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                  PointerDeviceKind.trackpad,
                },
                behavior: HitTestBehavior.opaque,
                onLongPressStart: enabled
                    ? (details) => _startRange(details.globalPosition)
                    : null,
                onLongPressMoveUpdate: enabled
                    ? (details) => _dragRange(details.globalPosition)
                    : null,
                onLongPressEnd: enabled
                    ? (details) => _finishRange(details.globalPosition)
                    : null,
                onLongPressCancel: enabled ? _cancelRange : null,
                child: GridView.builder(
                  shrinkWrap: true,
                  primary: false,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: dimensions.columns,
                    crossAxisSpacing: _spacing,
                    mainAxisSpacing: _spacing,
                    mainAxisExtent: dimensions.height,
                  ),
                  itemCount: weeks.length,
                  itemBuilder: (context, index) {
                    final week = weeks[index];
                    final selected = selectedWeeks.contains(week);
                    return Semantics(
                      selected: selected,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: selected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          foregroundColor: selected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                          side: BorderSide(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        onPressed: !enabled
                            ? null
                            : () {
                                final weeks = {...selectedWeeks};
                                if (selected) {
                                  weeks.remove(week);
                                } else {
                                  weeks.add(week);
                                }
                                onChanged(weeks);
                              },
                        child: Text('$week', semanticsLabel: '第 $week 周'),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
