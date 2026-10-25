import 'dart:math' as math;

import 'package:flutter/material.dart';

class CourseWeekPicker extends StatelessWidget {
  const CourseWeekPicker({
    super.key,
    required this.weekCount,
    required this.selectedWeeks,
    required this.enabled,
    required this.onChanged,
  });

  final int weekCount;
  final Set<int> selectedWeeks;
  final bool enabled;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            const Text('上课周次', style: TextStyle(fontWeight: FontWeight.w600)),
            TextButton(
              onPressed: enabled
                  ? () => onChanged({for (var i = 1; i <= weekCount; i++) i})
                  : null,
              child: const Text('全选'),
            ),
            TextButton(
              onPressed: enabled
                  ? () => onChanged({for (var i = 1; i <= weekCount; i += 2) i})
                  : null,
              child: const Text('单周'),
            ),
            TextButton(
              onPressed: enabled
                  ? () => onChanged({for (var i = 2; i <= weekCount; i += 2) i})
                  : null,
              child: const Text('双周'),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final fontSize = MediaQuery.textScalerOf(context).scale(14);
            final minimumWidth = math.max(48.0, fontSize * 2 + 16);
            final columns = ((constraints.maxWidth + 4) / (minimumWidth + 4))
                .floor()
                .clamp(1, 7);
            return GridView.builder(
              shrinkWrap: true,
              primary: false,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                mainAxisExtent: math.max(48, fontSize * 1.4 + 16),
              ),
              itemCount: weekCount,
              itemBuilder: (context, index) {
                final week = index + 1;
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
            );
          },
        ),
      ],
    );
  }
}
