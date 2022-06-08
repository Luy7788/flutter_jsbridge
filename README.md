# webview_jsbridge

[中文文档](https://github.com/KouYiGuo/webview_jsbridge/blob/main/doc/README.zh_CN.md)

A flutter jsbridge package compatible with [webview_flutter](https://github.com/flutter/plugins/tree/master/packages/webview_flutter/webview_flutter), no native dependence.

Full compatible with Android [JsBridge](https://github.com/lzyzsd/JsBridge) and iOS [WebViewJavascriptBridge](https://github.com/marcuswestin/WebViewJavascriptBridge).

## Usage

```dart
  WebView _buildWebView() {
    return WebView(
      javascriptChannels: jsBridge.jsChannels,
      // must enable js
      javascriptMode: JavascriptMode.unrestricted,
      onWebViewCreated: (controller) {
        jsBridge.controller = controller;
        jsBridge.defaultHandler = _defaultHandler;
        jsBridge.registerHandler("NativeEcho", _nativeEchoHandler);
      },
      navigationDelegate: (NavigationRequest navigation) {
        // this is no effect on Android
        if (navigation.url.contains('__bridge_loaded__')) {
          jsBridge.injectJs();
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
      onPageFinished: (String url) {
        jsBridge.injectJs();
      },
      initialUrl: 'https://example.com',
    );
  }

  Future<void> _send() async {
    final res = await jsBridge.send('send from native');
    print('_send res: $res');
  }

  Future<void> _callJs() async {
    final res =
        await jsBridge.callHandler('JSEcho', data: 'callJs from native');
    print('callJs res: $res');
  }

  Future<Object?> _defaultHandler(Object? data) async {
    await Future.delayed(Duration(seconds: 1), () {});
    return '_defaultHandler from native';
  }

  Future<Object?> _nativeEchoHandler(Object? data) async {
    await Future.delayed(Duration(seconds: 1), () {});
    return '_nativeEchoHandler from native';
  }
```

### default js implementation

Default js implementation is es5 version. Using this version, web client has no need to change anything.

### async js implementation

If web client is using es7, here is a **async** implementation. You just need choose es7 version to inject. Like this:

dart client

```dart
jsBridge.injectJs(esVersion: WebViewInjectJsVersion.es7);
```

js client

```js
setupWebViewJavascriptBridge(function (bridge) {
    console.log('setupWebViewJavascriptBridge done');
    async function defaultHandler(message) {
        console.log('defaultHandler JS got a message', message);
        return new Promise(resolve => {
            let data = {
                'Javascript Responds': 'defaultHandler Wee!'
            };
            console.log('defaultHandler JS responding with', data);
            setTimeout(() => resolve(data), 0);
        });
    }

    bridge.init(defaultHandler);

    async function JSEcho(data) {
        console.log("JS Echo called with:", data);
        return new Promise(resolve => setTimeout(() => resolve(data), 0));
    }

    bridge.registerHandler('JSEcho', JSEcho);
});

async function sendHello() {
    let responseData = await window.WebViewJavascriptBridge.send('hello');
    console.log("repsonseData from java, data = ", responseData);
}

async function callHandler() {
    let responseData = await window.WebViewJavascriptBridge.callHandler('NativeEcho', { 'key': 'value' });
    console.log("JS received response:", responseData);
}
```
