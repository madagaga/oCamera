import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../models/camera_profile.dart';
import '../models/envelope.dart';
import '../models/ice_config.dart';
import '../models/user.dart';

/// A camera `state` received; empty payload = [removed].
typedef DeviceStateCallback = void Function(String devId, Map<String, dynamic>? state);

/// A message from the mailbox `ocam/cli/{self}/in/{fromId}`.
typedef InboxCallback = void Function(String fromId, Envelope env);
typedef ConnectCallback = void Function(bool);

/// MQTT signaling, protocol version 1 (see MQTT_PROTOCOL.md).
class SignalingService {
  final _client = MqttServerClient('', '', maxConnectionAttempts: 5);

  final User _currentUser = User();

  StreamSubscription<List<MqttReceivedMessage<MqttMessage?>>>? _subscription;

  /// ICE configuration published by the administrator (optional).
  IceConfig? iceConfig;

  /// Latest `state` messages received; replayed to the subscriber (retained
  /// states arrive before the home screen exists).
  final Map<String, Map<String, dynamic>> _states = {};
  DeviceStateCallback? _onDeviceState;
  set onDeviceState(DeviceStateCallback? cb) {
    _onDeviceState = cb;
    if (cb != null) {
      _states.forEach(cb);
    }
  }

  InboxCallback? onInbox;
  InboxCallback? onStale;
  ConnectCallback? onConnected;

  /// Set before [connect] to act as a camera (retained state + Last Will,
  /// subscription to `ocam/dev/{self}/in/#`); `null` = viewer.
  CameraProfile? cameraProfile;

  bool get isCamera => cameraProfile != null;

  /// MQTT connection state, for display.
  final RxBool connected = false.obs;

  String get selfId => _currentUser.id;

  // Reconnection is handled here rather than by the library: its auto
  // reconnect stops for good when a network error is thrown while the network
  // is down (DNS failure, aborted socket), which left the camera offline until
  // the app was reopened.
  bool _wantConnected = false;
  bool _everConnected = false;
  int _retry = 0;
  Timer? _retryTimer;

  SignalingService() {
    _client.setProtocolV311();
    _client.autoReconnect = false;
    _client.keepAlivePeriod = 30;
    // Without this a half-open connection (Wi-Fi gone, socket still open) is
    // never noticed: drop it when a ping gets no answer for 10 s.
    _client.disconnectOnNoResponsePeriod = 10;
    _client.onConnected = _onClientConnected;
    _client.onDisconnected = _onClientDisconnected;
  }

  Future<void> connect(User user) async {
    _currentUser.id = user.name; // id = MQTT username
    _currentUser.name = user.name;
    _currentUser.password = user.password;
    _currentUser.broker = user.broker;
    _currentUser.deviceName = user.deviceName;

    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      return;
    }

    // A viewer has no Last Will: it does not announce its presence. A camera
    // has one: the broker publishes `online:false` if it disappears.
    var connMessage = MqttConnectMessage()
        .authenticateAs(_currentUser.name, _currentUser.password)
        .startClean();
    final profile = cameraProfile;
    if (profile != null) {
      connMessage = connMessage
          .withWillTopic('ocam/dev/$selfId/state')
          .withWillMessage(
              jsonEncode(profile.state(online: false, busy: false)))
          .withWillQos(MqttQos.atLeastOnce)
          .withWillRetain();
    }

    final uri = Uri.parse(_currentUser.broker);
    _client.server = uri.host;
    _client.port = uri.port;
    _client.secure = true;
    // The broker certificate is validated (no onBadCertificate).
    _client.securityContext = SecurityContext.defaultContext;
    _client.clientIdentifier = _currentUser.id;
    _client.connectionMessage = connMessage;

    _wantConnected = true;
    try {
      debugPrint('[MQTT] : connecting as ${_currentUser.name}');
      final result = await _client.connect();
      if (result?.state != MqttConnectionState.connected) {
        _giveUp();
      }
    } on Exception catch (e) {
      debugPrint('[MQTT] : client exception - $e');
      _giveUp();
    }
  }

  /// The first connection failed: report it, no retry loop.
  void _giveUp() {
    _wantConnected = false;
    onConnected?.call(false);
    _client.disconnect();
  }

  void _onClientConnected() {
    debugPrint('[MQTT] : connected');
    // each successful connect() builds a new update stream
    _subscription?.cancel();
    _subscription = _client.updates!.listen(_onMessages);
    _everConnected = true;
    _retry = 0;
    _retryTimer?.cancel();
    if (isCamera) {
      _client.subscribe('ocam/dev/$selfId/in/#', MqttQos.atLeastOnce);
    } else {
      _client.subscribe('ocam/dev/+/state', MqttQos.atLeastOnce);
      _client.subscribe('ocam/cli/$selfId/in/#', MqttQos.atLeastOnce);
      _client.subscribe('ocam/config/ice', MqttQos.atLeastOnce);
    }
    connected.value = true;
    onConnected?.call(true);
  }

  void _onClientDisconnected() {
    debugPrint('[MQTT] : disconnected');
    connected.value = false;
    onConnected?.call(false);
    _scheduleReconnect();
  }

  /// Retries forever after a connection that had been established was lost:
  /// 2, 4, 8, 16 s, then every 30 s.
  void _scheduleReconnect() {
    if (!_wantConnected || !_everConnected) return;
    _retryTimer?.cancel();
    final seconds = _retry >= 4 ? 30 : 2 << _retry;
    _retry++;
    debugPrint('[MQTT] : reconnecting in ${seconds}s (attempt $_retry)');
    _retryTimer = Timer(Duration(seconds: seconds), _reconnect);
  }

  Future<void> _reconnect() async {
    if (!_wantConnected) return;
    try {
      final result = await _client.connect();
      if (result?.state == MqttConnectionState.connected) return;
    } catch (e) {
      debugPrint('[MQTT] : reconnect failed - $e');
    }
    _client.disconnect(); // may trigger onDisconnected, which reschedules
    _scheduleReconnect();
  }

  void disconnect() {
    _wantConnected = false;
    _everConnected = false;
    _retryTimer?.cancel();
    _client.disconnect();
  }

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

    // camera: ocam/dev/{self}/in/{fromId}
    if (isCamera) {
      if (parts[1] == 'dev' && parts.length == 5 && parts[3] == 'in') {
        _dispatchInbox(parts[4], raw);
      }
      return;
    }

    // ocam/dev/{id}/state
    if (parts[1] == 'dev' && parts.length == 4 && parts[3] == 'state') {
      final devId = parts[2];
      if (raw.isEmpty) {
        _states.remove(devId);
        _onDeviceState?.call(devId, null); // device removed
        return;
      }
      final json = jsonDecode(utf8.decode(raw));
      if (json is Map<String, dynamic>) {
        _states[devId] = json;
        _onDeviceState?.call(devId, json);
      }
      return;
    }

    // ocam/config/ice (missing, empty or invalid = ignored)
    if (parts[1] == 'config' && parts.length == 3 && parts[2] == 'ice') {
      iceConfig = raw.isEmpty
          ? null
          : IceConfig.tryParse(jsonDecode(utf8.decode(raw)));
      return;
    }

    // ocam/cli/{self}/in/{fromId}: the sender is the last level
    if (parts[1] == 'cli' && parts.length == 5 && parts[3] == 'in') {
      _dispatchInbox(parts[4], raw);
    }
  }

  void _dispatchInbox(String fromId, List<int> raw) {
    final env = Envelope.tryParse(jsonDecode(utf8.decode(raw)));
    if (env == null) return;
    if (env.v > Envelope.version) {
      debugPrint('[MQTT] : ignoring message with v=${env.v}');
      return;
    }
    if (!env.isFresh) {
      debugPrint(
          '[MQTT] : ignoring stale ${env.type} (ts=${env.ts}), check the clock');
      // a stale offer gets an `error` (§ 4)
      onStale?.call(fromId, env);
      return;
    }
    onInbox?.call(fromId, env);
  }

  /// Publishes an envelope to the mailbox of camera `devId`.
  void sendTo(String devId, Envelope env) {
    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('[MQTT] : skip send, client not connected (${env.type})');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addUTF8String(jsonEncode(env.toJson()));
    _client.publishMessage(
        'ocam/dev/$devId/in/$selfId', MqttQos.atLeastOnce, builder.payload!);
  }

  /// Camera: publishes an envelope to the mailbox of viewer `viewerId`.
  void sendToViewer(String viewerId, Envelope env) {
    if (_client.connectionStatus?.state != MqttConnectionState.connected) return;
    final builder = MqttClientPayloadBuilder()
      ..addUTF8String(jsonEncode(env.toJson()));
    _client.publishMessage('ocam/cli/$viewerId/in/$selfId',
        MqttQos.atLeastOnce, builder.payload!);
  }

  /// Camera: publishes its `state` (retained).
  void publishState(Map<String, dynamic> state) {
    if (_client.connectionStatus?.state != MqttConnectionState.connected) return;
    final builder = MqttClientPayloadBuilder()..addUTF8String(jsonEncode(state));
    _client.publishMessage('ocam/dev/$selfId/state', MqttQos.atLeastOnce,
        builder.payload!,
        retain: true);
  }

  /// Connection test from the login screen: `null` if the broker accepts
  /// the credentials, otherwise a readable message. [onMs] receives the latency.
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
