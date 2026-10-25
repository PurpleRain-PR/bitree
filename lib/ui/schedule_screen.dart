import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../schedule/controller.dart';
import '../schedule/ics.dart';
import '../schedule/model.dart';
import 'course_detail.dart';
import 'course_editor.dart';
import 'login_screen.dart';
import 'timetable.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key, required this.controller});
  final ScheduleController controller;

  Future<bool?> _import(BuildContext context) =>
      openSchoolPage(context, controller, action: SchoolAction.importSchedule);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final inset = compact ? 16.0 : 28.0;
                final schedule = controller.schedule;
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(inset, 4, inset - 6, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _WeekSelector(controller: controller),
                            ),
                          ),
                          if (!compact && schedule != null) ...[
                            IconButton(
                              tooltip: '上一周',
                              onPressed: controller.week > 1
                                  ? () => controller.selectWeek(
                                      controller.week - 1,
                                    )
                                  : null,
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            IconButton(
                              tooltip: '下一周',
                              onPressed: controller.week < schedule.weekCount
                                  ? () => controller.selectWeek(
                                      controller.week + 1,
                                    )
                                  : null,
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                            const SizedBox(width: 12),
                          ],
                          IconButton(
                            tooltip: '添加课程',
                            onPressed: controller.busy
                                ? null
                                : () => editCourse(context, controller),
                            icon: const Icon(Icons.add_rounded),
                          ),
                          IconButton(
                            tooltip: '导入课表',
                            onPressed: controller.busy
                                ? null
                                : () => _import(context),
                            icon: const Icon(Icons.input_rounded),
                          ),
                          _ScheduleMenu(
                            schedule: schedule,
                            enabled: !controller.busy,
                          ),
                        ],
                      ),
                    ),
                    if (controller.error != null)
                      Container(
                        color: scheme.errorContainer,
                        padding: EdgeInsets.fromLTRB(inset, 4, inset, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                controller.error!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                            ),
                            if (controller.needsLogin)
                              TextButton(
                                onPressed: controller.busy
                                    ? null
                                    : () => _import(context),
                                child: const Text('继续导入'),
                              ),
                            IconButton(
                              tooltip: '关闭提示',
                              onPressed: controller.dismissError,
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                          ],
                        ),
                      ),
                    if (!controller.ready)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (schedule == null)
                      Expanded(
                        child: _EmptySchedule(
                          onImport: () => _import(context),
                          onAdd: () => editCourse(context, controller),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 6 : inset,
                          ),
                          child: _WeekPager(
                            key: ValueKey((
                              schedule.term,
                              schedule.firstMonday,
                            )),
                            controller: controller,
                          ),
                        ),
                      ),
                      if (schedule.courses.any((course) => !course.isScheduled))
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: inset),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _unscheduled(context),
                              child: const Text('时间待定'),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unscheduled(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('时间待定'),
      children: [
        for (final course in controller.schedule!.courses.where(
          (course) => !course.isScheduled,
        ))
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              showCourse(context, controller, course);
            },
            child: Text(course.name),
          ),
      ],
    ),
  );
}

class _ScheduleMenu extends StatefulWidget {
  const _ScheduleMenu({required this.schedule, required this.enabled});
  final SemesterSchedule? schedule;
  final bool enabled;

  @override
  State<_ScheduleMenu> createState() => _ScheduleMenuState();
}

class _ScheduleMenuState extends State<_ScheduleMenu> {
  bool _exporting = false;

  Future<void> _export(SemesterSchedule schedule) async {
    if (_exporting) return;
    final skipped = schedule.courses
        .where((course) => !course.isScheduled)
        .length;
    final messenger = ScaffoldMessenger.of(context);
    if (skipped == schedule.courses.length) {
      messenger.showSnackBar(
        const SnackBar(content: Text('没有可导出的课程，请先添加课程或设置上课时间。')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final term = schedule.term.replaceAll(
        RegExp(r'[<>:"/\\|?*\x00-\x1f]'),
        '_',
      );
      final saved = await FilePicker.saveFile(
        fileName: 'BITree-$term.ics',
        bytes: Uint8List.fromList(utf8.encode(scheduleToIcs(schedule))),
        mimeType: 'text/calendar',
        dialogTitle: '导出课表',
      );
      if (!mounted || saved == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(skipped == 0 ? '已导出课表' : '已导出课表，跳过 $skipped 门时间待定的课程'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is PlatformException
          ? error.message ?? error.code
          : error.toString();
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$message')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: schedule == null || !widget.enabled || _exporting
              ? null
              : () => _export(schedule),
          leadingIcon: const Icon(Icons.file_download_outlined),
          child: const Text('导出 ICS'),
        ),
      ],
      builder: (context, menu, child) => IconButton(
        tooltip: '更多',
        onPressed: _exporting
            ? null
            : () => menu.isOpen ? menu.close() : menu.open(),
        icon: const Icon(Icons.more_horiz_rounded),
      ),
    );
  }
}

class _WeekPager extends StatefulWidget {
  const _WeekPager({super.key, required this.controller});
  final ScheduleController controller;

  @override
  State<_WeekPager> createState() => _WeekPagerState();
}

class _WeekPagerState extends State<_WeekPager> {
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
  void didUpdateWidget(covariant _WeekPager oldWidget) {
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

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({required this.controller});
  final ScheduleController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final schedule = controller.schedule;
    final screen = MediaQuery.sizeOf(context);
    final cellSize = math.max(
      48.0,
      MediaQuery.textScalerOf(context).scale(14) * 2 + 16,
    );
    final columns = ((screen.width - 32) / (cellSize + 4)).floor().clamp(1, 5);
    final weekCount = schedule?.weekCount ?? 0;
    final currentWeek = schedule?.weekAt(campusNow());
    return MenuAnchor(
      style: MenuStyle(
        maximumSize: WidgetStatePropertyAll(
          Size(double.infinity, math.min(320, screen.height * 0.4)),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      menuChildren: [
        for (var row = 1; row <= weekCount; row += columns)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (
                var week = row;
                week < row + columns && week <= weekCount;
                week++
              )
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: SizedBox.square(
                    dimension: cellSize,
                    child: Semantics(
                      selected: controller.week == week,
                      child: MenuItemButton(
                        onPressed: () => controller.selectWeek(week),
                        style: MenuItemButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: controller.week == week
                              ? scheme.primary
                              : Colors.transparent,
                          foregroundColor: controller.week == week
                              ? scheme.onPrimary
                              : week == currentWeek
                              ? scheme.primary
                              : scheme.onSurface,
                          side: week == currentWeek
                              ? BorderSide(color: scheme.primary)
                              : BorderSide.none,
                          textStyle: TextStyle(
                            fontWeight:
                                controller.week == week || week == currentWeek
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$week',
                            semanticsLabel:
                                '第 $week 周${week == currentWeek ? '，本周' : ''}',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
      builder: (context, menu, _) => TextButton(
        onPressed: schedule == null
            ? null
            : () => menu.isOpen ? menu.close() : menu.open(),
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          disabledForegroundColor: scheme.onSurface,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                schedule == null ? '课表' : '第${controller.week}周',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (schedule != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({required this.onImport, required this.onAdd});
  final VoidCallback onImport;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 40,
                color: scheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                '还没有课表',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onImport,
                  child: const Text('导入课表'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加课程'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
