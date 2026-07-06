import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sign in / create account screen.
///
/// Email+password works against Supabase Auth directly. Google and Apple use
/// the Supabase OAuth redirect flow — on web the page navigates away and the
/// session is picked up from the URL when the app reloads.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

/// Flip to true once the Google/Apple providers are enabled in the
/// Supabase dashboard (Authentication -> Sign In/Providers).
const bool _showOAuthProviders = false;

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isSignUp = false;
  bool _busy = false;
  String? _infoMessage;

  SupabaseClient get _auth => Supabase.instance.client;

  /// Where OAuth providers send the browser back to. On GitHub Pages this is
  /// https://prithvisudin.github.io/pulse-flutter/ — it must be listed under
  /// Auth -> URL Configuration -> Redirect URLs in the Supabase dashboard.
  String? get _oauthRedirect =>
      kIsWeb ? Uri.base.origin + Uri.base.path : null;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _submitEmailPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _infoMessage = null;
    });
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    try {
      if (_isSignUp) {
        final res = await _auth.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: _oauthRedirect,
        );
        if (!mounted) return;
        if (res.session == null) {
          // Email confirmation is enabled — no session until they confirm.
          setState(() {
            _busy = false;
            _infoMessage =
                'Almost there! Check $email for a confirmation link, then come back and sign in.';
            _isSignUp = false;
          });
          return;
        }
        Navigator.pop(context);
      } else {
        await _auth.auth.signInWithPassword(email: email, password: password);
        if (!mounted) return;
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      setState(() => _busy = false);
      _showError(e.message);
    } catch (e) {
      setState(() => _busy = false);
      _showError('Something went wrong: $e');
    }
  }

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    setState(() => _busy = true);
    try {
      await _auth.auth.signInWithOAuth(provider, redirectTo: _oauthRedirect);
      // On web the browser navigates away here; nothing more to do.
    } on AuthException catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e.message);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError('Could not start sign-in: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(title: Text(_isSignUp ? 'Create Account' : 'Sign In')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child:
                            const Icon(Icons.bolt, size: 38, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isSignUp ? 'Join Pulse' : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isSignUp
                          ? 'Your workouts, nutrition and progress — saved to your account.'
                          : 'Sign in to pick up where you left off.',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Color(0xFF8B8B9E), fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    if (_infoMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A0A2E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF2D1B60)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mark_email_read_outlined,
                                color: Color(0xFFA78BFA)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _infoMessage!,
                                style: const TextStyle(
                                    color: Color(0xFFCCCCDD), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    TextFormField(
                      controller: _emailCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Required';
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
                      onFieldSubmitted: (_) =>
                          _busy ? null : _submitEmailPassword(),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (_isSignUp && v.length < 6) {
                          return 'At least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Primary CTA
                    SizedBox(
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed: _busy ? null : _submitEmailPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white),
                                )
                              : Text(
                                  _isSignUp ? 'Create Account' : 'Sign In',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _infoMessage = null;
                              }),
                      child: Text(
                        _isSignUp
                            ? 'Already have an account?  Sign in'
                            : "Don't have an account?  Sign up",
                        style: const TextStyle(color: Color(0xFFA78BFA)),
                      ),
                    ),
                    if (_showOAuthProviders) ...[
                      const SizedBox(height: 16),
                      // Divider
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xFF2D2D3D))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or continue with',
                                style: TextStyle(
                                    color: Color(0xFF5A5A6E), fontSize: 12)),
                          ),
                          Expanded(child: Divider(color: Color(0xFF2D2D3D))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ProviderButton(
                        label: 'Continue with Google',
                        glyph: 'G',
                        glyphColor: const Color(0xFF4285F4),
                        onTap: _busy
                            ? null
                            : () => _signInWithProvider(OAuthProvider.google),
                      ),
                      const SizedBox(height: 12),
                      _ProviderButton(
                        label: 'Continue with Apple',
                        icon: Icons.apple,
                        onTap: _busy
                            ? null
                            : () => _signInWithProvider(OAuthProvider.apple),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final String? glyph;
  final Color? glyphColor;
  final IconData? icon;
  final VoidCallback? onTap;

  const _ProviderButton({
    required this.label,
    this.glyph,
    this.glyphColor,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF13131A),
          side: const BorderSide(color: Color(0xFF2D2D3D)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, color: Colors.white, size: 22)
            else if (glyph != null)
              Text(
                glyph!,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: glyphColor ?? Colors.white,
                ),
              ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
