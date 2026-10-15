# oCamera

**Watch your cameras from anywhere, directly. No cloud, no account, no port forwarding.**

oCamera is an open source Android app that opens your IP cameras (and your old phones turned into cameras)
over an encrypted, peer-to-peer WebRTC link. The video goes from the camera to your phone, and nowhere else:
no vendor server, no "P2P service" run by someone you have never heard of.

```
 IP camera (RTSP) ─▶ oCamera agent (Go) ◀── MQTT broker (signaling only) ──▶ oCamera app
 Old phone (camera mode) ───────────────────────┘                                  │
                          ╚══════════ WebRTC, encrypted, peer-to-peer ═════════════╝
```

## Why oCamera

- **Your video stays yours.** The stream is end-to-end encrypted (WebRTC DTLS-SRTP) between the camera
  side and your phone. Nothing is stored, relayed or analysed by a third party.
- **Nothing to expose.** The camera side only makes outgoing connections. No port forwarding, no dynamic
  DNS, no VPN to maintain, nothing listening on your network.
- **You choose the only server involved.** A small MQTT broker carries a few messages to set up each
  connection (no video). Run your own [Mosquitto](https://mosquitto.org) or use a free hosted one.
- **Cameras for every drawer.** Watch RTSP cameras through the lightweight
  [oCameraAgent](https://github.com/madagaga/oCameraAgent) (a single Go binary, about 10 MB, around 13 to
  16 MB of RAM), or **turn an old Android phone into a camera** with the same app.
- **Built for old hardware.** In camera mode the phone only encodes with its hardware encoder, keeps the
  screen off, and sips battery: about 1.4 % per hour in standby on a recycled phone (measured, release
  build, screen off).
- **Open protocol.** The signaling is documented in `MQTT_PROTOCOL.md`; write your own camera or viewer.

## What the app does

**As a viewer**
- Lists your cameras with their live status: online, offline, in use, and the battery level of phone
  cameras (plugged in or not).
- Opens the live video in one tap, with pinch zoom, and shows the link type (direct or relayed), codec and
  bitrate.
- **SD / HD** switch per camera, when the camera offers several streams.
- **Records clips** to your gallery (album "oCamera") with a choice of three qualities (about 55, 110 or
  225 MB per hour).
- **Sound on demand**: starts muted, and plays on the loudspeaker, the earpiece or a Bluetooth / wired
  headset.
- Dark and light themes, and a connection test on the sign-in screen.

**As a camera** (any Android phone)
- Stays reachable with the screen off, through an Android foreground service, and reconnects by itself
  after a network loss.
- Offers SD and HD streams with a bitrate cap, and only the codecs your phone can encode in hardware.
- Remote commands: flip the camera, torch.

## oCamera vs go2rtc

[go2rtc](https://github.com/AlexxIT/go2rtc) is an excellent, much broader camera streaming server: many
inputs and outputs, a web UI, and tight integration with Home Assistant and Frigate. oCamera is
deliberately narrower. Pick the one that fits.

| | **oCamera** | **go2rtc** |
|---|---|---|
| Goal | Reach your cameras from your phone, privately, with nothing exposed | Universal stream hub: many sources, many outputs |
| Remote access | Outgoing connections only, MQTT broker for signaling, direct WebRTC | Direct WebRTC may work through hole punching; stable external access needs port 8555 opened (TCP and UDP) on your router |
| Client | Dedicated Android app (viewer and phone-camera mode) | Web UI and HTTP API, Home Assistant, any compatible player |
| Camera side | oCameraAgent (about 10 MB, 13 to 16 MB of RAM), or an old phone | One binary with a much larger feature set |
| Sources and outputs | RTSP in (or the phone camera), WebRTC out | Dozens of protocols in and out, optional FFmpeg transcoding |
| Viewers | One at a time per camera | Many consumers |
| Recording | Clips recorded on the viewer, low bitrate | Not described in its README; usually paired with Home Assistant or Frigate |
| Extra infrastructure | An MQTT broker (free or self-hosted) | None for local use |

**Choose oCamera** for a private, no-exposure way to watch cameras from your phone, on modest hardware, and
to recycle old phones as cameras. **Choose go2rtc** to convert between protocols, share one camera with many
viewers, transcode, or plug into a home automation hub. They also work together: the agent only needs an RTSP
URL, which go2rtc can provide.

## Get started

1. **A broker.** Create an account for each camera and each phone on your MQTT broker (TLS, login and
   password). Per-account access rules are described in `MQTT_PROTOCOL.md` (project root).
2. **A camera.**
   - *IP camera:* run the [oCameraAgent](https://github.com/madagaga/oCameraAgent) on a small always-on
     machine (router, Raspberry Pi, NAS, mini PC). Download a binary from its
     [releases](https://github.com/madagaga/oCameraAgent/releases), copy `config.yaml.template` to
     `config.yaml`, fill in your broker and the camera's RTSP URL, then run
     `./oCameraAgent -config config.yaml`.
   - *Old phone:* install the app, pick **Camera** on the sign-in screen and use the camera's own account.
3. **The viewer.** Install the app on your phone, pick **Viewer**, enter your broker address and your
   account: your cameras appear.

## Honest limits

- It needs an MQTT broker. If you want something with no infrastructure at all, this is not it.
- One viewer per camera at a time; a second viewer is told the camera is busy.
- STUN (to find a path through your router) uses free public servers by default and carries no video. On
  strict networks (some mobile carriers, corporate NATs), add a TURN server: see `STUN_TURN.md` in the project root.
- Clips are recorded on the viewer from the decoded video, so they are re-encoded at the chosen quality.
- No motion detection and no continuous recording on a server: oCamera is for live viewing.
- Android only. Phone-camera mode relies on Android's foreground services and hardware encoders.

## Build the app

You need the Flutter SDK and an Android device.

```bash
flutter pub get
flutter run            # debug
flutter run --release  # release (what to use to measure battery)
```

The app uses a local copy of `flutter_webrtc` (in `third_party/flutter_webrtc`) that adds a configurable
recording bitrate; see `third_party/flutter_webrtc/OCAMERA_PATCH.md`.

## Documentation

- `MQTT_PROTOCOL.md` (project root): the signaling protocol (version 1) and the Mosquitto setup
- `STUN_TURN.md` (project root): STUN and TURN servers
- [oCameraAgent](https://github.com/madagaga/oCameraAgent): the camera-side agent for RTSP cameras

## Contributing

Contributions are welcome. Open an issue or a pull request.

## License

MIT. See the [LICENSE](LICENSE) file.

## Contact

Questions and suggestions: [GitHub Issues](https://github.com/madagaga/oCamera/issues).
