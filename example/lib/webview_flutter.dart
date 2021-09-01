import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:local_assets_server/local_assets_server.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_jsbridge/webview_jsbridge.dart';

class WebViewFlutterPage extends StatefulWidget {
  final String title;
  WebViewFlutterPage(this.title) : super();

  @override
  _WebViewFlutterPageState createState() => _WebViewFlutterPageState();
}

class _WebViewFlutterPageState extends State<WebViewFlutterPage> {
  final _jsBridge = WebViewJSBridge();

  bool isListening = false;
  String? address;
  int? port;

  @override
  initState() {
    _initServer();
    super.initState();
  }

  Future<void> _initServer() async {
    final server = LocalAssetsServer(
      address: InternetAddress.loopbackIPv4,
      assetsBasePath: 'assets/',
      logger: DebugLogger(),
    );

    final address = await server.serve();

    setState(() {
      this.address = address.address;
      port = server.boundPort!;
      isListening = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.title == 'es5')
            TextButton(
              child: Text(
                'es7',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => WebViewFlutterPage('es7'),
                ),
              ),
            ),
        ],
      ),
      body: isListening
          ? Row(
              children: [
                Expanded(
                  child: _buildWebView(),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('native'),
                      TextButton(
                        child: Text(
                          'sendHello',
                        ),
                        onPressed: () => _sendHello(),
                      ),
                      TextButton(
                        child: Text(
                          'callJSEcho',
                        ),
                        onPressed: () => _callJSEcho(),
                      ),
                      TextButton(
                        child: Text(
                          '_callNotExist',
                        ),
                        onPressed: () => _callNotExist(),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(child: CircularProgressIndicator()),
    );
  }

  WebView _buildWebView() {
    final isEs5 = widget.title == 'es5';
    final jsVersion =
        isEs5 ? WebViewInjectJsVersion.es5 : WebViewInjectJsVersion.es7;
    final htmlVersion = isEs5 ? 'default' : 'async';
    final channels = <JavascriptChannel>{
      JavascriptChannel(
        name: 'YGFlutterJSBridgeChannel',
        onMessageReceived: _onMessageReceived,
      ),
    };
    return WebView(
      javascriptChannels: channels,
      // must enable js
      javascriptMode: JavascriptMode.unrestricted,
      onWebViewCreated: (controller) {
        _jsBridge.jsHandler = (javascriptString) =>
            controller.evaluateJavascript(javascriptString);
        _jsBridge.defaultHandler = _defaultHandler;
        _jsBridge.registerHandler("NativeEcho", _nativeEchoHandler);
      },
      navigationDelegate: (NavigationRequest navigation) {
        print('navigationDelegate ${navigation.url}');
        // this is no effect on Android
        if (navigation.url.contains('__bridge_loaded__')) {
          _jsBridge.injectJs(esVersion: jsVersion);
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
      onPageFinished: (String url) {
        _jsBridge.injectJs(esVersion: jsVersion);
      },
      initialUrl: 'http://$address:$port/$htmlVersion.html',
    );
  }

  void _onMessageReceived(JavascriptMessage message) {
    _jsBridge.onMessageReceived(message.message);
  }

  Future<void> _sendHello() async {
    final res = await _jsBridge.send('hello from native');
    print('_sendHello res: $res');
  }

  Future<void> _callJSEcho() async {
    final res =
        await _jsBridge.callHandler('JSEcho', data: 'callJs from native');
    print('_callJSEcho res: $res');
  }

  Future<void> _callNotExist() async {
    final res =
        await _jsBridge.callHandler('NotExist', data: 'callJs from native');
    print('_callNotExist res: $res');
  }

  Future<Object?> _defaultHandler(Object? data) async {
    await Future.delayed(Duration(seconds: 1), () {});
    return '_defaultHandler res from native';
  }

  Future<Object?> _nativeEchoHandler(Object? data) async {
    await Future.delayed(Duration(seconds: 1), () {});
    return '_nativeEchoHandler res from native';
  }
}
