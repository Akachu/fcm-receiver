import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:f_logs/f_logs.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info/package_info.dart';

Future<void> messageHandler(Map<String, dynamic> message) async {
  JsonEncoder encoder = new JsonEncoder.withIndent('  ');

  FLog.info(
    className: "FCM",
    methodName: "message inbound",
    text: encoder.convert(message),
  );
}

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fcm-receiver',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemBlue,
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
        buttonBarTheme: ButtonBarThemeData(
          buttonPadding: EdgeInsets.symmetric(vertical: 4),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: CupertinoColors.systemBlue,
        scaffoldBackgroundColor: CupertinoColors.darkBackgroundGray,
        buttonBarTheme: ButtonBarThemeData(
          buttonPadding: EdgeInsets.symmetric(vertical: 4),
        ),
      ),
      home: MyHomePage(title: "FCM Receiver"),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({
    Key key,
    @required this.title,
  }) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseMessaging fcm = FirebaseMessaging();
  final TextEditingController _tokenTextController = TextEditingController();
  final TextEditingController _topicTextController = TextEditingController();

  List<Log> _logs = [];

  String appInfoString = '';

  @override
  void initState() {
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      setState(() {
        appInfoString = "v${packageInfo.version}+${packageInfo.buildNumber}";
      });
    });

    fcm.requestNotificationPermissions();
    fcm.configure(
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
    String token = await fcm.getToken();
    _tokenTextController.text = token;
  }

  Future refreshLogs() async {
    List<Log> logs = await FLog.getAllLogs();

    setState(() {
      _logs = logs;
    });
  }

  void clearLogs() async {
    await FLog.clearLogs();
    showToast('logs cleared');
    refreshLogs();
  }

  void subscribe() async {
    String topic = _topicTextController.text;
    if (topic == "") return;
    _topicTextController.text = "";

    clearFocus();
    await fcm.subscribeToTopic(topic);
    await FLog.info(
      className: "APP",
      methodName: "subscribe",
      text: "topic: $topic",
    );

    await refreshLogs();
    showToast("subscribed");
  }

  void unsubscribe() async {
    String topic = _topicTextController.text;
    if (topic == "") return;
    _topicTextController.text = "";

    clearFocus();
    await fcm.unsubscribeFromTopic(topic);
    await FLog.info(
      className: "APP",
      methodName: "unsubscribe",
      text: "topic: $topic",
    );
    await refreshLogs();
    showToast("unsubscribed");
  }

  void showToast(text) async {
    Fluttertoast.showToast(
      msg: text,
      toastLength: Toast.LENGTH_SHORT,
      fontSize: 16.0,
    );
  }

  void clearFocus() {
    FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
      if (currentFocus.focusedChild != null) {
        currentFocus.focusedChild.unfocus();
      }
    }
  }

  Widget logItemBuilder(Log log) {
    String time =
        DateTime.fromMillisecondsSinceEpoch(log.timeInMillis).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              log.className,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 4),
            Text(
              log.methodName,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        SelectableText(log.text),
        SizedBox(height: 4),
        Text(
          time,
          style: Theme.of(context).textTheme.caption,
        )
      ],
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
            labelText: "Token",
            border: OutlineInputBorder(),
          ),
          readOnly: true,
          controller: _tokenTextController,
        ),
        ButtonBar(
          children: <Widget>[
            CupertinoButton(
              child: Text('Copy token'),
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
            labelText: "Topic",
            border: OutlineInputBorder(),
          ),
          controller: _topicTextController,
        ),
        ButtonBar(
          children: <Widget>[
            CupertinoButton(
              child: Text("Subscribe"),
              onPressed: subscribe,
            ),
            CupertinoButton(
              child: Text("Unsubscribe"),
              onPressed: unsubscribe,
            ),
          ],
        ),
        SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).disabledColor),
              borderRadius: BorderRadius.circular(5),
            ),
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ListView.separated(
              separatorBuilder: (context, index) => Divider(),
              itemCount: _logs.length,
              itemBuilder: (context, index) => logItemBuilder(_logs[index]),
              physics: BouncingScrollPhysics(),
            ),
          ),
        ),
        ButtonBar(
          children: <Widget>[
            CupertinoButton(
              child: Text('Refresh'),
              onPressed: () async {
                await refreshLogs();
                showToast("logs refreshed");
              },
            ),
            CupertinoButton(
              child: Text('Clear'),
              onPressed: clearLogs,
            ),
          ],
        ),
        Text(appInfoString, style: Theme.of(context).textTheme.caption),
        SizedBox(height: 16),
      ],
    );

    body = Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: body);

    Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return GestureDetector(
      onTap: clearFocus,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(
            widget.title,
            style:
                TextStyle(color: Theme.of(context).textTheme.bodyText1.color),
          ),
          backgroundColor: backgroundColor,
          elevation: 0,
        ),
        backgroundColor: backgroundColor,
        body: body,
      ),
    );
  }
}
