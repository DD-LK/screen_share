import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isSharing = false;
  RTCPeerConnection? _peerConnection;
  final _localRenderer = RTCVideoRenderer();
  final _serverIpController = TextEditingController();
  IOWebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    super.dispose();
  }

  Future<void> _startSharing() async {
    if (await _requestPermissions()) {
      final mediaConstraints = <String, dynamic>{
        'audio': false,
        'video': {
          'mandatory': {
            'minWidth': '1280',
            'minHeight': '720',
            'minFrameRate': '30',
          },
          'facingMode': 'user',
          'optional': [],
        }
      };

      try {
        var stream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
        _localRenderer.srcObject = stream;

        _peerConnection = await createPeerConnection({
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'},
          ]
        }, {});

        stream.getTracks().forEach((track) {
          _peerConnection?.addTrack(track, stream);
        });

        _channel = IOWebSocketChannel.connect('ws://${_serverIpController.text}:8080');

        _peerConnection?.onIceCandidate = (candidate) {
          if (candidate != null) {
            _channel?.sink.add(jsonEncode({
              'type': 'candidate',
              'candidate': candidate.toMap(),
            }));
          }
        };

        var offer = await _peerConnection?.createOffer({});
        await _peerConnection?.setLocalDescription(offer!);
        _channel?.sink.add(jsonEncode(offer?.toMap()));

        _channel?.stream.listen((message) {
          final data = jsonDecode(message);
          if (data['type'] == 'answer') {
            _peerConnection?.setRemoteDescription(
              RTCSessionDescription(data['sdp'], data['type']),
            );
          } else if (data['type'] == 'candidate') {
            _peerConnection?.addIceCandidate(
              RTCIceCandidate(
                data['candidate']['candidate'],
                data['candidate']['sdpMid'],
                data['candidate']['sdpMLineIndex'],
              ),
            );
          }
        });

        setState(() {
          _isSharing = true;
        });
      } catch (e) {
        print(e.toString());
      }
    }
  }

  void _stopSharing() {
    try {
      _channel?.sink.close();
      _peerConnection?.close();
      _peerConnection = null;
      _localRenderer.srcObject = null;
      setState(() {
        _isSharing = false;
      });
    } catch (e) {
      print(e.toString());
    }
  }

  Future<bool> _requestPermissions() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        return false;
      }
    }
    status = await Permission.systemAlertWindow.status;
    if (!status.isGranted) {
      status = await Permission.systemAlertWindow.request();
      if (!status.isGranted) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Screen Sharing'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_isSharing)
              Expanded(child: RTCVideoView(_localRenderer))
            else
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _serverIpController,
                  decoration: InputDecoration(
                    labelText: 'Server IP Address',
                  ),
                ),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSharing ? _stopSharing : _startSharing,
              child: Text(_isSharing ? 'Stop Sharing' : 'Start Sharing'),
            ),
          ],
        ),
      ),
    );
  }
}
