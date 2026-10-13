import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../models/envelope.dart';
import '../models/ice_config.dart';
import '../models/user.dart';

/// Un `state` de caméra reçu ; payload vide = [removed].
typedef DeviceStateCallback = void Function(String devId, Map<String, dynamic>? state);

/// Un message de la boîte `ocam/cli/{self}/in/{fromId}`.
typedef InboxCallback = void Function(String fromId, Envelope env);
typedef ConnectCallback = void Function(bool);

/// Signalisation MQTT, protocole version 1 (voir MQTT_PROTOCOL.md).
class SignalingService {
  final _client = MqttServerClient('', '', maxConnectionAttempts: 5);

  final User _currentUser = User();

  StreamSubscription<List<MqttReceivedMessage<MqttMessage?>>>? _subscription;

  /// Configuration ICE publiée par l'administrateur (optionnelle).
  IceConfig? iceConfig;

  /// Derniers `state` reçus ; rejoués à l'abonné (les états retained arrivent
  /// avant que l'écran d'accueil existe).
  final Map<String, Map<String, dynamic>> _states = {};
  DeviceStateCallback? _onDeviceState;
  set onDeviceState(DeviceStateCallback? cb) {
    _onDeviceState = cb;
    if (cb != null) {
      _states.forEach(cb);
    }
  }

  InboxCallback? onInbox;
  ConnectCallback? onConnected;

  /// État de la connexion MQTT, pour l'affichage.
  final RxBool connected = false.obs;

  String get selfId => _currentUser.id;

  SignalingService() {
    _client.setProtocolV311();
    _client.autoReconnect = true;
    _client.resubscribeOnAutoReconnect = true;
    _client.keepAlivePeriod = 30;
    _client.onConnected = _onClientConnected;
    // les abonnements sont rétablis par la bibliothèque (resubscribeOnAutoReconnect)
    _client.onAutoReconnected = () {
      connected.value = true;
      onConnected?.call(true);
    };
    _client.onDisconnected = _onClientDisconnected;
  }

  Future<void> connect(User user) async {
    _currentUser.id = user.name; // identifiant = nom d'utilisateur MQTT
    _currentUser.name = user.name;
    _currentUser.password = user.password;
    _currentUser.broker = user.broker;
    _currentUser.deviceName = user.deviceName;

    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      return;
    }

    // Un viewer n'a pas de Last Will : il n'annonce pas sa présence.
    final connMessage = MqttConnectMessage()
        .authenticateAs(_currentUser.name, _currentUser.password)
        .startClean();

    final uri = Uri.parse(_currentUser.broker);
    _client.server = uri.host;
    _client.port = uri.port;
    _client.secure = true;
    // Le certificat du broker est validé (pas de onBadCertificate).
    _client.securityContext = SecurityContext.defaultContext;
    _client.clientIdentifier = _currentUser.id;
    _client.connectionMessage = connMessage;

    try {
      debugPrint('[MQTT] : connecting as ${_currentUser.name}');
      final result = await _client.connect();
      if (result?.state != MqttConnectionState.connected) {
        onConnected?.call(false);
        _client.disconnect();
      }
    } on Exception catch (e) {
      debugPrint('[MQTT] : client exception - $e');
      onConnected?.call(false);
      _client.disconnect();
    }
  }

  void _onClientConnected() {
    debugPrint('[MQTT] : connected');
    _subscription ??= _client.updates!.listen(_onMessages);
    _client.subscribe('ocam/dev/+/state', MqttQos.atLeastOnce);
    _client.subscribe('ocam/cli/$selfId/in/#', MqttQos.atLeastOnce);
    _client.subscribe('ocam/config/ice', MqttQos.atLeastOnce);
    connected.value = true;
    onConnected?.call(true);
  }

  void _onClientDisconnected() {
    debugPrint('[MQTT] : disconnected');
    connected.value = false;
    onConnected?.call(false);
  }

  void disconnect() => _client.disconnect();

  void _onMessages(List<MqttReceivedMessage<MqttMessage?>>? messages) {
    if (messages == null) return;
    for (final m in messages) {
      try {
        _onMessage(m.topic, m.payload as MqttPublishMessage);
      } catch (e) {
        debugPrint('[MQTT] : bad message on ${m.topic} - $e');
      }
    }
  }

  void _onMessage(String topic, MqttPublishMessage msg) {
    final raw = msg.payload.message;
    final parts = topic.split('/');
    if (parts.length < 3 || parts[0] != 'ocam') return;

    // ocam/dev/{id}/state
    if (parts[1] == 'dev' && parts.length == 4 && parts[3] == 'state') {
      final devId = parts[2];
      if (raw.isEmpty) {
        _states.remove(devId);
        _onDeviceState?.call(devId, null); // retrait de l'appareil
        return;
      }
      final json = jsonDecode(utf8.decode(raw));
      if (json is Map<String, dynamic>) {
        _states[devId] = json;
        _onDeviceState?.call(devId, json);
      }
      return;
    }

    // ocam/config/ice (absent, vide ou invalide = ignoré)
    if (parts[1] == 'config' && parts.length == 3 && parts[2] == 'ice') {
      iceConfig = raw.isEmpty
          ? null
          : IceConfig.tryParse(jsonDecode(utf8.decode(raw)));
      return;
    }

    // ocam/cli/{self}/in/{fromId} : l'expéditeur est le dernier niveau
    if (parts[1] == 'cli' && parts.length == 5 && parts[3] == 'in') {
      final env = Envelope.tryParse(jsonDecode(utf8.decode(raw)));
      if (env == null) return;
      if (env.v > Envelope.version) {
        debugPrint('[MQTT] : ignoring message with v=${env.v}');
        return;
      }
      if (!env.isFresh) {
        debugPrint('[MQTT] : ignoring stale ${env.type} (ts=${env.ts}), check the clock');
        return;
      }
      onInbox?.call(parts[4], env);
    }
  }

  /// Publie une enveloppe dans la boîte de la caméra `devId`.
  void sendTo(String devId, Envelope env) {
    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('[MQTT] : skip send, client not connected (${env.type})');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addUTF8String(jsonEncode(env.toJson()));
    _client.publishMessage(
        'ocam/dev/$devId/in/$selfId', MqttQos.atLeastOnce, builder.payload!);
  }

  /// Test de connexion depuis l'écran de login : `null` si le broker accepte
  /// les identifiants, sinon un message lisible. [onMs] reçoit la latence.
  static Future<String?> testConnection(
      User user, void Function(int ms) onMs) async {
    final client = MqttServerClient('', '', maxConnectionAttempts: 1)
      ..setProtocolV311()
      ..autoReconnect = false
      ..keepAlivePeriod = 30
      ..secure = true
      ..securityContext = SecurityContext.defaultContext;
    try {
      final uri = Uri.parse(user.broker);
      client.server = uri.host;
      client.port = uri.port;
      client.clientIdentifier = user.name;
      client.connectionMessage = MqttConnectMessage()
          .authenticateAs(user.name, user.password)
          .startClean();
      final sw = Stopwatch()..start();
      final result = await client.connect();
      onMs(sw.elapsedMilliseconds);
      if (result?.state == MqttConnectionState.connected) return null;
      return switch (result?.returnCode) {
        MqttConnectReturnCode.badUsernameOrPassword ||
        MqttConnectReturnCode.notAuthorized =>
          'The broker rejected these credentials.',
        _ => 'The broker refused the connection.',
      };
    } on HandshakeException {
      return "The broker's certificate isn't trusted.";
    } catch (_) {
      return 'Check the URL and that the broker is running.';
    } finally {
      client.disconnect();
    }
  }
}
