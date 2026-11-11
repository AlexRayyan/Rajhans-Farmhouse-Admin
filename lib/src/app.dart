import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'screens.dart';

class RajhansApp extends StatefulWidget {
  const RajhansApp({super.key, required this.firebaseReady, this.setupError});
  final bool firebaseReady;
  final String? setupError;
  @override
  State<RajhansApp> createState() => _RajhansAppState();
}

class _RajhansAppState extends State<RajhansApp> {
  ThemeMode themeMode = ThemeMode.system;
  @override
  Widget build(BuildContext context) {
    ThemeData makeTheme(Brightness brightness) {
      final dark = brightness == Brightness.dark;
      return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        scaffoldBackgroundColor: dark ? const Color(0xFF101525) : const Color(0xFFF5F6FB),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6655F5), brightness: brightness),
        cardTheme: CardThemeData(color: dark ? const Color(0xFF192139) : Colors.white),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent),
      );
    }
    return MaterialApp(
      title: 'Rajhans Farmhouse',
      debugShowCheckedModeBanner: false,
      theme: makeTheme(Brightness.light),
      darkTheme: makeTheme(Brightness.dark),
      themeMode: themeMode,
      home: !widget.firebaseReady
          ? Scaffold(body: Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Firebase setup required. See README.md.\n${widget.setupError ?? ""}', textAlign: TextAlign.center),
            )))
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.data == null) return const _LoginScreen();
                return _AdminGate(
                  uid: snapshot.data!.uid,
                  onThemeChanged: (value) => setState(() => themeMode = value),
                  themeMode: themeMode,
                );
              },
            ),
    );
  }
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen();
  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  bool busy = false;
  String? error;
  Future<void> signIn() async {
    setState(() { busy = true; error = null; });
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
      );
      final account = await GoogleSignIn.instance.authenticate();
      final authentication = account.authentication;
      final credential = GoogleAuthProvider.credential(idToken: authentication.idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      if (mounted) setState(() => error = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.villa_outlined, size: 64),
        const SizedBox(height: 18),
        Text('Rajhans Farmhouse', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Private admin access'),
        const SizedBox(height: 28),
        FilledButton.icon(onPressed: busy ? null : signIn, icon: const Icon(Icons.login), label: const Text('Continue with Google')),
        if (busy) const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
        if (error != null) Text(error!, textAlign: TextAlign.center),
      ]),
    ))),
  );
}

class _AdminGate extends StatelessWidget {
  const _AdminGate({required this.uid, required this.onThemeChanged, required this.themeMode});
  final String uid;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ThemeMode themeMode;
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('admins').doc(uid).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return const Scaffold(body: Center(child: Text('Unable to verify administrator access')));
      if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (snapshot.data!.data()?['active'] != true) {
        return Scaffold(body: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Access denied. Contact the property owner.'),
            TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Sign out')),
          ],
        )));
      }
      return AdminHome(themeMode: themeMode, onThemeChanged: onThemeChanged);
    },
  );
}
