// ignore_for_file: unused_local_variable, unused_element, unnecessary_cast

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../widgets/custom_navbar.dart';

class RekapBarangPage extends StatefulWidget {
  const RekapBarangPage({super.key});

  @override
  State<RekapBarangPage> createState() => _RekapBarangPageState();
}

class _RekapBarangPageState extends State<RekapBarangPage> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<bool> _requestStoragePermission() async {
    var status = await Permission.storage.request();
    return status.isGranted;
  }



  Future<String> _getDownloadPath() async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (await directory.exists()) return directory.path;
      } else {
        final d = await getDownloadsDirectory();
        if (d != null) return d.path;
      }
    } catch (_) {}
    final appDoc = await getApplicationDocumentsDirectory();
    return appDoc.path;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    try {
      if (value is Timestamp) {
        final dt = value.toDate();
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      } else if (value is DateTime) {
        final dt = value;
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      } else {
        final s = value.toString();
        if (s.isEmpty) return '-';
        return s;
      }
    } catch (_) {
      return value.toString();
    }
  }

  Future<void> _exportBarangToExcel(BuildContext context) async {
    final granted = await _requestStoragePermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin penyimpanan diperlukan untuk menyimpan file.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .orderBy('createdAt', descending: true)
          .get();

      final excel = Excel.createExcel();
      final Sheet sheet = excel['Sheet1'];

      sheet.appendRow([
        'Nama',
        'Model',
        'Tanggal Masuk',
        'Tanggal Keluar',
        'Tanggal Rusak', // <-- ditambahkan
        'No Inventaris',
        'SN',
        'Status',
        'Keterangan',
      ]);

      for (final doc in snapshot.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final tMasukRaw = d['tanggal_masuk'] ?? d['tanggal'];
        final tKeluarRaw = d['tanggal_keluar'];
        final tRusakRaw = d['tanggal_rusak']; // <-- ambil tanggal rusak

        final tanggalMasuk = _formatDate(tMasukRaw);
        final tanggalKeluar = _formatDate(tKeluarRaw);
        final tanggalRusak = _formatDate(tRusakRaw); // <-- format tanggal rusak

        sheet.appendRow([
          d['nama'] ?? '',
          d['jenis'] ?? '',
          tanggalMasuk,
          tanggalKeluar,
          tanggalRusak, // <-- masukkan ke baris
          d['no_inventaris'] ?? '',
          d['sn'] ?? '',
          d['status'] ?? '',
          d['keterangan'] ?? '',
        ]);
      }

      final excelBytes = excel.encode();
      if (excelBytes == null) throw Exception('Gagal membuat file Excel.');

      String filePath;
      File file;
      final fileName = 'Rekap_Data_Barang_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          filePath = '${downloadDir.path}/$fileName';
          file = File(filePath);
          await file.writeAsBytes(excelBytes);
        } else {
          throw Exception('Download dir tidak ada');
        }
      } catch (_) {
        final appDir = await getApplicationDocumentsDirectory();
        filePath = '${appDir.path}/$fileName';
        file = File(filePath);
        await file.writeAsBytes(excelBytes);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rekap data berhasil disimpan di:\n$filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Buka',
              textColor: Colors.white,
                  onPressed: () async {
                    try {
                      await Share.shareXFiles([XFile(filePath)], text: 'Rekap Data Barang');
                    } catch (_) {}
                  },
            ),
          ),
        );

        _showExportResultDialog(context, filePath);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan rekap data barang!\nDetail error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _loading = false);
  }

  // ------------------ IMPORT FEATURE ------------------
  DateTime? _tryParseDate(dynamic v) {
    if (v == null) return null;
    try {
      if (v is DateTime) return v;
      if (v is Timestamp) return v.toDate();
      if (v is num) {
        // Excel sometimes encodes dates as serial numbers (days since 1899-12-30)
        try {
          final excelEpoch = DateTime(1899, 12, 30);
          final ms = (v * 86400 * 1000).round();
          return excelEpoch.add(Duration(milliseconds: ms));
        } catch (_) {}
      }
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      // Try ISO parse first
      final parsed = DateTime.tryParse(s);
      if (parsed != null) return parsed;
      // Try common dd/mm/yyyy or dd-mm-yyyy
      final re = RegExp(r"^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$");
      final m = re.firstMatch(s);
      if (m != null) {
        final d = int.parse(m.group(1)!);
        final mo = int.parse(m.group(2)!);
        final y = int.parse(m.group(3)!).abs();
        final year = y < 100 ? 2000 + y : y;
        return DateTime(year, mo, d);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _importBarangFromExcel(BuildContext context) async {
    setState(() => _loading = true);
    // pick file
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xls', 'xlsx'],
        withData: kIsWeb ? true : false,
        allowMultiple: false,
      );
      if (result == null) return; // user cancelled

      // read bytes
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = result.files.single.bytes;
      } else {
        final path = result.files.single.path;
        if (path == null) throw Exception('File path unavailable');
        bytes = await File(path).readAsBytes();
      }
      if (bytes == null) throw Exception('Gagal membaca file');

  debugPrint('Import: file bytes length=${bytes.length}');
  final excel = Excel.decodeBytes(bytes);
  debugPrint('Import: parsed excel, sheets=${excel.tables.keys.toList()}');
      if (excel.tables.isEmpty) throw Exception('File Excel kosong');
      final sheetName = excel.tables.keys.first;
      final table = excel.tables[sheetName]!;

      if (table.rows.isEmpty) throw Exception('Sheet kosong');

      // header mapping
      final headerRow = table.rows.first;
      final headers = <int, String>{};
      for (var i = 0; i < headerRow.length; i++) {
        final h = headerRow[i]?.value?.toString() ?? '';
        headers[i] = h.trim().toLowerCase();
      }

      // collect records
      final records = <Map<String, dynamic>>[];
      for (var r = 1; r < table.rows.length; r++) {
        final row = table.rows[r];
        // build map using header names
        final Map<String, dynamic> doc = {};
        for (var c = 0; c < row.length; c++) {
          final key = headers[c] ?? 'col_$c';
          final cell = row[c];
          final val = cell?.value;
          doc[key] = val;
        }

        // helper to get by various keys
        String getByKeys(List<String> keys) {
          for (final k in keys) {
            final entry = doc.entries.firstWhere((e) => e.key.contains(k) || e.key == k, orElse: () => const MapEntry('', null));
            final found = entry.value;
            if (found != null && found.toString().trim().isNotEmpty) return found.toString();
          }
          return '';
        }

        final namaVal = getByKeys(['nama', 'name']);
        final jenisVal = getByKeys(['model', 'jenis']);
        final noInvVal = getByKeys(['no_inventaris', 'no inventaris', 'no_inventory', 'no']);
        final snVal = getByKeys(['sn', 'serial']);
        final statusVal = getByKeys(['status']);
        final ketVal = getByKeys(['keterangan', 'keterangan ']);

        // tanggal fields
        dynamic rawMasuk = doc.entries.firstWhere((e) => e.key.contains('tanggal masuk') || e.key.contains('tanggal_masuk') || e.key.contains('tanggal') || e.key.contains('date'), orElse: () => const MapEntry('', null)).value;
        dynamic rawKeluar = doc.entries.firstWhere((e) => e.key.contains('tanggal keluar') || e.key.contains('tanggal_keluar'), orElse: () => const MapEntry('', null)).value;
        dynamic rawRusak = doc.entries.firstWhere((e) => e.key.contains('tanggal rusak') || e.key.contains('tanggal_rusak'), orElse: () => const MapEntry('', null)).value;

        final masukDt = _tryParseDate(rawMasuk);
        final keluarDt = _tryParseDate(rawKeluar);
        final rusakDt = _tryParseDate(rawRusak);

        final item = <String, dynamic>{
          'nama': namaVal,
          'namaLower': namaVal.toLowerCase(),
          'jenis': jenisVal,
          'tanggal_masuk': masukDt != null ? Timestamp.fromDate(masukDt) : null,
          'tanggal_keluar': keluarDt != null ? Timestamp.fromDate(keluarDt) : null,
          'tanggal_rusak': rusakDt != null ? Timestamp.fromDate(rusakDt) : null,
          'no_inventaris': noInvVal,
          'sn': snVal,
          'status': statusVal.isNotEmpty ? statusVal.toLowerCase() : 'masuk',
          'keterangan': ketVal,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        records.add(item);
      }

  if (records.isEmpty) throw Exception('Tidak ada baris data untuk diimpor');

      // show preview and confirm
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('Preview Import (${records.length} baris)'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Contoh 5 baris pertama:'),
                  const SizedBox(height: 8),
                  ...records.take(5).map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(r['nama'] ?? '-'))),
                  const SizedBox(height: 12),
                  const Text('Klik Import untuk memulai proses. Dokumen akan ditambahkan ke koleksi items.'),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Import')),
            ],
          );
        },
      );

  if (confirmed != true) return;

      // perform batch writes with chunking
      final firestore = FirebaseFirestore.instance;
      const chunkSize = 400; // keep below 500 limit
      int imported = 0;
      for (var i = 0; i < records.length; i += chunkSize) {
        final chunk = records.sublist(i, (i + chunkSize) > records.length ? records.length : (i + chunkSize));
        final batch = firestore.batch();
        for (final rec in chunk) {
          final docRef = firestore.collection('items').doc();
          // remove null values to avoid potential errors from platform drivers
          final sanitized = <String, dynamic>{};
          rec.forEach((k, v) {
            if (v != null) sanitized[k] = v;
          });
          batch.set(docRef, sanitized);
        }
        await batch.commit();
        imported += chunk.length;
      }

      if (context.mounted) {
        // Tampilkan dialog sukses
        await showDialog(
          context: context,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      color: Colors.green.shade600,
                      boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 6))],
                    ),
                    child: const Center(child: Icon(Icons.check, size: 56, color: Colors.white)),
                  ),
                  const SizedBox(height: 18),
                  const Text('Import Berhasil!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('$imported data barang telah ditambahkan', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        
        // Refresh data dengan menampilkan snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil mengimpor $imported baris.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          )
        );
        
        // Tidak perlu refresh manual karena menggunakan StreamBuilder
      }
    } catch (e, st) {
      debugPrint('Import error: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengimpor: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showExportResultDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.green.shade600,
                  child: const Icon(Icons.check, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(
                  'Berhasil diunduh',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'File rekap telah disimpan.',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                Text(
                  filePath,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Buka / Bagikan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    try {
                      await Share.shareXFiles([XFile(filePath)], text: 'Rekap Data Barang');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal membuka file: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Tutup', style: TextStyle(color: Colors.green.shade700)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Colors.teal.shade700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFB),
      appBar: AppBar(
        title: const Text('Rekap Data Barang', style: TextStyle(color: Colors.white)),
        backgroundColor: mainColor,
        elevation: 0,
      ),
      bottomNavigationBar: const CustomNavBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('items').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final documents = snapshot.data?.docs ?? [];

          // Use ListView so RefreshIndicator works correctly
          return RefreshIndicator(
            onRefresh: () async {
              // no-op: stream provides updates; brief delay for UX
              await Future.delayed(const Duration(milliseconds: 300));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: mainColor.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: mainColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.table_view, color: mainColor, size: 34),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rekap Data Barang',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: mainColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Export seluruh data barang ke file Excel. File akan disimpan di folder Download jika tersedia, otherwise di direktori aplikasi.',
                              style: TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Statistics
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ringkasan Data',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            icon: Icons.inventory_2_outlined,
                            label: 'Total\nBarang',
                            value: documents.length.toString(),
                            color: mainColor,
                          ),
                          _buildStatItem(
                            icon: Icons.timeline,
                            label: 'Status\nAktif',
                            value: documents.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return (data['status'] as String?)?.toLowerCase() == 'masuk';
                            }).length.toString(),
                            color: Colors.green.shade700,
                          ),
                          _buildStatItem(
                            icon: Icons.report_problem_outlined,
                            label: 'Perlu\nPerhatian',
                            value: documents.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final status = (data['status'] as String?)?.toLowerCase();
                              return status == 'rusak' || status == 'keluar';
                            }).length.toString(),
                            color: Colors.orange.shade800,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Buttons
                _loading
                    ? Column(
                        children: [
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(mainColor)),
                          const SizedBox(height: 14),
                          const Text('Mengekspor / Mengimpor data...'),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.file_download),
                            label: const Text('Export Rekap Data Barang ke Excel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _exportBarangToExcel(context),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.file_upload),
                            label: const Text('Import Data dari Excel'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _importBarangFromExcel(context),
                          ),
                        ],
                      ),

                const SizedBox(height: 12),

                Text(
                  'Tip: Jika file tidak muncul di folder Download, cek notifikasi atau gunakan tombol "Buka" untuk membagikan/menyimpan secara manual.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}

// Card statistik barang
class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 90,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }
}