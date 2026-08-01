import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/app_atmosphere.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _emailFocus = FocusNode();
  bool _signUp = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !BxLayout.isCompact(context)) {
        _emailFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (_signUp) {
        await AuthService.instance.signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
        if (AuthService.instance.isSignedIn) {
          if (mounted) Navigator.of(context).pop(true);
        } else {
          setState(() {
            _info =
                'Account created. Check your email to confirm, then sign in.';
            _signUp = false;
          });
        }
      } else {
        await AuthService.instance.signIn(
          email: _email.text,
          password: _password.text,
        );
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('AuthException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _signUp = !_signUp;
      _error = null;
      _info = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final desktop = !BxLayout.isCompact(context);

    return Scaffold(
      body: AtmosphereBackground(
        child: SafeArea(
          child: desktop ? _buildDesktop() : _buildCompact(),
        ),
      ),
    );
  }

  Widget _buildCompact() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const SizedBox(height: 12),
        const BrandMark(size: 38),
        const SizedBox(height: 14),
        ..._headlineBlock(compact: true),
        const SizedBox(height: 32),
        ..._formFields(),
        const SizedBox(height: 28),
        ..._actions(),
      ],
    );
  }

  Widget _buildDesktop() {
    return Stack(
      children: [
        Positioned(
          top: 8,
          left: 12,
          child: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 640),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: _brandPanel()),
                  const SizedBox(width: 48),
                  Expanded(
                    flex: 4,
                    child: Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ..._headlineBlock(compact: false),
                              const SizedBox(height: 28),
                              ..._formFields(),
                              const SizedBox(height: 24),
                              ..._actions(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _brandPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const BrandMark(size: 48),
        const SizedBox(height: 28),
        Text.rich(
          TextSpan(
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 40,
                  height: 1.15,
                ),
            children: [
              const TextSpan(text: 'Scripture,\nclarity, and '),
              TextSpan(
                text: 'wisdom.',
                style: GoogleFonts.instrumentSerif(
                  color: Bx.grove,
                  fontStyle: FontStyle.italic,
                  fontSize: 42,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Sign in to sync reading progress, highlights,\nnotes, and AI chats across every device.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Bx.muted,
                height: 1.5,
              ),
        ),
      ],
    );
  }

  List<Widget> _headlineBlock({required bool compact}) {
    return [
      Text(
        _signUp ? 'Create your account' : 'Welcome back',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: compact ? null : 28,
            ),
      ),
      const SizedBox(height: 8),
      Text(
        compact
            ? 'Sync reading progress, highlights, and AI chats across devices.'
            : (_signUp
                ? 'A few details and you’re ready to sync.'
                : 'Continue where you left off.'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Bx.muted,
            ),
      ),
    ];
  }

  List<Widget> _formFields() {
    return [
      if (_signUp) ...[
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Display name',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
      ],
      TextField(
        controller: _email,
        focusNode: _emailFocus,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.mail_outline_rounded),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        obscureText: _obscure,
        textInputAction: TextInputAction.done,
        autofillHints: [
          _signUp ? AutofillHints.newPassword : AutofillHints.password,
        ],
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      if (_info != null) ...[
        const SizedBox(height: 12),
        Text(_info!, style: const TextStyle(color: Bx.grove)),
      ],
    ];
  }

  List<Widget> _actions() {
    return [
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(_signUp ? 'Create account' : 'Sign in'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy ? null : _toggleMode,
        child: Text(
          _signUp
              ? 'Already have an account? Sign in'
              : 'Need an account? Create one',
        ),
      ),
    ];
  }
}
