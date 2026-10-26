import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../classrooms/model.dart';
import '../schedule/model.dart';
import 'app_dropdown_field.dart';
import 'app_notice.dart';
import 'course_period_fields.dart';
import 'school_screen.dart';
import 'school_verification_dialog.dart';

class ClassroomScreen extends StatefulWidget {
  const ClassroomScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  ClassroomDirectory? _directory;
  String? _campusCode;
  String? _buildingCode;
  DateTime _date = calendarDate(campusNow());
  late int _start = _nextSection();
  late int _end = _start;
  List<ClassroomOccupancy>? _rooms;
  bool _working = false;
  bool _requesting = false;

  List<SchoolBuilding> get _buildings => [
    for (final building in _directory?.buildings ?? <SchoolBuilding>[])
      if (building.campusCode == _campusCode) building,
  ];

  int _nextSection() {
    final now = campusNow();
    final minutes = now.hour * 60 + now.minute;
    final index = sectionTimes.indexWhere((time) {
      final parts = time.$2.split(':').map(int.parse).toList();
      return parts[0] * 60 + parts[1] > minutes;
    });
    return index < 0 ? sectionTimes.length : index + 1;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadDirectory());
    });
  }

  @override
  void dispose() {
    if (_requesting) widget.controller.cancelSchoolRequest();
    super.dispose();
  }

  Future<T?> _withLogin<T>(Future<T?> Function() read) async {
    final controller = widget.controller;
    if (controller.busy || controller.schoolBusy) {
      showAppNotice(context, '学校请求正在进行，请稍后重试。');
      return null;
    }

    Future<bool> signIn() async =>
        await openSchoolPage(
          context,
          controller,
          action: SchoolAction.signIn,
        ) ==
        true;

    if (controller.username == null) {
      if (!await signIn() || !mounted) return null;
    }

    Future<T?> request() async {
      _requesting = true;
      try {
        return await read();
      } finally {
        _requesting = false;
      }
    }

    var result = await request();
    if (!mounted) return null;
    if (result == null && controller.loginExpired) {
      if (!await signIn() || !mounted) return null;
      result = await request();
    }
    return result;
  }

  Future<void> _loadDirectory() async {
    if (_working) return;
    setState(() {
      _working = true;
    });
    final result = await _withLogin(
      () => widget.controller.classroomDirectory(
        verify: (request) => verifySchoolLogin(context, request),
      ),
    );
    if (!mounted) return;
    setState(() {
      _working = false;
      if (result == null) return;
      _directory = result;
      _campusCode = result.campuses.firstOrNull?.code;
      _buildingCode = _buildings.firstOrNull?.code;
    });
  }

  Future<void> _query() async {
    if (_working || _buildingCode == null) return;
    setState(() {
      _working = true;
      _rooms = null;
    });
    final result = await _withLogin(
      () => widget.controller.classroomOccupancy(
        buildingCode: _buildingCode!,
        date: _date,
        verify: (request) => verifySchoolLogin(context, request),
      ),
    );
    if (!mounted) return;
    setState(() {
      _working = false;
      _rooms = result;
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 1, 12, 31),
    );
    if (date == null || !mounted) return;
    setState(() {
      _date = calendarDate(date);
      _rooms = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('空教室查询')),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _buildQuery(),
                ),
              ),
              ..._buildResults(),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildQuery() {
    final directory = _directory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (directory == null) ...[
          if (_working)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            OutlinedButton.icon(
              onPressed: _loadDirectory,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('加载教学楼'),
            ),
        ] else if (directory.campuses.isEmpty) ...[
          const Text('学校暂未提供校区和教学楼信息。'),
          TextButton(onPressed: _loadDirectory, child: const Text('重新加载')),
        ] else ...[
          _ResponsiveFields(
            first: AppDropdownField<String>(
              label: '校区',
              value: _campusCode!,
              entries: [
                for (final campus in directory.campuses)
                  DropdownMenuEntry(value: campus.code, label: campus.name),
              ],
              onChanged: _working
                  ? null
                  : (value) => setState(() {
                      _campusCode = value;
                      _buildingCode = _buildings.firstOrNull?.code;
                      _rooms = null;
                    }),
            ),
            second: _buildingCode == null
                ? const InputDecorator(
                    decoration: InputDecoration(labelText: '教学楼'),
                    child: Text('该校区暂无教学楼'),
                  )
                : AppDropdownField<String>(
                    label: '教学楼',
                    value: _buildingCode!,
                    maxLines: 2,
                    entries: [
                      for (final building in _buildings)
                        DropdownMenuEntry(
                          value: building.code,
                          label: building.name,
                        ),
                    ],
                    onChanged: _working
                        ? null
                        : (value) => setState(() {
                            _buildingCode = value;
                            _rooms = null;
                          }),
                  ),
          ),
          const SizedBox(height: 16),
          _ResponsiveFields(
            first: OutlinedButton.icon(
              onPressed: _working ? null : _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 20),
              label: Text('${dateText(_date)} ${weekdays[_date.weekday - 1]}'),
            ),
            second: CoursePeriodFields(
              startSection: _start,
              endSection: _end,
              enabled: !_working,
              onChanged: (start, end) => setState(() {
                _start = start;
                _end = end;
              }),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _working || _buildingCode == null ? null : _query,
              icon: _working
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(_working ? '查询中…' : '查询'),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildResults() {
    final rooms = _rooms;
    if (rooms == null) return const [];
    final free = [
      for (final room in rooms)
        if (room.freePeriod(_start, _end) case final period?)
          (room: room, period: period),
    ];
    final theme = Theme.of(context);

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${free.length} 间空闲教室', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '按教学安排查询，现场使用情况以实际为准。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (free.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    rooms.isEmpty ? '该教学楼没有返回教室。' : '这段时间没有空教室，换个节次试试。',
                  ),
                ),
            ],
          ),
        ),
      ),
      SliverList.builder(
        itemCount: free.length,
        itemBuilder: (context, index) {
          final (:room, :period) = free[index];
          final start = sectionTimes[period.start - 1].$1;
          final end = sectionTimes[period.end - 1].$2;
          return ListTile(
            title: Text(room.name),
            subtitle: Text('第 ${period.start}–${period.end} 节空闲（$start–$end）'),
          );
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth <
          600 * MediaQuery.textScalerOf(context).scale(1)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 16), second],
        );
      }
      return Row(
        children: [
          Expanded(child: first),
          const SizedBox(width: 16),
          Expanded(child: second),
        ],
      );
    },
  );
}
