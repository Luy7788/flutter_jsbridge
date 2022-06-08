library webview_jsbridge;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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
          name: 'HXFlutterJSBridgeChannel',
          onMessageReceived: _onMessageReceived,
        ),
      };

  Future<void> injectJs({WebViewInjectJsVersion esVersion = WebViewInjectJsVersion.es5}) async {
    final jsVersion = esVersion == WebViewInjectJsVersion.es5 ? 'default' : 'async';
    final jsPath = 'packages/webview_jsbridge/assets/$jsVersion.js';
    final jsFile = await rootBundle.loadString(jsPath);
    controller?.evaluateJavascript(jsFile);
    debugPrint('JsBridge初始化方法 injectJs');
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
        _jsCall(jsonData);
        break;
      case 'response':
      case 'error':
        _nativeCallResponse(jsonData);
        break;
      default:
        break;
    }
  }

  Future<void> _jsCall(Map<String, dynamic> jsonData) async {
    if (jsonData.containsKey('handlerName')) {
      final String handlerName = jsonData['handlerName'];
      if (_handlers.containsKey(handlerName)) {
        final data = await _handlers[handlerName]?.call(jsonData['data']);
        _jsCallResponse(jsonData, data);
      } else {
        _jsCallError(jsonData);
      }
    } else {
      if (defaultHandler != null) {
        final data = await defaultHandler?.call(jsonData['data']);
        _jsCallResponse(jsonData, data);
      } else {
        _jsCallError(jsonData);
      }
    }
  }

  void _jsCallResponse(Map<String, dynamic> jsonData, Object? data) {
    jsonData['type'] = 'response';
    jsonData['data'] = data;
    _evaluateJavascript(jsonData);
  }

  void _jsCallError(Map<String, dynamic> jsonData) {
    jsonData['type'] = 'error';
    _evaluateJavascript(jsonData);
  }

  Future<T?> callHandler<T extends Object?>(String handlerName,
      {Object? data}) async {
    return _nativeCall<T>(handlerName: handlerName, data: data);
  }

  Future<T?> send<T extends Object?>(Object data) async {
    return _nativeCall<T>(data: data);
  }

  Future<T?> _nativeCall<T extends Object?>(
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

  void _nativeCallResponse(Map<String, dynamic> jsonData) {
    final int index = jsonData['index'];
    final completer = _completers[index];
    _completers.remove(index);
    if (jsonData['type'] == 'response') {
      completer?.complete(jsonData['data']);
    } else {
      completer?.completeError('native call js error for request $jsonData');
    }
  }

  void _evaluateJavascript(Map<String, dynamic> jsonData) {
    final jsonStr = jsonEncode(jsonData);
    final encodeStr = Uri.encodeFull(jsonStr);
    final script = 'flutterJsBridge.nativeCall("$encodeStr")';
    controller?.evaluateJavascript(script);
  }

  //检查flutterJsBridge方法
  Future<bool> checkJsBridge() async {
    final script = '(function () { if(window.flutterJsBridge == null) {return false;} else {return true;} })();';
    var result = await controller?.evaluateJavascript(script);
    // debugPrint('checkJsBridge 是否初始化 $result: ${result == "true" || result == "1"}');
    return (result == "true" || result == "1") ? true : false;
  }
}
