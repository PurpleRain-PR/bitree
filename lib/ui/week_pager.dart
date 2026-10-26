import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'timetable.dart';

class WeekPager extends StatefulWidget {
  const WeekPager({
    super.key,
    required this.controller,
    this.active = true,
  });

  final AppController controller;
  final bool active;

  @override
  State<WeekPager> createState() => _WeekPagerState();
}

class _WeekPagerState extends State<WeekPager> {
  late final PageController _pages;
  late int _week;
  double _scrollOffset = 0;
  int _entry = 0;
  int? _revealWeek;

  void _requestTimeReveal() {
    _entry++;
    _revealWeek = widget.controller.week;
  }

  @override
  void initState() {
    super.initState();
    _week = widget.controller.week;
    if (widget.active) _requestTimeReveal();
    _pages = PageController(
      initialPage: widget.controller.weeks.indexOf(_week),
      keepPage: false,
    );
  }

  @override
  void didUpdateWidget(covariant WeekPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) {
      _revealWeek = null;
    } else if (!oldWidget.active) {
      _requestTimeReveal();
    }
    final week = widget.controller.week;
    if (_week == week) return;
    // Changing weeks must not carry an unconsumed entry request with it.
    _revealWeek = null;
    _week = week;
    final page = widget.controller.weeks.indexOf(week);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _pages.jumpToPage(page);
      } else {
        _pages.animateToPage(
          page,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    final weeks = widget.controller.weeks;
    return ScrollConfiguration(
      behavior: behavior.copyWith(
        dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
      ),
      child: PageView.builder(
        controller: _pages,
        itemCount: weeks.length,
        onPageChanged: (page) {
          if (_week != weeks[page]) _revealWeek = null;
          _week = weeks[page];
          if (widget.controller.week != _week) {
            widget.controller.selectWeek(_week);
          }
        },
        itemBuilder: (context, page) => Timetable(
          controller: widget.controller,
          week: weeks[page],
          initialScrollOffset: _scrollOffset,
          onScroll: (offset) => _scrollOffset = offset,
          timeRevealRequest: widget.active && _revealWeek == weeks[page]
              ? _entry
              : null,
          onTimeRevealHandled: () => _revealWeek = null,
        ),
      ),
    );
  }
}
