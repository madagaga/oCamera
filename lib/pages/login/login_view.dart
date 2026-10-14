import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rtc/pages/login/login_controller.dart';
import 'package:rtc/theme/app_theme.dart';

/// Broker login screen.
class LoginView extends GetView<LoginController> {
  LoginView({super.key}) {
    brokerController.text = controller.broker.value;
    userController.text = controller.name.value;
    passwordController.text = controller.password.value;
    // values reloaded from storage after construction
    ever(controller.broker, (v) => brokerController.text = v);
    ever(controller.name, (v) => userController.text = v);
    ever(controller.password, (v) => passwordController.text = v);
  }

  final _formKey = GlobalKey<FormState>();
  final brokerController = TextEditingController();
  final userController = TextEditingController();
  final passwordController = TextEditingController();
  final RxBool obscureText = true.obs;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 72),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              color: oc.accentContainer,
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.videocam_outlined,
                              color: oc.onAccentContainer),
                        ),
                        const SizedBox(height: 16),
                        const Text('Sign in to oCamera',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Connect to the broker that relays your cameras.',
                            style: TextStyle(fontSize: 14, color: oc.muted)),
                        const SizedBox(height: 24),
                        _label('Use this phone as', oc),
                        Obx(() => SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                      value: 'viewer',
                                      icon: Icon(Icons.visibility_outlined),
                                      label: Text('Viewer')),
                                  ButtonSegment(
                                      value: 'camera',
                                      icon: Icon(Icons.videocam_outlined),
                                      label: Text('Camera')),
                                ],
                                selected: {controller.role.value},
                                onSelectionChanged: (v) =>
                                    controller.role.value = v.first,
                              ),
                            )),
                        const SizedBox(height: 4),
                        Obx(() => Text(
                              controller.role.value == 'camera'
                                  ? 'Use the camera account, not your viewer account.'
                                  : 'Watch the cameras on your server.',
                              style: TextStyle(fontSize: 12, color: oc.muted),
                            )),
                        const SizedBox(height: 20),
                        _label('Broker URL', oc),
                        TextFormField(
                          controller: brokerController,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 14),
                          decoration: const InputDecoration(
                              helperText:
                                  'Include scheme and port, e.g. tls://host:8883'),
                          validator: (v) {
                            final uri = Uri.tryParse((v ?? '').trim());
                            if (uri == null || uri.host.isEmpty || !uri.hasPort) {
                              return 'Enter a URL with host and port';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _label('Username', oc),
                        TextFormField(
                          controller: userController,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.username],
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Enter your username'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        _label('Password', oc),
                        Obx(() => TextFormField(
                              controller: passwordController,
                              obscureText: obscureText.value,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                suffixIcon: IconButton(
                                  tooltip: obscureText.value
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    obscureText.value
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: oc.muted,
                                  ),
                                  onPressed: () =>
                                      obscureText.value = !obscureText.value,
                                ),
                              ),
                              validator: (v) => (v ?? '').isEmpty
                                  ? 'Enter your password'
                                  : null,
                            )),
                        const SizedBox(height: 20),
                        Obx(() => OutlinedButton.icon(
                              onPressed: controller.testing.value ? null : _test,
                              icon: controller.testing.value
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.link, size: 18),
                              label: const Text('Test connection'),
                            )),
                        _TestResult(controller: controller),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _submit,
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, OcamColors oc) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: oc.muted)),
      );

  void _test() {
    if (_formKey.currentState!.validate()) {
      controller.testConnection(brokerController.text.trim(),
          userController.text.trim(), passwordController.text);
    }
  }

  void _submit() {
    debugPrint('[Login] sign in');
    if (_formKey.currentState!.validate()) {
      controller.saveUserData(userController.text.trim(),
          passwordController.text, brokerController.text.trim(),
          controller.role.value);
    }
  }
}

class _TestResult extends StatelessWidget {
  final LoginController controller;
  const _TestResult({required this.controller});

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  Widget _content(BuildContext context) {
    final oc = context.oc;
    final cs = Theme.of(context).colorScheme;
    final error = controller.testError.value;
    final ok = controller.testMs.value;
    if (error.isEmpty && ok < 0) return const SizedBox.shrink();
    final isError = error.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? cs.errorContainer : oc.surface2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.cancel_outlined : Icons.check_circle_outline,
              size: 20, color: isError ? cs.onErrorContainer : oc.online),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isError ? "Couldn't reach the broker" : 'Broker reachable',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isError ? cs.onErrorContainer : null)),
                Text(isError ? error : '$ok ms · TLS valid · credentials accepted',
                    style: TextStyle(
                        fontSize: 13,
                        color: isError ? cs.onErrorContainer : oc.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
