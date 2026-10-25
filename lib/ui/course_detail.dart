import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../schedule/model.dart';
import 'course_editor.dart';
import 'sheet_layout.dart';
import 'theme.dart';

Future<void> showCourse(
  BuildContext context,
  AppController controller,
  Course course,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (sheetContext) => ListenableBuilder(
    listenable: controller,
    builder: (_, _) => _CourseDetails(
      controller: controller,
      course: course,
      onEdit: () {
        Navigator.pop(sheetContext);
        editCourse(context, controller, course: course);
      },
    ),
  ),
);

class _CourseDetails extends StatelessWidget {
  const _CourseDetails({
    required this.controller,
    required this.course,
    required this.onEdit,
  });

  final AppController controller;
  final Course course;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = courseColors(context, course.colorIndex);
    final location = [
      course.campus,
      course.room,
    ].where((part) => part.isNotEmpty).join(' ');

    Widget detail(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: SelectableText(
              text,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        ],
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SheetLayout(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 25,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        course.name,
                        style: const TextStyle(
                          fontSize: 21,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                detail(Icons.date_range_outlined, weeksLabel(course.weeks)),
                detail(
                  Icons.schedule_outlined,
                  '${course.weekday == null ? '' : '${weekdays[course.weekday! - 1]} '}${course.sectionLabel}\n${course.timeLabel}',
                ),
                detail(
                  Icons.place_outlined,
                  location.isEmpty ? '教室待定' : location,
                ),
                if (course.teacher.isNotEmpty)
                  detail(Icons.person_outline, course.teacher),
                if (course.number.isNotEmpty) detail(Icons.tag, course.number),
                if (course.description.isNotEmpty)
                  detail(Icons.notes_rounded, course.description),
              ],
            ),
            actions: course.local
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: controller.busy ? null : onEdit,
                            child: const Text('编辑课程'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          tooltip: '删除课程',
                          onPressed: controller.busy
                              ? null
                              : () =>
                                    _deleteCourse(context, controller, course),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

Future<void> _deleteCourse(
  BuildContext context,
  AppController controller,
  Course course,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除这门课程？'),
      content: Text('删除“${course.name}”后无法恢复。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('删除课程'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final success = await controller.deleteCourse(course);
  if (!context.mounted) return;

  if (success) {
    Navigator.pop(context);
  } else {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(controller.error ?? '删除失败，请重试。')));
  }
}
