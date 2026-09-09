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
          _errorMessage = apiService.loginErrorMessage ?? 'Authentication failed. Please verify your credentials.';
        });
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    final credentials = await BiometricService.getSavedCredentials();
    if (credentials == null) {
      setState(() {
        _errorMessage = 'No biometric credentials enrolled. Please log in manually.';
      });
      return;
    }

    final ownerEmail = credentials['username']?.trim() ?? '';
    final typedUsername = _usernameController.text.trim();

    // STRICT ANTI-BREACH GUARD:
    // If a different username is typed into the box, reject biometric execution immediately
    if (typedUsername.isNotEmpty && typedUsername.toLowerCase() != ownerEmail.toLowerCase()) {
      setState(() {
        _errorMessage = 'Biometric login is not available for this account. Please enter password manually.';
      });
      return;
    }

    final authenticated = await BiometricService.authenticate();
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
          _errorMessage = apiService.loginErrorMessage ?? 'Biometric login failed on server. Please verify your credentials manually.';
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
          // Subtle dark vignette gradient overlay for high contrast and elegance
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.20),
                  Colors.black.withOpacity(0.40),
                ],
              ),
            ),
          ),
          // Top-right Credits Button (Apple Frosted Glass Circle)
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
                  borderRadius: BorderRadius.circular(22),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.45),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Centered Apple Glassmorphic Login Card
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 38.0),
                        decoration: BoxDecoration(
                          // Apple frosted glass gradient
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.80),
                              Colors.white.withOpacity(0.58),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.70),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.22),
                              blurRadius: 36,
                              spreadRadius: 2,
                              offset: const Offset(0, 16),
                            ),
                            BoxShadow(
                              color: const Color(0xFF0056B3).withOpacity(0.12),
                              blurRadius: 40,
                              spreadRadius: -4,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Apple Squircle Logo Container
                              Center(
                                child: Container(
                                  width: 78,
                                  height: 78,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0A84FF), Color(0xFF0056B3)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.40),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF007AFF).withOpacity(0.40),
                                        blurRadius: 20,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.donut_large_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // App Title
                              Text(
                                AppConfig.mode == AppMode.corenergy ? 'PIMS MCP' : 'HCP Profiling',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF00458E),
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Healthcare Professional Management',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFF1D1D1F).withOpacity(0.55),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Username Field
                              Text(
                                'USERNAME',
                                style: TextStyle(
                                  color: const Color(0xFF1D1D1F).withOpacity(0.65),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _usernameController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(
                                  color: Color(0xFF1C1C1E),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                    color: const Color(0xFF0056B3).withOpacity(0.7),
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.75),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.85),
                                      width: 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.85),
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF0071E3),
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.red.shade400,
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Colors.red,
                                      width: 2,
                                    ),
                                  ),
                                  hintText: 'name@company.com',
                                  hintStyle: TextStyle(
                                    color: const Color(0xFF1D1D1F).withOpacity(0.35),
                                    fontSize: 14,
                                  ),
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
                              Text(
                                'PASSWORD',
                                style: TextStyle(
                                  color: const Color(0xFF1D1D1F).withOpacity(0.65),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                  color: Color(0xFF1C1C1E),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    color: const Color(0xFF0056B3).withOpacity(0.7),
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF1D1D1F).withOpacity(0.45),
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.75),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.85),
                                      width: 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.85),
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF0071E3),
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.red.shade400,
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Colors.red,
                                      width: 2,
                                    ),
                                  ),
                                  hintText: 'Enter password',
                                  hintStyle: TextStyle(
                                    color: const Color(0xFF1D1D1F).withOpacity(0.35),
                                    fontSize: 14,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50.withOpacity(0.92),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: Colors.red.shade800,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Login Button (Apple Blue Gradient Capsule)
                              Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF007AFF), Color(0xFF0056B3)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0066CC).withOpacity(0.38),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    disabledBackgroundColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Login',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                ),
                              ),

                              // Biometric Button (Apple Frosted Capsule)
                              if (_isBiometricAvailable && _hasSavedCredentials) ...[
                                const SizedBox(height: 14),
                                Builder(
                                  builder: (context) {
                                    final typed = _usernameController.text.trim();
                                    final bool isOwnerMatching = typed.isEmpty ||
                                        typed.toLowerCase() == _enrolledOwner.toLowerCase();

                                    if (isOwnerMatching) {
                                      return Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.55),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.85),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.04),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(14),
                                            onTap: _isLoading ? null : _handleBiometricLogin,
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.fingerprint_rounded,
                                                  color: Color(0xFF0056B3),
                                                  size: 22,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Biometric Login',
                                                  style: TextStyle(
                                                    color: Color(0xFF0056B3),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    } else {
                                      return const SizedBox.shrink();
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
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
