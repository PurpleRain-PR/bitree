import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../schedule/controller.dart';
import '../schedule/model.dart';

Future<void> editCourse(
  BuildContext context,
  ScheduleController controller, {
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
  final ScheduleController controller;
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
      {
        for (var i = 1; i <= (widget.controller.schedule?.weekCount ?? 20); i++)
          i,
      };
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
      id: widget.course?.id ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      teacher: _teacher.text.trim(),
      room: _room.text.trim(),
      weekday: _day,
      startSection: _start,
      endSection: _end,
      weeks: _weeks.toList(),
      local: true,
    );
    final success = await widget.controller.saveCourse(
      course,
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

  String _sectionLabel(int section) {
    final (start, end) = sectionTimes[section - 1];
    return '第 $section 节（$start–$end）';
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.controller.schedule?.weekCount ?? 20;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  widget.course == null ? '添加课程' : '编辑课程',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.controller.schedule == null) ...[
                          TextFormField(
                            controller: _term,
                            decoration: const InputDecoration(labelText: '学期'),
                            validator: (value) =>
                                value!.trim().isEmpty ? '请输入学期' : null,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
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
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: '课程名称'),
                          validator: (value) =>
                              value!.trim().isEmpty ? '请输入课程名称' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _room,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: '教室（选填）',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _teacher,
                                decoration: const InputDecoration(
                                  labelText: '教师（选填）',
                                ),
                              ),
                            ),
                          ],
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
                              DropdownMenuEntry(
                                value: i,
                                label: weekdays[i - 1],
                              ),
                          ],
                          onSelected: (value) {
                            if (value != null) setState(() => _day = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final start = DropdownMenu<int>(
                              initialSelection: _start,
                              label: const Text('开始节次'),
                              expandedInsets: EdgeInsets.zero,
                              menuHeight: menuHeight,
                              inputDecorationTheme: inputTheme,
                              selectOnly: true,
                              enableSearch: false,
                              maxLines: null,
                              enabled: !_saving,
                              dropdownMenuEntries: [
                                for (var i = 1; i <= sectionTimes.length; i++)
                                  DropdownMenuEntry(
                                    value: i,
                                    label: _sectionLabel(i),
                                    labelWidget: Text(_sectionLabel(i)),
                                  ),
                              ],
                              onSelected: (value) {
                                if (value == null) return;
                                setState(() {
                                  _start = value;
                                  if (_end < _start) _end = _start;
                                });
                              },
                            );
                            final end = DropdownMenu<int>(
                              initialSelection: _end,
                              label: const Text('结束节次'),
                              expandedInsets: EdgeInsets.zero,
                              menuHeight: menuHeight,
                              inputDecorationTheme: inputTheme,
                              selectOnly: true,
                              enableSearch: false,
                              maxLines: null,
                              enabled: !_saving,
                              dropdownMenuEntries: [
                                for (
                                  var i = _start;
                                  i <= sectionTimes.length;
                                  i++
                                )
                                  DropdownMenuEntry(
                                    value: i,
                                    label: _sectionLabel(i),
                                    labelWidget: Text(_sectionLabel(i)),
                                  ),
                              ],
                              onSelected: (value) {
                                if (value != null) setState(() => _end = value);
                              },
                            );
                            final scale = MediaQuery.textScalerOf(
                              context,
                            ).scale(1);
                            if (constraints.maxWidth < 500 * scale) {
                              return Column(
                                children: [
                                  start,
                                  const SizedBox(height: 12),
                                  end,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: start),
                                const SizedBox(width: 12),
                                Expanded(child: end),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            const Text(
                              '上课周次',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextButton(
                              onPressed: () => setState(
                                () => _weeks = {
                                  for (var i = 1; i <= count; i++) i,
                                },
                              ),
                              child: const Text('全选'),
                            ),
                            TextButton(
                              onPressed: () => setState(
                                () => _weeks = {
                                  for (var i = 1; i <= count; i += 2) i,
                                },
                              ),
                              child: const Text('单周'),
                            ),
                            TextButton(
                              onPressed: () => setState(
                                () => _weeks = {
                                  for (var i = 2; i <= count; i += 2) i,
                                },
                              ),
                              child: const Text('双周'),
                            ),
                          ],
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final fontSize = MediaQuery.textScalerOf(
                              context,
                            ).scale(14);
                            final minimumWidth = math.max(
                              48.0,
                              fontSize * 2 + 16,
                            );
                            final columns =
                                ((constraints.maxWidth + 4) /
                                        (minimumWidth + 4))
                                    .floor()
                                    .clamp(1, 7);
                            return GridView.builder(
                              shrinkWrap: true,
                              primary: false,
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 4,
                                    mainAxisSpacing: 4,
                                    mainAxisExtent: math.max(
                                      48,
                                      fontSize * 1.4 + 16,
                                    ),
                                  ),
                              itemCount: count,
                              itemBuilder: (context, index) {
                                final week = index + 1;
                                final selected = _weeks.contains(week);
                                return Semantics(
                                  selected: selected,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      backgroundColor: selected
                                          ? theme.colorScheme.secondaryContainer
                                          : Colors.transparent,
                                      foregroundColor: selected
                                          ? theme
                                                .colorScheme
                                                .onSecondaryContainer
                                          : theme.colorScheme.onSurfaceVariant,
                                      side: BorderSide(
                                        color: selected
                                            ? Colors.transparent
                                            : theme.colorScheme.outlineVariant,
                                      ),
                                    ),
                                    onPressed: _saving
                                        ? null
                                        : () => setState(() {
                                            if (selected) {
                                              _weeks.remove(week);
                                            } else {
                                              _weeks.add(week);
                                            }
                                          }),
                                    child: Text(
                                      '$week',
                                      semanticsLabel: '第 $week 周',
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
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
            ],
          ),
        ),
      ),
    );
  }
}
