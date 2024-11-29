# oCamera

Open source camera P2P WebRTC client for the oCamera app. This project aims to provide a peer-to-peer camera client using WebRTC technology, allowing for seamless, real-time communication.

## Features

- Peer-to-peer camera streaming using WebRTC.
- Integration with the oCamera app.
- Flutter-based UI for cross-platform compatibility.
- Connect two or more devices running the oCamera application to enable real-time video communication.
- One-way video streaming (from RTSP camera to oCamera).

## How It Works

oCamera leverages WebRTC to establish a direct connection between two or more devices, allowing for peer-to-peer (P2P) video streaming without the need for an intermediary server. Here's a detailed look at how it works:

1. **MQTT Signaling**: The signaling process is implemented using MQTT, a lightweight messaging protocol. The `signaling_channel.dart` file manages the connection to an MQTT broker, which acts as a signaling server. The MQTT client handles topics for communication, including:
   - **Offer and Answer Exchange**: The signaling channel listens for SDP (Session Description Protocol) packets, including offers and answers, to establish a WebRTC connection.
   - **ICE Candidates**: ICE (Interactive Connectivity Establishment) candidates are exchanged via MQTT messages to help peers establish a reliable connection.
   - **Device Discovery**: The signaling service also manages device discovery and maintains a list of connected devices, ensuring efficient communication.

2. **WebRTC Protocol**: Once signaling is complete, WebRTC is used to create a secure, encrypted P2P channel between devices. This channel is used to transmit video data directly between peers, ensuring low latency and high-quality video streaming.

3. **NAT Traversal**: The application uses technologies like STUN (Session Traversal Utilities for NAT) to overcome network obstacles, such as firewalls and NATs (Network Address Translators), which may otherwise block P2P connections. The only external server involved is the STUN server (e.g., Google's STUN server).

4. **One-Way Video Streaming**: The initial design of oCamera focuses on transmitting RTSP video streams to oCamera, allowing users to view video feeds from an RTSP camera on their mobile devices.

5. **No Data Retention**: oCamera does not use any proxy servers for signaling or data storage. All signaling occurs via MQTT with no data retention, ensuring a secure and privacy-focused solution.

6. **Alternative to Chinese P2P Solutions**: oCamera provides an alternative to standard P2P solutions provided by many Chinese cameras, ensuring that no data is sent to unknown third-party servers. Except for the STUN server, no data passes through external servers, giving users full control over their data.

7. **Flutter-based UI**: The client interface is built using Flutter, which ensures the application can run on both Android and iOS devices with a consistent user experience. The UI provides options to configure the connection settings, such as specifying the MQTT broker and managing video streams.

## Getting Started

This project is built using Flutter. To get started:

1. Install dependencies:
   ```
   flutter pub get
   ```

2. Run the app:
   ```
   flutter run
   ```

## Quick Start with oCameraAgent

To quickly get started with the full oCamera solution, you will also need to set up the [oCameraAgent](https://github.com/madagaga/oCameraAgent) project. The agent is used to connect to an RTSP camera and transmit the video stream to oCamera, allowing it to be viewed by other devices connected via oCamera.

### Steps:
1. Download the precompiled binaries (x86 and ARM) from the [oCameraAgent releases](https://github.com/madagaga/oCameraAgent/releases).
2. Follow the setup instructions in the oCameraAgent repository to run the agent.
3. Ensure that you have an MQTT broker set up. You can either self-host an MQTT broker or create an account with an online MQTT broker service, such as [HiveMQ](https://www.hivemq.com).
4. Configure both the oCamera app and oCameraAgent to use the same MQTT broker for signaling.

## Requirements

- Flutter SDK
- Dart
- Android/iOS device or emulator

## Installation

Ensure you have the Flutter SDK installed and configured. Follow [Flutter's installation guide](https://flutter.dev/docs/get-started/install) for your operating system.

## Usage

- Launch the app to connect to the MQTT broker and start peer-to-peer camera streaming.
- Configure the settings in the app to connect to the appropriate MQTT broker.
- Connect two or more devices running the oCamera app to enable video communication between them.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request with your improvements.

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Commit your changes (`git commit -m 'Add new feature'`).
4. Push to the branch (`git push origin feature-branch`).
5. Open a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

For questions or suggestions, please reach out to the maintainer at [GitHub Issues](https://github.com/madagaga/oCamera/issues).

