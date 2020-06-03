import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:f_logs/f_logs.dart';
import 'package:fluttertoast/fluttertoast.dart';

Future<void> messageHandler(Map<String, dynamic> message) async {
  FLog.info(
    className: "logs",
    methodName: "message inbound",
    text: jsonEncode(message),
  );
}

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fcm-receiver',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(
        title: "Fcm receiver",
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, @required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
  final TextEditingController _tokenTextController = TextEditingController();
  final TextEditingController _topicTextController = TextEditingController();
  List<String> logList = [];

  @override
  void initState() {
    _firebaseMessaging.configure(
      onBackgroundMessage: messageHandler,
      onMessage: messageHandler,
      onLaunch: messageHandler,
      onResume: messageHandler,
    );

    getToken();
    refreshLogs();

    super.initState();
  }

  void getToken() async {
    String token = await _firebaseMessaging.getToken();
    _tokenTextController.text = token;
  }

  void refreshLogs() async {
    List<Log> logs = await FLog.getAllLogs();

    setState(() {
      logList = logs
          .map((log) =>
              "[${log.methodName}] ${DateTime.fromMillisecondsSinceEpoch(log.timeInMillis).toString()}: ${log.text}")
          .toList();
    });
    showToast("logs refreshed");
  }

  void subscribe() async {
    String topic = _topicTextController.text;
    await _firebaseMessaging.subscribeToTopic(topic);
    FLog.info(
      className: "logs",
      methodName: "subscribe",
      text: "subscribe to topic: $topic",
    );
    showToast("subscribed");
  }

  void unSubscribe() async {
    String topic = _topicTextController.text;
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    FLog.info(
      className: "logs",
      methodName: "unsubscribe",
      text: "un-subscribe to topic: $topic",
    );
    showToast("unsubscribed");
  }

  void showToast(text) async {
    Fluttertoast.showToast(
      msg: text,
      toastLength: Toast.LENGTH_SHORT,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body = Column(
      children: <Widget>[
        SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            isDense: true,
            hintText: "Token",
            border: OutlineInputBorder(),
          ),
          readOnly: true,
          controller: _tokenTextController,
        ),
        SizedBox(height: 4),
        ButtonBar(
          children: <Widget>[
            FlatButton(
              child: Text('copy token'),
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: _tokenTextController.text),
                );
                showToast("copied to clipboard");
              },
            )
          ],
        ),
        SizedBox(height: 4),
        TextField(
          decoration: InputDecoration(
            isDense: true,
            hintText: "Topic",
            border: OutlineInputBorder(),
          ),
          controller: _topicTextController,
        ),
        SizedBox(height: 4),
        ButtonBar(
          alignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            FlatButton(
              child: Text("Subscribe"),
              onPressed: subscribe,
            ),
            FlatButton(
              child: Text("Un-subscribe"),
              onPressed: unSubscribe,
            ),
            FlatButton(
              child: Text("Reset"),
              onPressed: () {
                _topicTextController.text = "";
              },
            ),
          ],
        ),
        SizedBox(height: 4),
        Expanded(
          child: ListView(
            physics: BouncingScrollPhysics(),
            children: logList.map((log) => SelectableText(log)).toList(),
          ),
        ),
        SizedBox(height: 4),
        ButtonBar(
          children: <Widget>[
            FlatButton(
              child: Text('refresh logs'),
              onPressed: refreshLogs,
            )
          ],
        ),
      ],
    );

    body = Padding(padding: EdgeInsets.only(left: 16, right: 16), child: body);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(color: Theme.of(context).textTheme.bodyText1.color),
        ),
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      body: GestureDetector(
        onTap: () {
          FocusScopeNode currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus) {
            currentFocus.unfocus();
            if (currentFocus.focusedChild != null) {
              currentFocus.focusedChild.unfocus();
            }
          }
        },
        child: body,
      ),
    );
  }
}
