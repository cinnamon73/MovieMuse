import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_data_service.dart';
import '../utils/avatar_helper.dart';
import '../themes/app_colors.dart';

class AuthPage extends StatefulWidget {
  final AuthService authService;
  final UserDataService userDataService;
  final VoidCallback? onAuthChanged;
  const AuthPage({
    super.key, 
    required this.authService, 
    required this.userDataService,
    this.onAuthChanged
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  
  String? _error;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isSignUpTab = false;
  String? _currentUsername;
  String? _currentAvatarId;
  bool _isUpdatingProfile = false;

  // Get preset avatar options from helper
  List<Map<String, String>> get _presetAvatars => AvatarHelper.getAvatarOptions();

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    try {
      final userData = await widget.userDataService.getCurrentUserData();
      setState(() {
        _currentUsername = userData.username;
        _currentAvatarId = userData.avatarId;
      });
    } catch (_) {}
  }

  String? _getAvatarAsset(String? avatarId) {
    return AvatarHelper.getAvatarAsset(avatarId);
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose Your Avatar',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _presetAvatars.length,
                itemBuilder: (context, index) {
                  final avatar = _presetAvatars[index];
                  final isSelected = _currentAvatarId == avatar['id'];
                  return GestureDetector(
                    onTap: () async {
                      setState(() => _isUpdatingProfile = true);
                      try {
                        await widget.userDataService.updateAvatarId(avatar['id']!);
                        setState(() { _currentAvatarId = avatar['id']; _isUpdatingProfile = false; });
                        if (mounted) Navigator.pop(context);
                      } catch (_) { setState(() => _isUpdatingProfile = false); }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 3),
                      ),
                      child: ClipOval(
                        child: Image.asset(avatar['asset']!, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? email) {
    if (email == null || email.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }
  String? _validateUsername(String? username) {
    if (username == null || username.isEmpty) return 'Username is required';
    if (username.length < 3) return 'Username must be at least 3 characters';
    if (username.length > 20) return 'Username must be less than 20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) return 'Only letters, numbers, and _ allowed';
    return null;
  }
  String? _validatePassword(String? password) {
    if (password == null || password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    if (password.length > 64) return 'Password is too long';
    return null;
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      print('🚀 Starting account creation...');
      await widget.authService.signUpWithEmailEphemeral(
        _emailController.text.trim(),
        _passwordController.text,
        username: _usernameController.text.trim(),
      );
      print('✅ Account created successfully');
      
      try { 
        await widget.userDataService.updateUsername(_usernameController.text.trim());
        print('✅ Username updated successfully');
      } catch (e) {
        print('⚠️ Username update failed: $e');
      }
      
      try {
        await FirebaseAuth.instance.currentUser?.sendEmailVerification();
        print('✅ Email verification sent');
      } catch (e) {
        print('⚠️ Email verification failed: $e');
      }
      
      widget.onAuthChanged?.call();
      if (mounted) {
        print('✅ Navigating back...');
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Account creation failed: $e');
      setState(() { _error = e is FirebaseAuthException ? widget.authService.getErrorMessage(e) : 'Something went wrong'; });
    } finally { 
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      await widget.authService.signInWithEmailEphemeral(
        _emailController.text.trim(),
        _passwordController.text,
      );
      widget.onAuthChanged?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e is FirebaseAuthException ? widget.authService.getErrorMessage(e) : 'Something went wrong'; });
    } finally { setState(() { _isLoading = false; }); }
  }

  Future<void> _signOut() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await widget.authService.signOutAndCreateAnonymous();
      widget.onAuthChanged?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = 'Failed to sign out. Please try again.'; });
    } finally { setState(() { _isLoading = false; }); }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;
    final isAnonymous = widget.authService.isAnonymous;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Account', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Signed-in profile card
            if (user != null && !isAnonymous) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isUpdatingProfile ? null : _showAvatarPicker,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey[700],
                            backgroundImage: _getAvatarAsset(_currentAvatarId) != null 
                              ? AssetImage(_getAvatarAsset(_currentAvatarId)!) as ImageProvider
                              : null,
                            child: _getAvatarAsset(_currentAvatarId) == null
                              ? const Icon(Icons.person, color: Colors.white, size: 36)
                              : null,
                          ),
                          if (_isUpdatingProfile)
                            const Positioned.fill(
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_currentUsername ?? 'Loading...', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(user.email ?? '', style: TextStyle(color: Colors.grey[400])),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))) : const Text('Sign Out'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : () async {
                          final email = user.email ?? '';
                          final controller = TextEditingController();
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Account'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Enter your password to confirm. This action is irreversible.'),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: controller,
                                    obscureText: true,
                                    decoration: const InputDecoration(labelText: 'Password'),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            setState(() => _isLoading = true);
                            try {
                              await widget.authService.deleteUserAccountAndCloudData(email: email, password: controller.text);
                              if (mounted) Navigator.pop(context); // leave account screen
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                              }
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Account'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Auth form
            if (user == null || isAnonymous) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tabs
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isSignUpTab = false),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !_isSignUpTab ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('Sign In', textAlign: TextAlign.center, style: TextStyle(color: !_isSignUpTab ? Colors.white : Colors.grey[400], fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isSignUpTab = true),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _isSignUpTab ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('Create Account', textAlign: TextAlign.center, style: TextStyle(color: _isSignUpTab ? Colors.white : Colors.grey[400], fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      if (_isSignUpTab) ...[
                        TextFormField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _input('Username'),
                          validator: _validateUsername,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: _input('Email'),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: _input('Password').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: Colors.grey[400]),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: _validatePassword,
                      ),

                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: 12),
                      ],

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : (_isSignUpTab ? _signUp : _signIn),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))),
                                  const SizedBox(width: 12),
                                  Text(_isSignUpTab ? 'Creating Account...' : 'Signing In...', style: const TextStyle(color: Colors.white)),
                                ],
                              )
                            : Text(_isSignUpTab ? 'Create Account' : 'Sign In'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400]),
      filled: true,
      fillColor: Colors.white.withOpacity(0.02),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.primary)),
    );
  }
} 