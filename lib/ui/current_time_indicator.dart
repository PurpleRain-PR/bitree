import 'dart:async';

import 'package:flutter/material.dart';

import '../schedule/model.dart';
import '../schedule/time_position.dart';

/// A non-interactive overlay for the timetable's equal-height section grid.
class CurrentTimeIndicator extends StatefulWidget {
  const CurrentTimeIndicator({
    super.key,
    required this.monday,
    required this.columnWidth,
    required this.rowHeight,
  });

  final DateTime monday;
  final double columnWidth;
  final double rowHeight;

  @override
  State<CurrentTimeIndicator> createState() => _CurrentTimeIndicatorState();
}

class _CurrentTimeIndicatorState extends State<CurrentTimeIndicator>
    with WidgetsBindingObserver {
  static const _lineHeight = 3.0;
  static const _horizontalInset = 3.0;

  Timer? _timer;
  DateTime _now = campusNow();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      _scheduleTick();
    }
  }

  void _scheduleTick() {
    _timer?.cancel();
    final now = campusNow();
    // Align updates to minute boundaries rather than the widget's creation time.
    final delay =
        const Duration(minutes: 1) -
        Duration(
          seconds: now.second,
          milliseconds: now.millisecond,
          microseconds: now.microsecond,
        );
    _timer = Timer(delay, _refresh);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _now = campusNow());
    _scheduleTick();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = calendarDate(_now).difference(calendarDate(widget.monday)).inDays;
    final offset = sectionOffsetAt(_now);
    if (day < 0 ||
        day >= 7 ||
        widget.columnWidth <= _horizontalInset * 2 ||
        widget.rowHeight * sectionTimes.length < _lineHeight) {
      return const SizedBox.shrink();
    }

    final gridHeight = widget.rowHeight * sectionTimes.length;
    final top = (offset * widget.rowHeight - _lineHeight / 2)
        .clamp(0.0, gridHeight - _lineHeight)
        .toDouble();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Positioned(
              left: day * widget.columnWidth + _horizontalInset,
              top: top,
              width: widget.columnWidth - _horizontalInset * 2,
              height: _lineHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(_lineHeight / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
