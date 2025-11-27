import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as FirebaseAuth;
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/pages/auth_welcome_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuthManager _authManager = FirebaseAuthManager();
  FirebaseAuth.User? _currentUser;
  StreamSubscription<FirebaseAuth.User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _currentUser = _authManager.currentUser;
    
    // Listen to auth state changes
    _authSub = _authManager.authStateChanges.listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        
        if (user == null) {
          // User signed out, navigate back to auth
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthWelcomePage()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    await _authManager.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Therapii'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.healing,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to Therapii!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_currentUser != null) ...[
                Text(
                  'Hello, ${_currentUser!.email}!',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'User ID: ${_currentUser!.uid}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎉 Firebase Integration Complete!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('• Firebase Authentication ✓'),
                      Text('• Cloud Firestore Database ✓'),
                      Text('• User Management ✓'),
                      Text('• Security Rules ✓'),
                      SizedBox(height: 8),
                      Text(
                        'Your app is now connected to Firebase and ready for production use!',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}