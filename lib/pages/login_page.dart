import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:math';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController usernameController;
  late final TextEditingController passwordController;

  bool _isLoading = false;
  bool _obscure = true;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    usernameController = TextEditingController();
    passwordController = TextEditingController();
  }

  Future<void> loginAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    setState(() => _isLoading = true);
    try {
        final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('username', username);

        if (mounted) setState(() => _isLoading = false);
        // show success dialog then navigate when user taps Tutup
        final proceed = await _showResultDialog(true, 'Login Berhasil', 'Anda berhasil masuk');
        if (proceed == true && mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        await _showResultDialog(false, 'Login Gagal', 'Username atau Password salah');
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      await _showResultDialog(false, 'Kesalahan', 'Terjadi kesalahan: $e');
    }
  }

  Future<bool?> _showResultDialog(bool success, String title, String message) {
    final mainColor = Colors.teal.shade700;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: success ? Colors.green.shade600 : Colors.red.shade600,
                    boxShadow: [
                      BoxShadow(
                        color: (success ? Colors.green : Colors.red).withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      success ? Icons.check : Icons.close,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(success),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showResetPasswordDialog() async {
    // 1) Minta username via dialog sederhana (buat controller di luar builder supaya bisa dispose dengan aman)
    final usernameControllerDialog = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: usernameControllerDialog,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 8),
              const Text('Masukkan username Anda.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dCtx).pop(null), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final v = usernameControllerDialog.text.trim();
                if (v.isEmpty) {
                  ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Masukkan username')));
                  return;
                }
                Navigator.of(dCtx).pop(v);
              },
              child: const Text('Lanjut'),
            ),
          ],
        );
      },
    );
    // schedule disposal after frame to avoid disposing while the dialog widgets
    // are still being torn down (prevents "used after dispose" race)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      usernameControllerDialog.dispose();
    });

    if (username == null) return; // dibatalkan

    // 2) Setelah mendapat username, jalankan pemeriksaan async di luar dialog
    try {
      final snap = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: username).limit(1).get();
      if (snap.docs.isEmpty) {
        if (mounted) _showMessage('Username tidak ditemukan');
        return;
      }
      final userDoc = snap.docs.first;
      final userData = userDoc.data();

      // 3) Tampilkan dialog password baru (buat controller di luar builder supaya bisa dispose)
      final pCtrl = TextEditingController();
      final cCtrl = TextEditingController();
      final newPass = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dCtx2) {
          return AlertDialog(
            title: const Text('Password Baru'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: pCtrl, decoration: const InputDecoration(labelText: 'Password baru'), obscureText: true),
                const SizedBox(height: 8),
                TextFormField(controller: cCtrl, decoration: const InputDecoration(labelText: 'Konfirmasi password'), obscureText: true),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dCtx2).pop(null), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () {
                  final np = pCtrl.text;
                  final cf = cCtrl.text;
                  if (np.length < 4) {
                    ScaffoldMessenger.of(dCtx2).showSnackBar(const SnackBar(content: Text('Password minimal 4 karakter')));
                    return;
                  }
                  if (np != cf) {
                    ScaffoldMessenger.of(dCtx2).showSnackBar(const SnackBar(content: Text('Password tidak cocok')));
                    return;
                  }
                  Navigator.of(dCtx2).pop(np);
                },
                child: const Text('Reset'),
              ),
            ],
          );
        },
      );
      // schedule disposal after the dialog has fully been removed from the tree
      WidgetsBinding.instance.addPostFrameCallback((_) {
          pCtrl.dispose();
          cCtrl.dispose();
        });

      if (newPass == null) return; // dibatalkan

      // 4) Update password di Firestore
      await FirebaseFirestore.instance.collection('users').doc(userDoc.id).update({
        'password': newPass,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) _showMessage('Password berhasil direset');
    } catch (e) {
      if (mounted) _showMessage('Gagal reset password: $e');
    }
  }


  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({required String label, Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Colors.teal.shade700;
    final isWide = MediaQuery.of(context).size.width > 600;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login', style: TextStyle(color: Colors.white)),
        backgroundColor: mainColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe6f4f2), Color(0xFFffffff)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isWide ? 48 : 20, vertical: isWide ? 40 : 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: mainColor.withOpacity(0.10),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: mainColor.withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: SizedBox(
                              width: 100,
                              height: 100,
                              child: Image.asset(
                                'assets/logoStokOpname.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, size: 64, color: mainColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Title
                      Center(
                        child: Text(
                          'Stok Opname Barang',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Silakan masuk untuk mengelola stok',
                          style: TextStyle(
                            color: Colors.teal.shade400,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: usernameController,
                              keyboardType: TextInputType.text,
                              decoration: _inputDecoration(
                                label: 'Username',
                                prefix: const Icon(Icons.person, color: Colors.teal),
                              ).copyWith(
                                filled: true,
                                fillColor: Colors.grey[50],
                                hintStyle: const TextStyle(color: Colors.grey),
                              ),
                              style: const TextStyle(fontSize: 15),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan username' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: passwordController,
                              obscureText: _obscure,
                              decoration: _inputDecoration(
                                label: 'Password',
                                prefix: IconButton(
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.teal),
                                ),
                              ).copyWith(
                                filled: true,
                                fillColor: Colors.grey[50],
                                hintStyle: const TextStyle(color: Colors.grey),
                              ),
                              style: const TextStyle(fontSize: 15, letterSpacing: 1),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan password' : null,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Checkbox(
                                  value: _remember,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (v) => setState(() => _remember = v ?? true),
                                  activeColor: mainColor,
                                ),
                                const SizedBox(width: 6),
                                const Text('Ingat saya'),
                                const Spacer(),
                                TextButton(
                                  onPressed: _showResetPasswordDialog,
                                  style: TextButton.styleFrom(foregroundColor: mainColor),
                                  child: const Text('Lupa Password?'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : loginAdmin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mainColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 4,
                                  shadowColor: mainColor.withOpacity(0.18),
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Color.fromARGB(255, 255, 255, 255), strokeWidth: 2.5))
                                    : const Text('Sign In', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Info bawah login
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text('ℹ️', style: TextStyle(fontSize: 20)),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'User baru hanya bisa dibuat oleh admin.\nSilakan hubungi admin untuk pendaftaran.',
                                  style: TextStyle(color: Colors.teal, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
