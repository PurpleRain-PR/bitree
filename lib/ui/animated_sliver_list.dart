import 'package:flutter/material.dart';

/// Reconciles keyed rows while Flutter animates their insertion and removal.
class AnimatedSliverChildren extends StatefulWidget {
  const AnimatedSliverChildren({super.key, required this.children});

  final List<Widget> children;

  @override
  State<AnimatedSliverChildren> createState() => _AnimatedSliverChildrenState();
}

class _AnimatedSliverChildrenState extends State<AnimatedSliverChildren> {
  final _list = GlobalKey<SliverAnimatedListState>();
  late final _children = widget.children.toList();

  Duration get _duration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 220);

  void _remove(int index) {
    // A restored or moved row can coexist with its outgoing animation.
    final child = KeyedSubtree(
      key: UniqueKey(),
      child: _children.removeAt(index),
    );
    _list.currentState!.removeItem(
      index,
      (context, animation) => _transition(child, animation, removing: true),
      duration: _duration,
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedSliverChildren oldWidget) {
    super.didUpdateWidget(oldWidget);
    final keys = widget.children.map((child) => child.key).toSet();
    assert(!keys.contains(null) && keys.length == widget.children.length);
    for (var index = _children.length - 1; index >= 0; index--) {
      if (!keys.contains(_children[index].key)) _remove(index);
    }

    for (var index = 0; index < widget.children.length; index++) {
      final child = widget.children[index];
      if (index < _children.length && _children[index].key == child.key) {
        _children[index] = child;
        continue;
      }
      final previous = _children.indexWhere((row) => row.key == child.key);
      if (previous != -1) _remove(previous);
      _children.insert(index, child);
      _list.currentState!.insertItem(index, duration: _duration);
    }
  }

  Widget _transition(
    Widget child,
    Animation<double> animation, {
    bool removing = false,
  }) {
    final progress = animation.drive(CurveTween(curve: Curves.easeInOutCubic));
    return KeyedSubtree(
      key: child.key,
      child: SizeTransition(
        sizeFactor: progress,
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: progress,
          child: removing
              ? ExcludeSemantics(child: IgnorePointer(child: child))
              : child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SliverAnimatedList(
    key: _list,
    initialItemCount: _children.length,
    findChildIndexCallback: (key) {
      final index = _children.indexWhere((child) => child.key == key);
      return index == -1 ? null : index;
    },
    itemBuilder: (context, index, animation) =>
        _transition(_children[index], animation),
  );
}
