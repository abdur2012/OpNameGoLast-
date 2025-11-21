import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/audit_service.dart';
import '../widgets/custom_navbar.dart';
import 'data_barang_page.dart';

class TambahBarangRusakPage extends StatefulWidget {
  const TambahBarangRusakPage({super.key});

  @override
  State<TambahBarangRusakPage> createState() => _TambahBarangRusakPageState();
}

class _TambahBarangRusakPageState extends State<TambahBarangRusakPage> {
  final _formKey = GlobalKey<FormState>();

  // selection & data
  String? _selectedNamaBarang;
  String? _selectedDocId;
  String? _jenisBarang;
  String? _noInventaris;
  String? _snBarang;

  // search and controllers
  String _search = '';
  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _jenisController = TextEditingController();
  final TextEditingController _noInventarisController = TextEditingController();
  final TextEditingController _snController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _tanggalController.dispose();
    _jenisController.dispose();
    _noInventarisController.dispose();
    _snController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Widget buildLoadingDialog() {
    final mainColor = Colors.teal.shade700;
    return Dialog(
      backgroundColor: mainColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              backgroundColor: Colors.teal.shade200,
              strokeWidth: 4,
            ),
            const SizedBox(height: 18),
            const Text(
              'Menyimpan...',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _tanggalController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _simpanBarangRusak() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih barang terlebih dahulu')));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (_) => buildLoadingDialog());

    try {
      final tanggalRusak = DateTime.parse(_tanggalController.text.trim());

      await FirebaseFirestore.instance.collection('items').doc(_selectedDocId).update({
        'status': 'rusak',
        'tanggal_rusak': Timestamp.fromDate(tanggalRusak),
        'keterangan': _keteranganController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log history (best-effort) — include eventType so GlobalHistoryPage can filter
      try {
        await AuditService.logItemHistory(
          itemId: _selectedDocId!,
          action: 'status_change',
          details: {
            'new_status': 'rusak',
            'tanggal_rusak': tanggalRusak.toIso8601String(),
            'keterangan': _keteranganController.text.trim(),
          },
          eventType: 'item',
        );
      } catch (_) {}

      if (mounted) Navigator.of(context).pop(); // close loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barang rusak berhasil disimpan')));
        // Navigate to Data Barang page, replacing current route
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DataBarangPage()));
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // show bottom sheet selector (reusable, similar UX to "barang keluar" page)
  Future<void> _openSelectBarang() async {
    // ambil semua item yang statusnya 'masuk'
    final snap = await FirebaseFirestore.instance.collection('items').where('status', isEqualTo: 'masuk').get();
    final allDocs = snap.docs;

    // filter sesuai query di input atas (SN atau No Inventaris atau nama)
    final query = _search.trim().toLowerCase();
    final filteredDocs = allDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final sn = (data['sn'] ?? '').toString().toLowerCase();
      final noInv = (data['no_inventaris'] ?? '').toString().toLowerCase();
      final nama = (data['nama'] ?? '').toString().toLowerCase();
      if (query.isEmpty) return true;
      return sn.contains(query) || noInv.contains(query) || nama.contains(query);
    }).toList();

    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.34,
            maxChildSize: 0.95,
            expand: false,
            builder: (sheetCtx, scrollController) {
              return Container(
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? Center(child: Text(query.isEmpty ? 'Daftar barang kosong' : 'Tidak ada hasil', style: TextStyle(color: Colors.black54)))
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: filteredDocs.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                              itemBuilder: (context, i) {
                                final doc = filteredDocs[i];
                                final data = doc.data() as Map<String, dynamic>;
                                return ListTile(
                                  title: Text(data['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('SN: ${data['sn'] ?? '-'} • Inv: ${data['no_inventaris'] ?? '-'}'),
                                  onTap: () => Navigator.of(ctx).pop(doc.id),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (selectedId != null) {
      final doc = await FirebaseFirestore.instance.collection('items').doc(selectedId).get();
      if (!doc.exists) return;
      final d = doc.data() as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _selectedDocId = doc.id;
          _selectedNamaBarang = d['nama']?.toString();
          _jenisBarang = d['jenis']?.toString();
          _noInventaris = d['no_inventaris']?.toString();
          _snBarang = d['sn']?.toString();

          _jenisController.text = _jenisBarang ?? '';
          _noInventarisController.text = _noInventaris ?? '';
          _snController.text = _snBarang ?? '';
        });
      }
    }
  }

  // history fetching removed since UI no longer shows riwayat here

  // history UI removed from this page to keep form compact

  @override
  Widget build(BuildContext context) {
    final mainColor = Colors.teal.shade700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFB),
      appBar: AppBar(
        backgroundColor: mainColor,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'Tambah Barang Rusak',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 32,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search + selector (UX similar to barang keluar)
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Cari SN atau No Inventaris',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: _openSelectBarang,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Pilih Barang',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          ),
                          child: _selectedDocId == null
                              ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
                                  Text('Pilih barang', style: TextStyle(color: Colors.black54)),
                                  Icon(Icons.keyboard_arrow_down, color: Colors.grey)
                                ])
                              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_selectedNamaBarang ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text('SN: ${_snController.text} • Inv: ${_noInventarisController.text}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                ]),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Model
                      TextFormField(
                        controller: _jenisController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Model Barang',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // No Inventaris
                      TextFormField(
                        controller: _noInventarisController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'No. Inventaris',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // SN
                      TextFormField(
                        controller: _snController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Serial Number (SN)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tanggal Rusak
                      TextFormField(
                        controller: _tanggalController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Tanggal Rusak',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onTap: _pickDate,
                        validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),

                      // Keterangan
                      TextFormField(
                        controller: _keteranganController,
                        decoration: InputDecoration(
                          labelText: 'Keterangan (Opsional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 28),

                      const SizedBox(height: 28),

                      // Tombol Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Simpan Barang Rusak', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          onPressed: _saving ? null : () async {
                            setState(() => _saving = true);
                            await _simpanBarangRusak();
                            if (mounted) setState(() => _saving = false);
                          },
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
      bottomNavigationBar: const CustomNavBar(),
    );
  }
}