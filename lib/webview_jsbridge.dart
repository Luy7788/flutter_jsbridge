library webview_jsbridge;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef Future<T?> WebViewJSBridgeHandler<T extends Object?>(Object? data);

enum WebViewInjectJsVersion { es5, es7 }

class WebViewJSBridge {
  WebViewController? controller;

  final _completers = <int, Completer>{};
  var _completerIndex = 0;
  final _handlers = <String, WebViewJSBridgeHandler>{};
  WebViewJSBridgeHandler? defaultHandler;

  Set<JavascriptChannel> get jsChannels => <JavascriptChannel>{
        JavascriptChannel(
          name: 'YGFlutterJSBridgeChannel',
          onMessageReceived: _onMessageReceived,
        ),
      };

  Future<void> injectJs(
      {WebViewInjectJsVersion esVersion = WebViewInjectJsVersion.es5}) async {
    final jsVersion =
        esVersion == WebViewInjectJsVersion.es5 ? 'default' : 'async';
    final jsPath = 'packages/webview_jsbridge/assets/$jsVersion.js';
    final jsFile = await rootBundle.loadString(jsPath);
    controller?.evaluateJavascript(jsFile);
  }

  void registerHandler(String handlerName, WebViewJSBridgeHandler handler) {
    _handlers[handlerName] = handler;
  }

  void removeHandler(String handlerName) {
    _handlers.remove(handlerName);
  }

  void _onMessageReceived(JavascriptMessage message) {
    final decodeStr = Uri.decodeFull(message.message);
    final jsonData = jsonDecode(decodeStr);
    final String type = jsonData['type'];
    switch (type) {
      case 'request':
        _jsCallNative(jsonData);
        break;
      case 'response':
        _callJsResponse(jsonData);
        break;
      default:
        break;
    }
  }

  Future<void> _jsCallNative(Map<String, dynamic> jsonData) async {
    Object? response;
    if (jsonData.containsKey('handlerName')) {
      final String handlerName = jsonData['handlerName'];
      response = await _handlers[handlerName]?.call(jsonData['data']);
    } else {
      response = await defaultHandler?.call(jsonData['data']);
    }

    if (response != null) {
      jsonData['data'] = response;
    }
    jsonData['type'] = 'response';

    _evaluateJavascript(jsonData);
  }

  Future<T?> callHandler<T extends Object?>(String handlerName,
      {Object? data}) async {
    final result = await _callJs<T>(handlerName: handlerName, data: data);
    return result;
  }

  Future<T?> send<T extends Object?>(Object data) async {
    final result = await _callJs<T>(data: data);
    return result;
  }

  Future<T?> _callJs<T extends Object?>(
      {String? handlerName, Object? data}) async {
    final jsonData = {
      'index': _completerIndex,
      'type': 'request',
    };
    if (data != null) {
      jsonData['data'] = data;
    }
    if (handlerName != null) {
      jsonData['handlerName'] = handlerName;
    }

    final completer = Completer<T>();
    _completers[_completerIndex] = completer;
    _completerIndex += 1;

    _evaluateJavascript(jsonData);
    return completer.future;
  }

  void _callJsResponse(Map<String, dynamic> jsonData) {
    final int index = jsonData['index'];
    final completer = _completers[index];
    _completers.remove(index);
    completer?.complete(jsonData['data']);
  }

  void _evaluateJavascript(Map<String, dynamic> jsonData) {
    final jsonStr = jsonEncode(jsonData);
    final encodeStr = Uri.encodeFull(jsonStr);
    final script = 'WebViewJavascriptBridge.nativeCall("$encodeStr")';
    controller?.evaluateJavascript(script);
  }
}
