// lib/views/verify_email_view.dart
// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mynotesapp/services/auth/bloc/auth_bloc.dart';
import 'package:mynotesapp/services/auth/bloc/auth_event.dart';
import 'package:mynotesapp/services/auth/bloc/auth_state.dart';
import 'package:mynotesapp/views/login_view.dart';

class VerifyEmailView extends StatelessWidget {
  const VerifyEmailView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthStateLoggedOut) {
          // ✅ Return to LoginView when logged out
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginView()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Verify Your Email')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_read, size: 70, color: Colors.blueAccent),
              const SizedBox(height: 20),
              const Text(
                'We’ve sent a verification email to your inbox.\n\n'
                'Please check your email and verify your account before logging in.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 40),

              // ✅ Button: Resend verification
              ElevatedButton.icon(
                onPressed: () {
                  context.read<AuthBloc>().add(const AuthEventSendEmailVerification());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification email resent!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.email),
                label: const Text('Resend Verification Email'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 20),

              // ✅ Button: Restart (recheck verification)
              ElevatedButton.icon(
                onPressed: () {
                  // 🔄 Tell Bloc to reinitialize and reload the user
                  context.read<AuthBloc>().add(const AuthEventInitialize());
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Restart / I Verified My Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 20),

              // ✅ Button: Back to Login
              ElevatedButton.icon(
                onPressed: () {
                  context.read<AuthBloc>().add(const AuthEventLogOut());
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
