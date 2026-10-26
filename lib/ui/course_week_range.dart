import 'package:flutter/material.dart';

Future<({int first, int last})?> manageCourseWeeks(
  BuildContext context, {
  required int first,
  required int last,
}) => showDialog<({int first, int last})>(
  context: context,
  builder: (_) => _CourseWeekRange(first: first, last: last),
);

class _CourseWeekRange extends StatefulWidget {
  const _CourseWeekRange({required this.first, required this.last});

  final int first;
  final int last;

  @override
  State<_CourseWeekRange> createState() => _CourseWeekRangeState();
}

class _CourseWeekRangeState extends State<_CourseWeekRange> {
  final _form = GlobalKey<FormState>();
  late final _first = TextEditingController(text: '${widget.first}');
  late final _last = TextEditingController(text: '${widget.last}');

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  String? _validateWeek(String? value) {
    final week = int.tryParse(value!.trim());
    if (week == null) return '请输入整数周次';
    if (week == 0) return '没有第 0 周';
    return null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, (
      first: int.parse(_first.text.trim()),
      last: int.parse(_last.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('周数管理'),
    constraints: const BoxConstraints(maxWidth: 400),
    scrollable: true,
    content: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Form(
        key: _form,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _first,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '开始周',
                  errorMaxLines: 3,
                ),
                validator: _validateWeek,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Text('—'),
            ),
            Expanded(
              child: TextFormField(
                controller: _last,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '截止周',
                  errorMaxLines: 3,
                ),
                validator: (value) {
                  final error = _validateWeek(value);
                  if (error != null) return error;
                  final first = int.tryParse(_first.text.trim());
                  final last = int.parse(value!.trim());
                  return first != null && last < first ? '截止周不能早于开始周' : null;
                },
                onFieldSubmitted: (_) => _save(),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _save, child: const Text('确定')),
    ],
  );
}
