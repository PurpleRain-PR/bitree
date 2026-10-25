import 'package:flutter/material.dart';
import '../schedule/controller.dart';
import '../schedule/model.dart';
import 'course_editor.dart';
import 'theme.dart';

Future<void> showCourse(
  BuildContext context,
  ScheduleController controller,
  Course course,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (sheetContext) {
    final theme = Theme.of(sheetContext);
    final colors = courseColors(sheetContext, course.colorIndex);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
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
                      detail(
                        Icons.date_range_outlined,
                        weeksLabel(course.weeks),
                      ),
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
                      if (course.number.isNotEmpty)
                        detail(Icons.tag, course.number),
                      if (course.description.isNotEmpty)
                        detail(Icons.notes_rounded, course.description),
                    ],
                  ),
                ),
              ),
              if (course.local) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: controller.busy
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                editCourse(context, controller, course: course);
                              },
                        child: const Text('编辑课程'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      tooltip: '删除课程',
                      onPressed: controller.busy
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: sheetContext,
                                builder: (context) => AlertDialog(
                                  title: const Text('删除这门课程？'),
                                  content: Text('删除“${course.name}”后无法恢复。'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('取消'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('删除课程'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              final success = await controller.deleteCourse(
                                course,
                              );
                              if (!sheetContext.mounted) return;
                              if (success) {
                                Navigator.pop(sheetContext);
                              } else {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      controller.error ?? '删除失败，请重试。',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  },
);
