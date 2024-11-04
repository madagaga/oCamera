// ignore_for_file: non_constant_identifier_names

import 'package:get/get.dart';
import 'package:rtc/pages/call/call_binding.dart';
import 'package:rtc/pages/call/call_view.dart';
import 'package:rtc/pages/home/home_view.dart';
import 'package:rtc/pages/home/home_binding.dart';
import 'package:rtc/pages/loading/loading_binding.dart';
import 'package:rtc/pages/loading/loading_view.dart';
import 'package:rtc/pages/login/login_binding.dart';
import 'package:rtc/pages/login/login_view.dart';

part 'app_routes.dart';

/// This class contains the definition of the different applications pages.
class AppPages {
  /// The initial route navigated.
  static String INITIAL = Routes.LOADING;

  /// Every [GetPage] page routes of the application.
  static final routes = [
    GetPage(
      name: Routes.LOGIN,
      page: () => LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: Routes.LOADING,
      page: () => const LoadingView(),
      binding: LoadingBinding(),
    ),
    GetPage(
      name: Routes.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: Routes.CALL,
      page: () => const CallView(),
      binding: CallBinding(),
    ),
  ];
}
