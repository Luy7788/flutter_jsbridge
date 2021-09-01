import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:local_assets_server/local_assets_server.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:webview_jsbridge/webview_jsbridge.dart';

class WebViewFlutterPluginPage extends StatefulWidget {
  final String title;
  WebViewFlutterPluginPage(this.title) : super();

  @override
  _WebViewFlutterPluginPageState createState() =>
      _WebViewFlutterPluginPageState();
}

class _WebViewFlutterPluginPageState extends State<WebViewFlutterPluginPage> {
  final _jsBridge = WebViewJSBridge();
  final _flutterWebviewPlugin = FlutterWebviewPlugin();

  bool isListening = false;
  String? address;
  int? port;

  @override
  void initState() {
    _initServer();
    _initJsBridge();
    _initPlugin();
    super.initState();
  }

  @override
  void dispose() {
    _flutterWebviewPlugin.dispose();
    super.dispose();
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
    if (!isListening) {
      return Center(child: CircularProgressIndicator());
    }
    return Row(
      children: [
        Expanded(
          child: _buildWebView(),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
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
        ),
      ],
    );
  }

  WebviewScaffold _buildWebView() {
    final isEs5 = widget.title == 'es5';
    final htmlVersion = isEs5 ? 'default' : 'async';
    final channels = <JavascriptChannel>{
      JavascriptChannel(
        name: 'YGFlutterJSBridgeChannel',
        onMessageReceived: _onMessageReceived,
      ),
    };
    return WebviewScaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      javascriptChannels: channels,
      url: 'http://$address:$port/$htmlVersion.html',
    );
  }

  void _initJsBridge() {
    _jsBridge.jsHandler = (javascriptString) =>
        _flutterWebviewPlugin.evalJavascript(javascriptString);
    _jsBridge.defaultHandler = _defaultHandler;
    _jsBridge.registerHandler("NativeEcho", _nativeEchoHandler);
  }

  void _initPlugin() {
    final isEs5 = widget.title == 'es5';
    final jsVersion =
        isEs5 ? WebViewInjectJsVersion.es5 : WebViewInjectJsVersion.es7;
    _flutterWebviewPlugin.onUrlChanged.listen((url) {
      if (url.contains('__bridge_loaded__')) {
        _jsBridge.injectJs(esVersion: jsVersion);
      }
    });
    _flutterWebviewPlugin.onStateChanged.listen((state) {
      if (state.type == WebViewState.finishLoad) {
        _jsBridge.injectJs(esVersion: jsVersion);
      }
    });
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
