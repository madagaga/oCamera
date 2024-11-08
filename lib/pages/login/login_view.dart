import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rtc/pages/login/login_controller.dart';

/// This class is the view for the [Login] page.
class LoginView extends GetView<LoginController> {
  LoginView({super.key});

  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController loginController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController brokerController = TextEditingController(
      text: "tls://1720f847e41a4e1e9e17e321e32ec831.s2.eu.hivemq.cloud:8883");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Login"),
        foregroundColor: Colors.white,
        backgroundColor: Colors.indigo,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), labelText: "Device name"),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an unique name';
                    }
                    return null;
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: TextFormField(
                  controller: loginController,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), labelText: "Username"),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), labelText: "Password"),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: TextFormField(
                  controller: brokerController,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Broker url:port"),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter broker url';
                    }
                    return null;
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16.0),
                child: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        controller.saveUserData(
                            loginController.text,
                            passwordController.text,
                            brokerController.text,
                            nameController.text);
                        // Navigate the user to the Home page
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill input')),
                        );
                      }
                    },
                    style: const ButtonStyle(
                        backgroundColor:
                            WidgetStatePropertyAll<Color>(Colors.indigo),
                        foregroundColor:
                            WidgetStatePropertyAll<Color>(Colors.white)),
                    child: const Text('Login'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
