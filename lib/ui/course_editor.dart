import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../schedule/model.dart';
import 'course_period_fields.dart';
import 'course_week_picker.dart';
import 'sheet_layout.dart';

Future<void> editCourse(
  BuildContext context,
  AppController controller, {
  Course? course,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => _CourseEditor(controller: controller, course: course),
);

class _CourseEditor extends StatefulWidget {
  const _CourseEditor({required this.controller, this.course});

  final AppController controller;
  final Course? course;

  @override
  State<_CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends State<_CourseEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.course?.name);
  late final _room = TextEditingController(text: widget.course?.room);
  late final _teacher = TextEditingController(text: widget.course?.teacher);
  late final _term = TextEditingController(text: _initialTerm());
  late int _day = widget.course?.weekday ?? campusNow().weekday;
  late int _start = widget.course?.startSection ?? 1;
  late int _end = widget.course?.endSection ?? 2;
  late DateTime _monday =
      widget.controller.schedule?.firstMonday ?? mondayOf(campusNow());
  late Set<int> _weeks =
      widget.course?.weeks.toSet() ??
      (widget.controller.schedule?.weeks ?? academicWeeks(1, 20)).toSet();
  late int _firstWeek = widget.controller.schedule?.firstWeek ?? 1;
  bool _saving = false;
  String? _error;

  String _initialTerm() {
    final now = campusNow();
    final year = now.month >= 8 ? now.year : now.year - 1;
    return widget.controller.schedule?.term ??
        '$year-${year + 1}-${now.month >= 8 ? 1 : 2}';
  }

  @override
  void dispose() {
    _name.dispose();
    _room.dispose();
    _teacher.dispose();
    _term.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_weeks.isEmpty) {
      setState(() => _error = '至少选择一个上课周次');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final course = Course(
      id:
          widget.course?.stableId ??
          'local-${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      teacher: _teacher.text.trim(),
      room: _room.text.trim(),
      campus: widget.course?.campus ?? '',
      number: widget.course?.number ?? '',
      description: widget.course?.description ?? '',
      weekday: _day,
      startSection: _start,
      endSection: _end,
      weeks: _weeks.toList(),
      local: true,
    );
    final success = await widget.controller.saveCourse(
      course,
      replacing: widget.course,
      semester: widget.controller.schedule == null
          ? SemesterSchedule(
              term: _term.text.trim(),
              firstMonday: _monday,
              courses: [],
            )
          : null,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = widget.controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final weeks = academicWeeks(
      _firstWeek,
      widget.controller.schedule?.lastWeek ?? 20,
    );
    final menuHeight = math.min(320.0, MediaQuery.sizeOf(context).height * 0.4);
    final theme = Theme.of(context);
    final inputTheme = theme.inputDecorationTheme.copyWith(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
    return PopScope(
      canPop: !_saving,
      child: Theme(
        data: theme.copyWith(inputDecorationTheme: inputTheme),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SheetLayout(
            header: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.course == null ? '添加课程' : '编辑课程',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            content: Padding(
              // Keep floating labels inside the scroll viewport.
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.controller.schedule == null) ...[
                      TextFormField(
                        controller: _term,
                        enabled: !_saving,
                        decoration: const InputDecoration(labelText: '学期'),
                        validator: (value) =>
                            value!.trim().isEmpty ? '请输入学期' : null,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: _saving
                            ? null
                            : () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _monday,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  selectableDayPredicate: (date) =>
                                      date.weekday == DateTime.monday,
                                  helpText: '选择第一周周一',
                                );
                                if (date != null) {
                                  setState(() => _monday = calendarDate(date));
                                }
                              },
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                        label: Text('第一周周一：${dateText(_monday)}'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: '课程名称'),
                      validator: (value) =>
                          value!.trim().isEmpty ? '请输入课程名称' : null,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final room = TextFormField(
                          controller: _room,
                          enabled: !_saving,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '教室（选填）',
                          ),
                        );
                        final teacher = TextFormField(
                          controller: _teacher,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: '教师（选填）',
                          ),
                        );
                        final scale = MediaQuery.textScalerOf(context).scale(1);
                        if (constraints.maxWidth < 300 * scale) {
                          return Column(
                            children: [
                              room,
                              const SizedBox(height: 12),
                              teacher,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: room),
                            const SizedBox(width: 12),
                            Expanded(child: teacher),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownMenu<int>(
                      initialSelection: _day,
                      label: const Text('星期'),
                      expandedInsets: EdgeInsets.zero,
                      menuHeight: menuHeight,
                      inputDecorationTheme: inputTheme,
                      selectOnly: true,
                      enableSearch: false,
                      enabled: !_saving,
                      dropdownMenuEntries: [
                        for (var i = 1; i <= 7; i++)
                          DropdownMenuEntry(value: i, label: weekdays[i - 1]),
                      ],
                      onSelected: (value) {
                        if (value != null) setState(() => _day = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    CoursePeriodFields(
                      startSection: _start,
                      endSection: _end,
                      enabled: !_saving,
                      onChanged: (start, end) {
                        setState(() {
                          _start = start;
                          _end = end;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    CourseWeekPicker(
                      weeks: weeks,
                      selectedWeeks: _weeks,
                      enabled: !_saving,
                      onChanged: (weeks) => setState(() => _weeks = weeks),
                      onAddEarlierWeek: () => setState(() {
                        _firstWeek = weekFromOffset(weekOffset(_firstWeek) - 1);
                      }),
                    ),
                  ],
                ),
              ),
            ),
            actions: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? '保存中…' : '保存课程'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
