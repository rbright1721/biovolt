import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

class SignInScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  const SignInScreen({super.key, required this.onSignedIn});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AuthService().signInWithGoogle();
      if (result != null && mounted) {
        widget.onSignedIn();
      } else if (mounted) {
        setState(() {
          _error = 'Sign-in cancelled. Please try again.';
          _loading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} \u2014 ${e.message}');
      if (mounted) {
        setState(() {
          _error = 'Firebase error: ${e.code}\n${e.message}';
          _loading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Google Sign-In error: $e');
      debugPrint('Stack: $stack');
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService().signInAnonymously();
      if (mounted) widget.onSignedIn();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not continue as guest.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo / app name
              Text(
                'BIOVOLT',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: BioVoltColors.teal,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'biometric intelligence',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: BioVoltColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),

              const Spacer(flex: 2),

              _featureLine('Real-time EDA \u00B7 ECG \u00B7 PPG \u00B7 HRV'),
              const SizedBox(height: 8),
              _featureLine('Protocol-tagged session recording'),
              const SizedBox(height: 8),
              _featureLine('AI analysis with full biological context'),

              const Spacer(flex: 2),

              // Error message
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: BioVoltColors.coral,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (_loading)
                const CircularProgressIndicator(color: BioVoltColors.teal)
              else
                Column(
                  children: [
                    // Google button
                    GestureDetector(
                      onTap: _signInWithGoogle,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: BioVoltColors.teal.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: BioVoltColors.teal.withAlpha(120),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  'G',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4285F4),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'CONTINUE WITH GOOGLE',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: BioVoltColors.teal,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Guest option
                    GestureDetector(
                      onTap: _continueAsGuest,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: BioVoltColors.cardBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'CONTINUE AS GUEST',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: BioVoltColors.textSecondary,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'Guest data is saved locally only',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: BioVoltColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

              const Spacer(),

              Text(
                'Your data never leaves your device without permission',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: BioVoltColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureLine(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: BioVoltColors.teal,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: BioVoltColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
