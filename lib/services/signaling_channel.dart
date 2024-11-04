import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/action_packet.dart';
import '../models/devices.dart';
import '../models/ice_packet.dart';
import '../models/sdp_packet.dart';
import '../models/user.dart';

import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

typedef OfferReceivedCallback = Function(SdpPacket);
typedef AnswerReceivedCallback = Function(SdpPacket);
typedef IceCandidateReceivedCallback = Function(IcePacket);
typedef ActionReceivedCallback = Function(ActionPacket);
typedef DeviceReceivedCallback = Function(Device);
typedef ConnectCallback = Function(bool);

class SignalingService {
  final _client = MqttServerClient('', '', maxConnectionAttempts: 5);

  final User _currentUser = User();
  final Device _currentDevice = Device('', '', '', true);

  StreamSubscription<List<MqttReceivedMessage<MqttMessage?>>>?
      streamSubscription;

  DeviceReceivedCallback? _onNewDeviceFound;
  set onNewDeviceFound(DeviceReceivedCallback? cb) {
    _onNewDeviceFound = cb;
  }

  OfferReceivedCallback? _onOfferReceived;
  set onOfferReceived(OfferReceivedCallback? cb) {
    _onOfferReceived = cb;
  }

  AnswerReceivedCallback? _onAnswerReceived;
  set onAnswerReceived(AnswerReceivedCallback? cb) {
    _onAnswerReceived = cb;
  }

  IceCandidateReceivedCallback? _onIceCandidateReceived;
  set onIceCandidateReceived(IceCandidateReceivedCallback? cb) {
    _onIceCandidateReceived = cb;
  }

  ActionReceivedCallback? _onActionReceived;
  set onActionReceived(ActionReceivedCallback? cb) {
    _onActionReceived = cb;
  }

  ConnectCallback? _onConnected;
  set onConnected(ConnectCallback? cb) {
    _onConnected = cb;
  }

  SignalingService() {
    /// Set logging on if needed, defaults to off
    _client.logging(on: true);

    /// Set the correct MQTT protocol for mosquito
    _client.setProtocolV311();

    /// Set auto reconnect
    _client.autoReconnect = true;

    _client.resubscribeOnAutoReconnect = true;

    _client.keepAlivePeriod = 20;
    _client.onConnected = _onClientConnected;
    _client.onDisconnected = _onClientDisconnected;
  }

  // waiting for the connection, if an error occurs, print it and disconnect
  Future<void> connect(User user) async {
    if (!_currentUser.isValid()) {
      _currentUser.id = user.id;
      _currentUser.name = user.name;
      _currentUser.password = user.password;
      _currentUser.broker = user.broker;

      _currentDevice.id = user.id;
      _currentDevice.name = user.name;
      _currentDevice.type = 'smartphone';
    }

    // if already connected cancel
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      return;
    }

    final connMessage = MqttConnectMessage()
        .authenticateAs(_currentUser.name, _currentUser.password)
        .withWillTopic('willtopic')
        .withWillMessage('Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client.autoReconnect = true;
    final uri = Uri.parse(_currentUser.broker);

    _client.server = uri.host;
    _client.port = uri.port;
    _client.secure = true;
    _client.securityContext = SecurityContext.defaultContext;
    _client.clientIdentifier = _currentUser.id;
    _client.connectionMessage = connMessage;

    try {
      print('client connecting....');
      MqttClientConnectionStatus? result = await _client.connect();
      if (result!.state != MqttConnectionState.connected &&
          result.state != MqttConnectionState.connecting) {
        _onConnected!(false);
        return;
      }

      _client.subscribe('/devices', MqttQos.atLeastOnce);
      _client.subscribe('/${_currentUser.id}', MqttQos.atLeastOnce);
    } on Exception catch (e) {
      _onConnected!(false);
      print('client exception - $e');
      _client.disconnect();
    }

    // when connected, print a confirmation, else print an error
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      print('client connected');
    } else {
      print(
          'ERROR client connection failed - disconnecting, status is ${_client.connectionStatus}');
      _client.disconnect();
    }
  }

  void _onClientConnected() {
    try {
      print('connected');
      heartBeat(true);

      streamSubscription ??= _client.updates!.listen(_onNewMessageReceived);

      if (_onConnected != null) {
        _onConnected!(true);
      }
    } on Exception catch (_) {
      print(_);
    }
  }

  void _onClientDisconnected() {
    print('disconnected');
  }

  void _onNewMessageReceived(List<MqttReceivedMessage<MqttMessage?>>? c) {
    try {
      if (c == null) {
        return;
      }

      final recMess = c[0].payload as MqttPublishMessage;

      final pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final data = jsonDecode(pt);
      if (data['source'] == _currentUser.id) {
        return;
      }

      print(
          'MQTT_LOGS:: New data arrived: topic is <${c[0].topic}>, payload is $pt');
      print('');

      switch (data['type'] as String) {
        case 'sdp':
          final Map<String, dynamic> jsonData = data['data'];
          if (jsonData['type'] as String == 'offer') {
            if (_onOfferReceived == null) {
              return;
            }

            _onOfferReceived!(SdpPacket(data['source'],
                RTCSessionDescription(jsonData['sdp'], jsonData['type'])));
          } else if (jsonData['type'] as String == 'answer') {
            if (_onAnswerReceived == null) {
              return;
            }
            _onAnswerReceived!(SdpPacket(data['source'],
                RTCSessionDescription(jsonData['sdp'], jsonData['type'])));
          }
          break;
        case 'ice':
          if (_onIceCandidateReceived == null) {
            return;
          }
          final Map<String, dynamic> jsonData = data['data'];
          _onIceCandidateReceived!(IcePacket(
              data['source'],
              RTCIceCandidate(
                  jsonData['candidate'] as String,
                  jsonData['sdpMid'] as String,
                  jsonData['sdpMLineIndex'] as int)));
          break;
        case 'hangup':
        case 'flipCamera':
        case 'error':
          if (_onActionReceived == null) {
            return;
          }
          _onActionReceived!(ActionPacket(data['source'] as String, data));
          break;
        case 'device':
          if (_onNewDeviceFound == null) {
            return;
          }

          final Map<String, dynamic> jsonData = data['data'];
          Device u = Device.fromJson(jsonData);
          _onNewDeviceFound!(u);

        case 'query':
          heartBeat(true);
      }
    } on Exception catch (_) {
      print(_);
    }
  }

  void heartBeat(bool online) async {
    _currentDevice.online = online;
    final pkt = {'type': 'device', 'data': _currentDevice.toJson()};
    _send('/devices', pkt);
  }

  void _send(String channel, Map<String, dynamic> data) {
    data['source'] = _currentUser.id;
    final builder1 = MqttClientPayloadBuilder();
    builder1.addString(jsonEncode(data));
    if (_client.connectionStatus!.state == MqttConnectionState.connected) {
      _client.publishMessage(channel, MqttQos.atLeastOnce, builder1.payload!);
    }
  }

  void sendIceCandidate(String targetId, RTCIceCandidate iceCandidate) {
    final pkt = {
      "type": 'ice',
      "data": iceCandidate.toMap(),
    };

    _send("/$targetId", pkt);
  }

  void sendSDP(String targetId, RTCSessionDescription sdp) {
    final pkt = {
      "type": 'sdp',
      "data": sdp.toMap(),
    };

    _send("/$targetId", pkt);
  }

  void hangup(String targetId) {
    final pkt = {
      "type": 'hangup',
    };
    _send("/$targetId", pkt);
  }

  void getDevices() {
    final pkt = {'type': 'query'};
    _send('/devices', pkt);
  }

  void flipCamera(String targetId) {
    final pkt = {
      "type": 'flipCamera',
    };
    _send("/$targetId", pkt);
  }
}
