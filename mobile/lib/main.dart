import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uni_links/uni_links.dart';

void main() {
  runApp(const MyApp());
}

class AuthResBody {
  final String ticket;
  AuthResBody(this.ticket);

  AuthResBody.fromJson(Map<String, dynamic> json) : ticket = json['ticket'];

  Map<String, dynamic> toJson() => {
        'ticket': ticket,
      };
}

class ConsentResBody {
  final String redirectTo;
  ConsentResBody(this.redirectTo);

  ConsentResBody.fromJson(Map<String, dynamic> json)
      : redirectTo = json['redirect_to'];

  Map<String, dynamic> toJson() => {
        'redirect_to': redirectTo,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A2A Demo with Authlete',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Demo PayApp'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  // Query params
  String? clientId;
  String? responseType;
  String? redirectUri;
  String? scope;
  String? state;
  String? codeChallenge;
  String? codeChallengeMethod;

  // Server response
  String? ticket;

  // Mobile inputs
  int? memberId;
  String? authCode;
  final myController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    initUniLinks();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      initUniLinks();
    }
  }

  Future<void> initUniLinks() async {
    linkStream.listen((String? link) {
      getQueryParameters(link);
    }, onError: (err) {
      print(err);
    });
    handleFetchTicket();
  }

  void getQueryParameters(String? link) {
    if (link == null) return;
    final uri = Uri.parse(link);
    setState(() {
      clientId = uri.queryParameters['client_id'];
      responseType = uri.queryParameters['response_type'];
      redirectUri = uri.queryParameters['redirect_uri'];
      scope = uri.queryParameters['scope'];
      state = uri.queryParameters['state'];
      codeChallenge = uri.queryParameters['code_challenge'];
      codeChallengeMethod = uri.queryParameters['code_challenge_method'];
    });
  }

  // call auth api
  Future<void> handleFetchTicket() async {
    if (clientId == null) return;
    Uri uri = Uri(scheme: 'http', host: 'localhost', port: 8888, path: '/auth');
    Map<String, String> headers = {'Content-Type': 'application/json'};
    String reqBody = json.encode({
      'client_id': clientId,
      'response_type': responseType,
      'redirect_uri': redirectUri,
      'scope': scope,
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': codeChallengeMethod
    });
    http.Response res = await http.post(uri, headers: headers, body: reqBody);

    if (res.statusCode == 200) {
      var respBody = AuthResBody.fromJson(json.decode(res.body));
      setState(() {
        memberId = null;
        ticket = respBody.ticket;
      });
    }
  }

  /// Dummy login. This function only sets memberId.
  void handleDummyLogin() {
    setState(() {
      memberId = int.parse(myController.text);
    });
  }

  /// Consent
  Future<void> handleConsent() async {
    Uri uri =
        Uri(scheme: 'http', host: 'localhost', port: 8888, path: '/consent');
    Map<String, String> headers = {'content-type': 'application/json'};
    String reqBody = json.encode({
      'ticket': ticket,
      'member_id': memberId,
    });

    http.Response res = await http.post(uri, headers: headers, body: reqBody);
    if (res.statusCode == 200) {
      var respBody = ConsentResBody.fromJson(json.decode(res.body));
      await launchUrl(Uri.parse(respBody.redirectTo),
          mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Login
            if (ticket != null && memberId == null)
              Column(
                children: [
                  const Text('Dummy Login screen'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 250.0,
                        child: TextField(
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'MemberId'),
                            controller: myController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ]),
                      ),
                      OutlinedButton(
                          onPressed: handleDummyLogin,
                          child: const Text('Login')),
                    ],
                  ),
                ],
              ),
            // Consent
            if (memberId != null)
              Column(
                children: [
                  Text('MemberID: $memberId'),
                  OutlinedButton(
                      onPressed: handleConsent, child: const Text('Consent')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
