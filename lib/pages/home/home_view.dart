import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../models/devices.dart';
import '../../theme/app_theme.dart';
import 'home_controller.dart';

/// Écran d'accueil : état du broker + une vignette 16:9 par caméra.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text('oCamera'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.tune, color: oc.muted),
            tooltip: 'Settings',
            onSelected: (v) {
              if (v == 'theme') {
                final dark = Get.isDarkMode;
                Get.changeThemeMode(dark ? ThemeMode.light : ThemeMode.dark);
                GetStorage().write('theme', dark ? 'light' : 'dark');
              } else if (v == 'logout') {
                controller.disconnect();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'theme',
                child: Text(Get.isDarkMode ? 'Light theme' : 'Dark theme'),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Disconnect')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _StatusBar(controller: controller),
          Expanded(
            child: Obx(() {
              final list = controller.devices.values.toList()
                ..sort((a, b) {
                  if (a.online != b.online) return a.online ? -1 : 1;
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });
              if (list.isEmpty) return const _EmptyState();
              return LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth >= 900
                    ? 3
                    : c.maxWidth >= 600
                        ? 2
                        : 1;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 16,
                    mainAxisExtent: (c.maxWidth - 32 - (cols - 1) * 16) /
                            cols *
                            9 /
                            16 +
                        64,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _CameraTile(
                    device: list[i],
                    onOpen: () => controller.videoCall(list[i]),
                    onDetails: () => _showDetails(context, list[i]),
                  ),
                );
              });
            }),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, Device d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetailsSheet(
        device: d,
        onOpen: () {
          Navigator.of(context).pop();
          controller.videoCall(d);
        },
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final HomeController controller;
  const _StatusBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Obx(() {
      final connected = controller.signalingService.connected.value;
      final online = controller.devices.values.where((d) => d.online).length;
      final host = Uri.tryParse(controller.currentUser.broker)?.host ?? '';
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: oc.surface2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _Dot(connected ? oc.online : oc.inUse),
            const SizedBox(width: 8),
            Text(
              connected ? 'Connected · $online online' : 'Reconnecting…',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Flexible(
              child: Text(host,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'monospace', fontSize: 12, color: oc.muted)),
            ),
          ],
        ),
      );
    });
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _CameraTile extends StatelessWidget {
  final Device device;
  final VoidCallback onOpen;
  final VoidCallback onDetails;
  const _CameraTile(
      {required this.device, required this.onOpen, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final cs = Theme.of(context).colorScheme;
    final d = device;
    final status = !d.online ? 'Offline' : d.busy ? 'In use' : 'Online';
    final dot = !d.online ? oc.offline : d.busy ? oc.inUse : oc.online;
    final canOpen = d.online && !d.busy;
    final meta = [
      d.isPhone ? 'Phone' : 'IP camera',
      if (d.agent != null) d.agent!,
    ].join(' · ');

    return Semantics(
      label: '${d.name}, $status. Long-press for details.',
      button: true,
      child: Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canOpen ? onOpen : onDetails,
          onLongPress: onDetails,
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (d.snapshot.isEmpty)
                      ColoredBox(
                        color: oc.surface3,
                        child: Icon(
                            d.online ? Icons.videocam_outlined : Icons.videocam_off_outlined,
                            size: 40,
                            color: oc.outlineStrong),
                      )
                    else
                      Opacity(
                        opacity: d.online ? 1 : 0.4,
                        child: Image.memory(d.snapshot,
                            fit: BoxFit.cover, gaplessPlayback: true),
                      ),
                    if (canOpen)
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                              color: Color(0x8C000000), shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 32),
                        ),
                      ),
                    if (d.busy)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE3A008),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            d.viewer == null
                                ? 'In use'
                                : 'In use · ${d.viewer}',
                            style: const TextStyle(
                                color: Color(0xFF1F1300),
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    if (!d.online)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: const Color(0x99000000),
                              borderRadius: BorderRadius.circular(16)),
                          child: const Text('Offline',
                              style: TextStyle(
                                  color: Color(0xFFE6E9EB), fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            if (d.isPhone) ...[
                              Icon(Icons.smartphone, size: 16, color: oc.muted),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(d.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                          Text(meta,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: oc.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _Dot(dot),
                    const SizedBox(width: 6),
                    Text(status,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: oc.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: oc.accentContainer,
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.videocam_outlined,
                  size: 36, color: oc.onAccentContainer),
            ),
            const SizedBox(height: 20),
            const Text('No cameras yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Cameras appear here as soon as they come online. Check that the camera agent uses the same broker.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: oc.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsSheet extends StatelessWidget {
  final Device device;
  final VoidCallback onOpen;
  const _DetailsSheet({required this.device, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final cs = Theme.of(context).colorScheme;
    final d = device;
    final status = !d.online ? 'Offline' : d.busy ? 'In use' : 'Online';

    Widget row(String label, Widget value) => Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outline))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 88,
                  child: Text(label,
                      style: TextStyle(fontSize: 13, color: oc.muted))),
              Expanded(child: value),
            ],
          ),
        );

    Widget chips(List<String> items) => Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final i in items)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    border: Border.all(color: oc.outlineStrong),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(i.toUpperCase(),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12)),
              ),
          ],
        );

    final codecs = [...d.caps.video, ...d.caps.audio];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: oc.accentContainer,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(d.isPhone ? Icons.smartphone : Icons.videocam_outlined,
                    color: oc.onAccentContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    Text('$status · ${d.isPhone ? 'Phone camera' : 'IP camera'}',
                        style: TextStyle(fontSize: 13, color: oc.muted)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Divider(color: cs.outline),
            row('Agent', Text(d.agent ?? 'Unknown')),
            row('Codecs',
                codecs.isEmpty ? const Text('Not reported') : chips(codecs)),
            row(
                'Streams',
                d.caps.streams.isEmpty
                    ? const Text('Default')
                    : chips(d.caps.streams)),
            row(
                'Supports',
                Text(d.caps.cmds.isEmpty
                    ? 'No remote commands'
                    : d.caps.cmds.join(' · '))),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: d.online && !d.busy ? onOpen : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(!d.online
                  ? 'Camera is offline'
                  : d.busy
                      ? 'Camera is in use'
                      : 'Open live view'),
            ),
          ],
        ),
      ),
    );
  }
}
