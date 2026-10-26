import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../data/school_network.dart';
import '../data/school_storage.dart';
import '../data/school_verification.dart';
import 'school_network_picker.dart';
import 'school_verification_dialog.dart';

enum SchoolAction { signIn, importSchedule }

Future<bool?> openSchoolPage(
  BuildContext context,
  AppController controller, {
  required SchoolAction action,
  SchoolNetwork? network,
  String? term,
}) async {
  if (controller.busy || controller.schoolBusy) return null;
  final using = network ?? controller.network;

  if (action == SchoolAction.importSchedule && controller.username != null) {
    final success = await controller.synchronize(
      using: using,
      term: term,
      verify: (request) => verifySchoolLogin(context, request),
    );
    if (success || !controller.loginExpired || !context.mounted) return success;
  }

  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => _SchoolScreen(
        controller: controller,
        action: action,
        network: using,
        term: term,
      ),
    ),
  );
}

class _SchoolScreen extends StatefulWidget {
  const _SchoolScreen({
    required this.controller,
    required this.action,
    required this.network,
    this.term,
  });

  final AppController controller;
  final SchoolAction action;
  final SchoolNetwork network;
  final String? term;

  @override
  State<_SchoolScreen> createState() => _SchoolScreenState();
}

class _SchoolScreenState extends State<_SchoolScreen> {
  final _form = GlobalKey<FormState>();
  late final _username = TextEditingController(
    text: widget.controller.username,
  );
  final _password = TextEditingController();
  late SchoolNetwork _network = widget.network;
  SchoolAction? _operation;
  bool _hidePassword = true;
  String? _error;

  bool get _importing => widget.action == SchoolAction.importSchedule;
  bool get _running => _operation != null;

  Future<void> _run() async {
    if (_running || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _operation = SchoolAction.signIn;
      _error = null;
    });
    final controller = widget.controller;
    Future<String?> verify(SchoolVerification request) =>
        verifySchoolLogin(context, request);
    try {
      final signedIn = await controller.signIn(
        SchoolCredentials(username: _username.text, password: _password.text),
        _network,
        verify,
      );
      if (!mounted) return;
      if (!signedIn) {
        setState(() => _error = controller.error);
        return;
      }
      _password.clear();
      if (_importing) setState(() => _operation = SchoolAction.importSchedule);
      final success =
          !_importing ||
          await controller.synchronize(
            using: _network,
            term: widget.term,
            verify: verify,
          );
      if (!mounted) return;
      _operation = null;
      Navigator.of(context).pop(success);
    } finally {
      if (mounted) setState(() => _operation = null);
    }
  }

  @override
  void dispose() {
    if (_running) widget.controller.cancelSchoolRequest();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_importing ? '导入课表' : '登录学校账号'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: SizedBox(
          height: 3,
          child: _running ? const LinearProgressIndicator(minHeight: 3) : null,
        ),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildForm(),
          ),
        ),
      ),
    ),
  );

  Widget _buildForm() => AutofillGroup(
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SchoolNetworkSelector(
            selected: _network,
            onChanged: _running
                ? null
                : (network) => setState(() => _network = network),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _username,
            enabled: !_running,
            readOnly: widget.controller.username != null,
            decoration: const InputDecoration(labelText: '学号'),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            autocorrect: false,
            enableSuggestions: false,
            validator: (value) =>
                value == null || value.isEmpty ? '请输入学号' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            enabled: !_running,
            autofocus: widget.controller.username != null,
            obscureText: _hidePassword,
            decoration: InputDecoration(
              labelText: '密码',
              suffixIcon: IconButton(
                tooltip: _hidePassword ? '显示密码' : '隐藏密码',
                icon: Icon(
                  _hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: _running
                    ? null
                    : () => setState(() => _hidePassword = !_hidePassword),
              ),
            ),
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            validator: (value) =>
                value == null || value.isEmpty ? '请输入密码' : null,
            onFieldSubmitted: (_) => _run(),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: _running ? null : _run,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_running) ...[
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(switch (_operation) {
                  SchoolAction.signIn => '登录中…',
                  SchoolAction.importSchedule => '导入中…',
                  null => _importing ? '登录并导入' : '登录',
                }),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
