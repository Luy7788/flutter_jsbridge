# webview_jsbridge

一款与 [webview_flutter](https://github.com/flutter/plugins/tree/master/packages/webview_flutter/webview_flutter) 兼容的 jsbridge 插件，没有 native 依赖。

完全兼容 Android [JsBridge](https://github.com/lzyzsd/JsBridge) 和 iOS [WebViewJavascriptBridge](https://github.com/marcuswestin/WebViewJavascriptBridge)。

## 使用

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

### 默认实现

默认的 js 实现为 es5 版本，使用该版本现有的 web 端实现无需做调整。

### async 版本

如果 web 端正在使用 es7，那么这里也提供了一个 **async** 的实现，只需要在 `injectJs` 时选择 es7 版本即可，如下所示。

dart 端

```dart
jsBridge.injectJs(esVersion: WebViewInjectJsVersion.es7);
```

js 端

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