import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rtc/pages/loading/loading_controller.dart';

class LoadingView extends GetView<LoadingController> {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
        title: const Text("Authenticating"),
        foregroundColor: Colors.white,
        backgroundColor: Colors.indigo,
      ),
    body: InkWell(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          /// Paint the area where the inner widgets are loaded with the
          /// background to keep consistency with the screen background
          Container(
            //decoration: const BoxDecoration(color: Colors.black),
          ),
          /// Render the background image
          // Container(
          //   child: Image.asset(‘assets/somebackground.png’, fit: BoxFit.cover),
          // ),
          /// Render the Title widget, loader and messages below each other
          const Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 3,
                
                    child:   Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                         Padding(
                          padding: EdgeInsets.only(top: 30.0),
                        ),
                        Text("Connecting to broker"),
                      ],
                    ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    /// Loader Animation Widget
                    CircularProgressIndicator(
                      valueColor:  AlwaysStoppedAnimation<Color>(
                          Colors.green),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 20.0),
                    ),
                    Text("Please wait"),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


