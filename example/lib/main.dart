import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mehery_sender/mehery_sender.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first
  try {
    await Firebase.initializeApp();
    print('Firebase Initialized');
  } catch (e) {
    print('Error initializing Firebase: $e');
    return;  // Stop if Firebase initialization fails
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MeSend _tokenSender = MeSend( // Replace with your server URL
    companyId : 'MeheryTestFlutter_1734160381705'
  );

  @override
  void initState() {
    super.initState();
    // Wait until Firebase is initialized and then send the token
    _initializeTokenSender();
  }

  // Ensure initialization happens after Firebase is initialized
  Future<void> _initializeTokenSender() async {
    // Only initialize the token sender after Firebase has been initialized
    await _tokenSender.initializeAndSendToken();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Token Sender Example')),
      body:  Center(
        child: Column(
          children: [
            const Text(
              'Token has been sent to the server.',
              textAlign: TextAlign.center,
            ),
            ElevatedButton(onPressed: (){
              _tokenSender.login("ABCD");
            }, child: const Text("Login")),
            ElevatedButton(onPressed: (){
              _tokenSender.logout("ABCD");
            }, child: const Text("Logout"))
          ],
        ),
      ),
    );
  }
}
