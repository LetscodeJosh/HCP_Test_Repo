import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import 'hcp_dashboard_screen.dart';
import 'list_screen.dart';
import 'credits_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _isBiometricAvailable = false;
  bool _hasSavedCredentials = false;
  String _enrolledOwner = '';
  String _enrolledOwnerName = '';

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    _checkBiometrics();
  }

  @override
  void dispose() {
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.isBiometricAvailable();
    final credentials = await BiometricService.getSavedCredentials();
    if (mounted) {
      setState(() {
        _isBiometricAvailable = available;
        _hasSavedCredentials = credentials != null;
        _enrolledOwner = credentials?['username']?.trim() ?? '';
        _enrolledOwnerName = credentials?['full_name']?.trim() ?? '';
        // Note: Do not auto-populate password or enforce username so fields remain clean on fresh/logout state
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final apiService = Provider.of<ApiService>(context, listen: false);
    final success = await apiService.login(username, password);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        final lowerUsername = username.toLowerCase();
        final lowerOwner = _enrolledOwner.toLowerCase();

        // STRICT SECURITY RULE:
        // Biometrics is locked to the iPad/device owner (Admin).
        // 1. If this account is already the registered device owner, update stored credentials.
        // 2. If NO owner is registered yet AND the user is Admin or Manager, register as the device owner.
        // 3. If any other account (MedRep / guest) logs in, DO NOT save or overwrite device biometrics!
        if (_enrolledOwner.isNotEmpty && lowerUsername == lowerOwner) {
          await BiometricService.saveCredentials(
            username,
            password,
            position: apiService.userPosition.name,
            fullName: apiService.loggedInFullName,
          );
        } else if (_enrolledOwner.isEmpty && (apiService.isAdmin || apiService.isManager)) {
          await BiometricService.saveCredentials(
            username,
            password,
            position: apiService.userPosition.name,
            fullName: apiService.loggedInFullName,
          );
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AppConfig.mode == AppMode.corenergy
                ? const ListScreen()
                : const HcpDashboardScreen(),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Authentication failed. Please verify your credentials.';
        });
      }
    }
  }

  Future<void> _handleResetBiometrics() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Reset Device Biometrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Currently, this iPad is registered to:\n\n$_enrolledOwner\n\n'
          'Do you want to unlink this account? After unlinking, only an Admin account can register as the device owner.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Unlink & Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await BiometricService.clearCredentials();
      await _checkBiometrics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device biometrics unlinked. Log in with your Admin account to bind Touch ID / Face ID.'),
            backgroundColor: Color(0xFF0056B3),
          ),
        );
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    final credentials = await BiometricService.getSavedCredentials();
    if (credentials == null) {
      setState(() {
        _errorMessage = 'No registered biometric owner found on this device. Please log in manually.';
      });
      return;
    }

    final ownerEmail = credentials['username']?.trim() ?? '';
    final typedUsername = _usernameController.text.trim();

    // STRICT ANTI-BREACH GUARD:
    // If a different username is typed into the box, reject biometric execution immediately
    if (typedUsername.isNotEmpty && typedUsername.toLowerCase() != ownerEmail.toLowerCase()) {
      setState(() {
        _errorMessage = 'Security Alert: Biometric login is bound to device owner ($ownerEmail). You cannot use biometrics for $typedUsername. Please enter password manually.';
      });
      return;
    }

    final authenticated = await BiometricService.authenticate(
      customReason: 'Authenticate as $ownerEmail to log in to PIMS HCP',
    );
    if (!authenticated) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = credentials['username']!;
    final password = credentials['password']!;

    // Sync username field to reflect actual authenticated identity
    _usernameController.text = username;

    final apiService = Provider.of<ApiService>(context, listen: false);
    final success = await apiService.login(username, password);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        await BiometricService.saveCredentials(
          username,
          password,
          position: apiService.userPosition.name,
          fullName: apiService.loggedInFullName,
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AppConfig.mode == AppMode.corenergy
                ? const ListScreen()
                : const HcpDashboardScreen(),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Biometric login failed on server. Please verify your credentials manually.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Image.asset(
            'assets/medical_bg.jpg',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          // Subtle overlay & slight blur filter for theme harmony
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
            child: Container(
              color: Colors.black.withOpacity(0.15),
            ),
          ),
          // Top-right Credits Button (Three Dots)
          Positioned(
            top: 12,
            right: 16,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => SizedBox(
                        height: MediaQuery.of(context).size.height * 0.88,
                        child: const CreditsScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      color: Color(0xFF0056B3),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Login Form
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 25,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo Container
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0056B3), Color(0xFF007AFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0056B3).withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.donut_large,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // App Title
                        Text(
                          AppConfig.mode == AppMode.corenergy ? 'PIMS MCP' : 'PIMS HCP',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF0056B3),
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 36),
                        
                        // Username Field
                        const Text(
                          'USERNAME',
                          style: TextStyle(
                            color: Color(0xFF56565A),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _usernameController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Color(0xFF1C1C1E)),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF8E8E93)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0056B3), width: 2),
                            ),
                            hintText: 'name@company.com',
                            hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your username';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Password Field
                        const Text(
                          'PASSWORD',
                          style: TextStyle(
                            color: Color(0xFF56565A),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Color(0xFF1C1C1E)),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8E8E93)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: const Color(0xFF8E8E93),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0056B3), width: 2),
                            ),
                            hintText: 'Enter password',
                            hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 30),
                        
                        if (_errorMessage != null) ...[
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Login Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0056B3),
                            disabledBackgroundColor: const Color(0xFF0056B3).withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        if (_isBiometricAvailable && _hasSavedCredentials) ...[
                          const SizedBox(height: 14),
                          Builder(
                            builder: (context) {
                              final typed = _usernameController.text.trim();
                              final bool isOwnerMatching = typed.isEmpty || typed.toLowerCase() == _enrolledOwner.toLowerCase();

                              if (isOwnerMatching) {
                                final displayName = _enrolledOwnerName.isNotEmpty ? _enrolledOwnerName : _enrolledOwner;
                                return OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _handleBiometricLogin,
                                  icon: const Icon(Icons.fingerprint, color: Color(0xFF0056B3)),
                                  label: Text(
                                    typed.isEmpty ? 'Touch ID Login (Owner: $displayName)' : 'Biometric Login as $displayName',
                                    style: const TextStyle(
                                      color: Color(0xFF0056B3),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                    side: const BorderSide(color: Color(0xFF0056B3), width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              } else {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.lock_person_rounded, color: Color(0xFFD97706), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Biometrics locked to iPad Owner ($_enrolledOwner). Enter password manually to log in as $typed.',
                                          style: const TextStyle(
                                            color: Color(0xFF92400E),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: TextButton.icon(
                              onPressed: _isLoading ? null : _handleResetBiometrics,
                              icon: const Icon(Icons.link_off_rounded, size: 14, color: Color(0xFF64748B)),
                              label: const Text(
                                'Unlink / Reset Device Biometrics',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
