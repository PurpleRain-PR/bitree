import 'package:flutter/material.dart';

import '../data/school_network.dart';

class SchoolNetworkSelector extends StatelessWidget {
  const SchoolNetworkSelector({
    super.key,
    required this.selected,
    this.onChanged,
  });

  final SchoolNetwork selected;
  final ValueChanged<SchoolNetwork>? onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<SchoolNetwork>(
    expandedInsets: EdgeInsets.zero,
    showSelectedIcon: false,
    style: SegmentedButton.styleFrom(
      minimumSize: const Size(48, 44),
      textStyle: const TextStyle(fontSize: 14),
    ),
    segments: const [
      ButtonSegment(
        value: SchoolNetwork.campus,
        icon: Icon(Icons.school_outlined, size: 18),
        label: Text('校园网'),
      ),
      ButtonSegment(
        value: SchoolNetwork.webvpn,
        icon: Icon(Icons.public_rounded, size: 18),
        label: Text('WebVPN'),
      ),
    ],
    selected: {selected},
    onSelectionChanged: onChanged == null
        ? null
        : (value) => onChanged!(value.single),
  );
}
