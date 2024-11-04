import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'home_controller.dart';

/// This class is the view for the [Home] page.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(HomeController());
    return Scaffold(
      appBar: AppBar(
          title: Text("${controller.currentUser.name} - Devices"),
          foregroundColor: Colors.white,
          backgroundColor: Colors.indigo,
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Show Snackbar',
              onPressed: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Refreshing')));
                controller.getDevices();
              },
            )
          ]),
      //backgroundColor: Color(0xFFFF787F),
      body: Column(
        children: [
          Expanded(
            child: _buildBody(),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  /// This function builds the body.
  Widget _buildBody() {
    return Column(children: [
      Expanded(
        child: Obx(
          () => ListView.builder(
            itemCount:
                controller.devices.isNotEmpty ? controller.devices.length : 1,
            itemBuilder: _devicesListItemBuilder,
          ),
        ),
      ),
    ]);
  }

  /// Builds a device list item.
  ///
  /// Returns the item widget.
  Widget? _devicesListItemBuilder(BuildContext context, int index) {
    if (controller.devices.isEmpty) {
      return const ListTile(
        title: Text("No devices"),
      );
    }
    final item = controller.devices.values.elementAt(index);
    return ListTile(
      contentPadding:
          const EdgeInsets.only(left: 5, right: 5, top: 0, bottom: 0),
      minTileHeight: 5,
      title: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: item.online ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(item.name),
        ],
      ),
      // shape: Border(
      //   bottom: BorderSide(color: Colors.blueGrey.withOpacity(0.3)),
      // ),
      trailing: item.online
          ? Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () {
                  controller.videoCall(item);
                },
              )
            ])
          : null,
    );
  }

  /// This function builds a footer.
  Widget _buildFooter() {
    return const SizedBox.shrink();
  }
}
