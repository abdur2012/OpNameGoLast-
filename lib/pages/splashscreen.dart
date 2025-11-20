import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Timer untuk pindah ke login setelah 2 detik
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Image.asset(
          'assets/logoStokOpname.png',
          width: 120,
          height: 120,
          errorBuilder: (context, error, stackTrace) {
            // jika asset tidak ditemukan (mis. saat build web sementara), tampilkan ikon fallback
            return Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Center(
                child: Icon(Icons.image_not_supported, size: 56, color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }
}