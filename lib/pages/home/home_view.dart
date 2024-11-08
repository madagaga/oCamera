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
          title: Text("${controller.currentUser.deviceName} - Devices"),
          foregroundColor: Colors.white,
          backgroundColor: Colors.indigo,
          actions: <Widget>[
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 1,
                  child: Text('Disconnect'),
                ),
              ],
              onSelected: (value) {
                if (value == 1) {
                  controller.disconnect();
                }
              },
            )
          ]),
      //backgroundColor: Color(0xFFFF787F),
      body: RefreshIndicator(
        child: _buildBody(),
        onRefresh: () async {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Refreshing')));
          controller.getDevices();
        },
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
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(item.name),
            ),
            Stack(
              children: [
                if (item.snapshot.isEmpty)
                  Container(
                    alignment: Alignment.topLeft,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(160, 133, 131, 131),
                    ),
                    height: 200,
                    width: double.infinity,
                    child: const Icon(Icons.videocam,
                        size: 100, color: Color.fromARGB(111, 0, 0, 0)),
                  ),
                //   Image.network(
                //     'https://www.lightstalking.com/wp-content/uploads/still_life_1564647544-1024x1048.jpeg', // Replace with the actual image source
                //     width: double.infinity,
                //     height: 200,
                //     fit: BoxFit.cover,
                //     opacity: !item.online
                //         ? const AlwaysStoppedAnimation(.5)
                //         : const AlwaysStoppedAnimation(1),
                //   ),
                if (item.snapshot.isNotEmpty)
                  Image.memory(
                    item.snapshot,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    opacity: !item.online
                        ? const AlwaysStoppedAnimation(.5)
                        : const AlwaysStoppedAnimation(1),
                  ),
                Container(
                    alignment: Alignment.center,
                    height: 200,
                    child: Visibility(
                        visible: !item.streaming && item.online,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                              icon: const Icon(
                                Icons.play_arrow,
                                size: 32,
                                color: Colors.indigo,
                              ),
                              onPressed: () {
                                controller.videoCall(item);
                              }),
                        ))),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle,
                          color: item.online ? Colors.green : Colors.red,
                          size: 10),
                      const SizedBox(width: 4),
                      Text(item.online ? "Online" : "Offline"),
                    ],
                  ),
                  Visibility(
                    visible: item.streaming,
                    child: const Row(
                      children: [
                        Icon(Icons.stream, color: Colors.grey),
                        SizedBox(width: 4),
                        Text("on air"),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
