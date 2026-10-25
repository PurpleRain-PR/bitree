import 'package:flutter/material.dart';

class SheetLayout extends StatelessWidget {
  const SheetLayout({
    super.key,
    required this.content,
    this.header,
    this.actions,
  });

  final Widget content;
  final Widget? header;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ?header,
      Flexible(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: content,
        ),
      ),
      ?actions,
    ],
  );
}
