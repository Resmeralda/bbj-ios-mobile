import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _emailSent = true;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Unable to send password reset email.';

      if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: _emailSent
                  ? _buildSuccessMessage()
                  : _buildResetForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResetForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.lock_reset,
            size: 64,
            color: AppColors.home,
          ),
          const SizedBox(height: 16),
          const Text(
            'Forgot Password?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your email and we\'ll send you a link to reset your password.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }

              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }

              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _isLoading ? null : _resetPassword,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.home,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Send Reset Link',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              context.go('/login');
            },
            child: const Text('Back to Log In'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: AppColors.home,
        ),
        const SizedBox(height: 16),
        const Text(
          'Check Your Email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'A password reset link was sent to\n${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: () {
              context.go('/login');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.home,
            ),
            child: const Text('Back to Log In'),
          ),
        ),
      ],
    );
  }
}