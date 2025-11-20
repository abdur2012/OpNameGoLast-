

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

// Import semua halaman
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/tambah_barang_page.dart';
import 'pages/edit_barang_page.dart';
import 'pages/data_barang_page.dart';
import 'pages/data_barang_keluar_page.dart';
import 'pages/tambah_barang_keluar_page.dart';
import 'pages/tambah_barang_rusak_page.dart';
import 'pages/rekap_barang_page.dart';
import 'pages/admin_page.dart';
import 'pages/splashscreen.dart';
import 'pages/summary_by_category_page.dart';


import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stok Opname Barang',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
  initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/tambah': (context) => const TambahBarangPage(),
        '/edit-barang': (context) => const EditBarangPage(),
        '/data-barang': (context) => const DataBarangPage(),
        '/data-barang-keluar': (context) => const DataBarangPageKeluar(),
        '/tambah-barang-keluar': (context) => const TambahBarangKeluarPage(),
        '/tambah-barang-rusak': (context) => const TambahBarangRusakPage(),
        '/rekap-barang': (context) => const RekapBarangPage(),
        '/admin': (context) => const AdminPage(),
        '/summary-category': (context) => const SummaryByCategoryPage(),
        
      },
    );
  }
}
