import 'package:flutter/material.dart';

/// Shared frame for the four main destinations.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final Widget title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = constraints.maxWidth < 680 ? 16.0 : 24.0;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        children: [
                          Expanded(
                            child: DefaultTextStyle(
                              style: Theme.of(context)
                                  .appBarTheme
                                  .titleTextStyle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              child: title,
                            ),
                          ),
                          ...actions,
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
