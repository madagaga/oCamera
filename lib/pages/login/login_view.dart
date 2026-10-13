import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rtc/pages/login/login_controller.dart';

/// This class is the view for the [Login] page.
class LoginView extends GetView<LoginController> {
  LoginView({super.key}) {
    // Initialize controllers with values from the controller
    _initializeControllers();
  }

  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController loginController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController brokerController = TextEditingController();
  
  void _initializeControllers() {
    // Set initial values
    nameController.text = controller.deviceName.value;
    loginController.text = controller.name.value;
    passwordController.text = controller.password.value;
    brokerController.text = controller.broker.value;
    
    // Listen for changes in the controller's variables
    ever(controller.deviceName, (value) => nameController.text = value);
    ever(controller.name, (value) => loginController.text = value);
    ever(controller.password, (value) => passwordController.text = value);
    ever(controller.broker, (value) => brokerController.text = value);
  }
  
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade800,
              Colors.indigo.shade500,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: size.height * 0.05),
                    // App Logo/Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.videocam,
                        size: 60,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // App Title
                    const Text(
                      "oCamera",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Sign in to your account",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Login Form
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Device Name Field
                          TextFormField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: "Device Name",
                              hintText: "Enter your device name",
                              prefixIcon: const Icon(Icons.devices, color: Colors.indigo),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.indigo, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a unique device name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Username Field
                          TextFormField(
                            controller: loginController,
                            decoration: InputDecoration(
                              labelText: "Username",
                              hintText: "Enter your username",
                              prefixIcon: const Icon(Icons.person, color: Colors.indigo),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.indigo, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your username';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Password Field
                          Obx(() {
                            // Create a local RxBool for password visibility
                            final obscureText = true.obs;
                            return TextFormField(
                              controller: passwordController,
                              obscureText: obscureText.value,
                              decoration: InputDecoration(
                                labelText: "Password",
                                hintText: "Enter your password",
                                prefixIcon: const Icon(Icons.lock, color: Colors.indigo),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureText.value ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => obscureText.value = !obscureText.value,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.indigo, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            );
                          }),
                          const SizedBox(height: 16),
                          // Broker URL Field
                          TextFormField(
                            controller: brokerController,
                            decoration: InputDecoration(
                              labelText: "Broker URL:Port",
                              hintText: "Enter broker URL and port",
                              prefixIcon: const Icon(Icons.link, color: Colors.indigo),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.indigo, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter broker URL';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  controller.saveUserData(
                                      loginController.text,
                                      passwordController.text,
                                      brokerController.text,
                                      nameController.text);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please fill all required fields')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                              ),
                              child: const Text(
                                'SIGN IN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Add extra padding at the bottom to ensure form is visible when keyboard is shown
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 
                      ? 120 
                      : 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


