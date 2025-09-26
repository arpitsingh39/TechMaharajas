// lib/authentication/login page.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../main.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  bool _loading = false;
  final _shop = TextEditingController();
  final _pass = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.store, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text('Welcome Back', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _shop,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.storefront), labelText: 'Shop Name'),
                    validator: (v) => v!.isEmpty ? 'Enter shop name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.lock), labelText: 'Password'),
                    validator: (v) => v!.isEmpty ? 'Enter password' : null,
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _loading
                        ? Lottie.asset('assets/loader.json', width: 80, repeat: true)
                        : SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () async {
                                if (!_form.currentState!.validate()) return;
                                setState(() => _loading = true);
                                await Future.delayed(const Duration(milliseconds: 800));
                                AppState.of(context).signIn();
                                if (context.mounted) context.go('/dashboard');
                              },
                              child: const Text('Login'),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/signin'),
                    child: const Text('Create account'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
