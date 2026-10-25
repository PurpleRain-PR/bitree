import 'package:flutter/material.dart';

import '../data/school_network.dart';

Future<SchoolNetwork?> pickSchoolNetwork(
  BuildContext context, {
  required String title,
  SchoolNetwork? current,
}) => showModalBottomSheet<SchoolNetwork>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 520),
  builder: (context) {
    void select(SchoolNetwork network) {
      if (ModalRoute.of(context)!.isCurrent) Navigator.pop(context, network);
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('校园网'),
              subtitle: const Text('需连接校园网'),
              trailing: current == SchoolNetwork.campus
                  ? const Text('当前')
                  : const Icon(Icons.chevron_right_rounded),
              onTap: current == SchoolNetwork.campus
                  ? null
                  : () => select(SchoolNetwork.campus),
            ),
            ListTile(
              leading: const Icon(Icons.public_rounded),
              title: const Text('WebVPN'),
              subtitle: const Text('校外访问'),
              trailing: current == SchoolNetwork.webvpn
                  ? const Text('当前')
                  : const Icon(Icons.chevron_right_rounded),
              onTap: current == SchoolNetwork.webvpn
                  ? null
                  : () => select(SchoolNetwork.webvpn),
            ),
          ],
        ),
      ),
    );
  },
);
