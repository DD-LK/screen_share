import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/io.dart';

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
  final _serverIpController = TextEditingController();
  IOWebSocketChannel? _channel;
  bool _isSharing = false;
  GlobalKey _globalKey = GlobalKey();
  Timer? _timer;

  Future<void> _startSharing() async {
    if (await _requestPermissions()) {
      _channel = IOWebSocketChannel.connect('ws://${_serverIpController.text}:8080');
      setState(() {
        _isSharing = true;
      });
      _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
        _captureAndSend();
      });
    }
  }

  void _stopSharing() {
    _timer?.cancel();
    _channel?.sink.close();
    setState(() {
      _isSharing = false;
    });
  }

  Future<void> _captureAndSend() async {
    try {
      RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      img.Image? decodedImage = img.decodeImage(pngBytes);
      List<int> jpegBytes = img.encodeJpg(decodedImage!);
      _channel?.sink.add(base64Encode(jpegBytes));
    } catch (e) {
      print(e);
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
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _globalKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Screen Sharing'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (!_isSharing)
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
      ),
    );
  }
}
