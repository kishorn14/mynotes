// lib/views/register_view.dart
// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mynotesapp/services/auth/bloc/auth_bloc.dart';
import 'package:mynotesapp/services/auth/bloc/auth_event.dart';
import 'package:mynotesapp/services/auth/bloc/auth_state.dart';
import 'package:mynotesapp/utilities/dialogs/error_dialog.dart';
import 'package:mynotesapp/views/verify_email_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _isLoading = false;

  @override
  void initState() {
    _email = TextEditingController();
    _password = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _register() {
    final email = _email.text.trim();
    final password = _password.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showErrorDialog(context, 'Please enter both email and password.');
      return;
    }

    setState(() => _isLoading = true);

    context.read<AuthBloc>().add(
          AuthEventRegister(email: email, password: password),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        // 🔥 Handle registration exceptions
        if (state is AuthStateRegistering && state.exception != null) {
          setState(() => _isLoading = false);
          final error = state.exception.toString();

          if (error.contains('email-already-in-use')) {
            await showErrorDialog(context, 'This email is already registered.');
          } else if (error.contains('invalid-email')) {
            await showErrorDialog(context, 'Invalid email format.');
          } else if (error.contains('weak-password')) {
            await showErrorDialog(context, 'Password is too weak (min 6 chars).');
          } else {
            await showErrorDialog(context, 'Registration failed. Please try again.');
          }
        }

        // ✅ When registration succeeds → go to verify email view
        if (state is AuthStateNeedsVerification) {
          setState(() => _isLoading = false);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const VerifyEmailView()),
          );
        }

        // ✅ In case user is already logged in
        if (state is AuthStateLoggedIn) {
          setState(() => _isLoading = false);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Create Account')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),

                // ✅ Disable button while loading
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Register'),
                ),

                const SizedBox(height: 20),

                // ✅ Go back to login
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          context.read<AuthBloc>().add(const AuthEventLogOut());
                        },
                  child: const Text('Already have an account? Login here.'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
