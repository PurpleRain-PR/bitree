import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../schedule/model.dart';

class CoursePeriodFields extends StatelessWidget {
  const CoursePeriodFields({
    super.key,
    required this.startSection,
    required this.endSection,
    required this.enabled,
    required this.onChanged,
  });

  final int startSection;
  final int endSection;
  final bool enabled;
  final void Function(int start, int end) onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final compact = constraints.maxWidth >= 360 * scale;
      final start = _SectionMenu(
        label: '开始节次',
        value: startSection,
        enabled: enabled,
        compact: compact,
        onChanged: (value) => onChanged(value, math.max(value, endSection)),
      );
      final end = _SectionMenu(
        label: '结束节次',
        value: endSection,
        firstSection: startSection,
        enabled: enabled,
        compact: compact,
        onChanged: (value) => onChanged(startSection, value),
      );

      if (!compact) {
        return Column(children: [start, const SizedBox(height: 12), end]);
      }
      return Row(
        children: [
          Expanded(child: start),
          const SizedBox(width: 12),
          Expanded(child: end),
        ],
      );
    },
  );
}

class _SectionMenu extends StatelessWidget {
  const _SectionMenu({
    required this.label,
    required this.value,
    required this.enabled,
    required this.compact,
    required this.onChanged,
    this.firstSection = 1,
  });

  final String label;
  final int value;
  final int firstSection;
  final bool enabled;
  final bool compact;
  final ValueChanged<int> onChanged;

  String _sectionLabel(int section, {bool multiline = false}) {
    final (start, end) = sectionTimes[section - 1];
    return '第 $section 节${multiline ? '\n' : ' '}（$start–$end）';
  }

  @override
  Widget build(BuildContext context) => DropdownMenu<int>(
    initialSelection: value,
    label: Text(label),
    expandedInsets: EdgeInsets.zero,
    menuHeight: math.min(320.0, MediaQuery.sizeOf(context).height * 0.4),
    inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
      suffixIconConstraints: const BoxConstraints.tightFor(
        width: 36,
        height: 44,
      ),
    ),
    trailingIcon: const Icon(Icons.expand_more_rounded, size: 18),
    selectedTrailingIcon: const Icon(Icons.expand_less_rounded, size: 18),
    textStyle: compact
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)
        : Theme.of(context).textTheme.bodyLarge,
    selectOnly: true,
    enableSearch: false,
    maxLines: compact ? 2 : null,
    enabled: enabled,
    dropdownMenuEntries: [
      for (
        var section = firstSection;
        section <= sectionTimes.length;
        section++
      )
        DropdownMenuEntry(
          value: section,
          label: _sectionLabel(section, multiline: compact),
          labelWidget: Text(_sectionLabel(section)),
        ),
    ],
    onSelected: (value) {
      if (value != null) onChanged(value);
    },
  );
}
