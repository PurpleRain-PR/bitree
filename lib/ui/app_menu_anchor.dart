import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppMenuAnchor extends StatelessWidget {
  const AppMenuAnchor({
    super.key,
    required this.menuChildren,
    this.controller,
    this.childFocusNode,
    this.menuWidth,
    this.style,
    this.onOpen,
    this.onClose,
    this.builder,
    this.child,
  });

  final List<Widget> menuChildren;
  final MenuController? controller;
  final FocusNode? childFocusNode;
  final double? menuWidth;
  final MenuStyle? style;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final MenuAnchorChildBuilder? builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final menuStyle = MenuStyle(
      minimumSize: menuWidth == null
          ? null
          : WidgetStatePropertyAll(Size(menuWidth!, 0)),
      maximumSize: WidgetStatePropertyAll(
        Size(
          menuWidth ?? double.infinity,
          math.min(320, MediaQuery.sizeOf(context).height * 0.4),
        ),
      ),
    ).merge(style);
    final padding =
        menuStyle.padding?.resolve({}) ??
        MenuTheme.of(context).style?.padding?.resolve({}) ??
        const EdgeInsets.symmetric(vertical: 8);

    return MenuAnchor(
      controller: controller,
      childFocusNode: childFocusNode,
      crossAxisUnconstrained: menuWidth == null,
      style: menuStyle.copyWith(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      onOpen: onOpen,
      onClose: onClose,
      animated: !MediaQuery.disableAnimationsOf(context),
      // Bound the list itself so MenuAnchor's outer panel has no scroll overflow
      // and does not add a permanent scrollbar.
      menuChildren: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: menuStyle.maximumSize!.resolve({})!.height,
          ),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false),
            child: SingleChildScrollView(
              primary: false,
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: menuChildren,
              ),
            ),
          ),
        ),
      ],
      builder: builder,
      child: child,
    );
  }
}
