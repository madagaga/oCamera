// ignore_for_file: constant_identifier_names

part of 'app_pages.dart';

/// This class contains the definition of the different routes.
abstract class Routes {
  /// The splash route.
  static const CALL = '/call/:userId';

  /// The home route.
  static const HOME = '/home';
  
  static const LOGIN = "/login";
  static const POSITION = "/position";
  static const LOADING = "/loading";
}
