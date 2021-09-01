import 'package:example/flutter_webview_plugin.dart';
import 'package:example/webview_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeView(),
    );
  }
}

class HomeView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: Column(
        children: [
          TextButton(
            child: Text(
              'WebViewFlutter',
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => WebViewFlutterPage('es5'),
              ),
            ),
          ),
          TextButton(
            child: Text(
              'WebViewFlutterPluginPage es5',
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => WebViewFlutterPluginPage('es5'),
              ),
            ),
          ),
          TextButton(
            child: Text(
              'WebViewFlutterPluginPage es7',
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => WebViewFlutterPluginPage('es7'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
