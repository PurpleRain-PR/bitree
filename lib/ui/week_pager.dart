import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'timetable.dart';

class WeekPager extends StatefulWidget {
  const WeekPager({super.key, required this.controller});

  final AppController controller;

  @override
  State<WeekPager> createState() => _WeekPagerState();
}

class _WeekPagerState extends State<WeekPager> {
  late final PageController _pages;
  late int _week;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _week = widget.controller.week;
    _pages = PageController(initialPage: _week - 1, keepPage: false);
  }

  @override
  void didUpdateWidget(covariant WeekPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final week = widget.controller.week;
    if (_week == week) return;
    _week = week;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _pages.jumpToPage(week - 1);
      } else {
        _pages.animateToPage(
          week - 1,
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
    return ScrollConfiguration(
      behavior: behavior.copyWith(
        dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
      ),
      child: PageView.builder(
        controller: _pages,
        itemCount: widget.controller.schedule!.weekCount,
        onPageChanged: (page) {
          _week = page + 1;
          if (widget.controller.week != _week) {
            widget.controller.selectWeek(_week);
          }
        },
        itemBuilder: (context, page) => Timetable(
          controller: widget.controller,
          week: page + 1,
          initialScrollOffset: _scrollOffset,
          onScroll: (offset) => _scrollOffset = offset,
        ),
      ),
    );
  }
}
