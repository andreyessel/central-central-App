import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'dart:async';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _studentNumberController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final Color _textColor = Colors.white;
  final Color _linkColor = Colors.blueAccent;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;

  AnimationController? _flashController;
  Animation<Color?>? _colorAnimation;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _colorAnimation =
        ColorTween(
          begin: Colors.red,
          end: Colors.amber,
        ).animate(_flashController!)..addListener(() {
          setState(() {});
        });
  }

  @override
  void dispose() {
    _studentNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _flashController?.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        _errorMessage = 'Please enter both email address and password.';
        _flashController?.forward().then((_) => _flashController?.reverse());
        return;
      }

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final User? user = userCredential.user;

      if (user != null) {
        // Store student number if provided
        if (_studentNumberController.text.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'studentNumber',
            _studentNumberController.text.trim(),
          );
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomePage(
              studentName:
                  user.displayName ?? user.email?.split('@').first ?? 'Student',
            ),
          ),
        );
      } else {
        _errorMessage = 'Login failed. Please check your credentials.';
        _flashController?.forward().then((_) => _flashController?.reverse());
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else {
        message = e.message ?? 'An unknown authentication error occurred.';
      }
      _errorMessage = message;
      _flashController?.forward().then((_) => _flashController?.reverse());
    } catch (e) {
      _errorMessage = 'Login failed: ${e.toString()}';
      _flashController?.forward().then((_) => _flashController?.reverse());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _errorMessage = 'Google Sign-In cancelled.';
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomePage(
              studentName:
                  user.displayName ?? user.email?.split('@').first ?? 'Student',
            ),
          ),
        );
      } else {
        _errorMessage = 'Google Sign-In failed.';
        _flashController?.forward().then((_) => _flashController?.reverse());
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'An error occurred during Google Sign-In.';
      _flashController?.forward().then((_) => _flashController?.reverse());
    } catch (e) {
      _errorMessage = 'Google Sign-In failed: ${e.toString()}';
      _flashController?.forward().then((_) => _flashController?.reverse());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 41, 41, 41),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/central_central_logo.png',
                height: 150,
                width: 150,
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to Central Central',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _studentNumberController,
                style: TextStyle(color: _textColor),
                decoration: _inputDecoration(
                  'Student Number (Optional)',
                  _errorMessage != null,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                style: TextStyle(color: _textColor),
                decoration: _inputDecoration(
                  'Email Address',
                  _errorMessage != null,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                style: TextStyle(color: _textColor),
                obscureText: !_isPasswordVisible,
                decoration: _inputDecoration('Password', _errorMessage != null)
                    .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: _textColor.withOpacity(0.7),
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: _colorAnimation?.value ?? Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF732525),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Login',
                          style: TextStyle(fontSize: 18, color: _textColor),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: _textColor.withOpacity(0.5))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Text(
                      'OR',
                      style: TextStyle(color: _textColor.withOpacity(0.8)),
                    ),
                  ),
                  Expanded(child: Divider(color: _textColor.withOpacity(0.5))),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    side: BorderSide(color: _textColor.withOpacity(0.5)),
                  ),
                  icon: FaIcon(FontAwesomeIcons.google, color: _textColor),
                  label: Text(
                    'Sign in with Google',
                    style: TextStyle(fontSize: 18, color: _textColor),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: _textColor.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  children: [
                    const TextSpan(text: 'By logging in, you agree to our '),
                    TextSpan(
                      text: 'Terms & Conditions',
                      style: TextStyle(
                        color: _linkColor,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PlaceholderPage(
                                title: 'Terms & Conditions',
                              ),
                            ),
                          );
                        },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String labelText, bool isFlashing) {
    Color borderColor = isFlashing
        ? _colorAnimation!.value!
        : _textColor.withOpacity(0.2);

    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: _textColor),
      filled: true,
      fillColor: _textColor.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: _linkColor, width: 2.0),
      ),
    );
  }
}
