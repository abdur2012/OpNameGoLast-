import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/audit_service.dart';
import '../widgets/custom_navbar.dart';

class TambahBarangPage extends StatefulWidget {
  const TambahBarangPage({super.key});

  @override
  State<TambahBarangPage> createState() => _TambahBarangPageState();
}

class _TambahBarangPageState extends State<TambahBarangPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _tanggalKeluarController = TextEditingController();
  final TextEditingController _tanggalRusakController = TextEditingController();
  final TextEditingController _noInventarisController = TextEditingController();
  final TextEditingController _snController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  String? _status;
  String? _selectedJenis;
  bool _saving = false;

  final List<String> _jenisList = [
    'Printer',
    'PC',
    'Switch',
    'CCTV',
    'Monitor',
    'Router',
    'Access Point',
    'NVR/DVR',
    'Video Conference',
  ];

  // Map untuk icon setiap jenis perangkat
  final Map<String, IconData> _jenisIcons = {
    'Printer': Icons.print,
    'PC': Icons.computer,
    'Switch': Icons.router,
    'CCTV': Icons.videocam,
    'Monitor': Icons.monitor,
    'Router': Icons.wifi,
    'Access Point': Icons.wifi_tethering,
    'NVR/DVR': Icons.video_library,
    'Video Conference': Icons.video_call,
  };

  @override
  void dispose() {
    _namaController.dispose();
    _tanggalController.dispose();
    _tanggalKeluarController.dispose();
    _tanggalRusakController.dispose();
    _noInventarisController.dispose();
    _snController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initial = DateTime.parse(controller.text);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  InputDecoration _inputDecoration({required String label, Widget? prefix, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(fontSize: 14, color: Colors.black45),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );
  }

  Future<void> _showSuccessDialog() async {
    final mainColor = Colors.teal.shade700;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mainColor,
                  boxShadow: [BoxShadow(color: mainColor.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 6))],
                ),
                child: const Center(child: Icon(Icons.check, size: 56, color: Colors.white)),
              ),
              const SizedBox(height: 18),
              const Text('Berhasil!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Data barang berhasil ditambahkan', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: mainColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _simpanBarang() async {
    if (!_formKey.currentState!.validate()) return;

    if (_status == 'keluar' && _tanggalKeluarController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tanggal keluar wajib diisi untuk status KELUAR')));
      return;
    }
    if (_status == 'rusak' && _tanggalRusakController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tanggal rusak wajib diisi untuk status RUSAK')));
      return;
    }

    setState(() => _saving = true);

    try {
      final tanggalMasuk = DateTime.parse(_tanggalController.text.trim());
      Timestamp? tsKeluar;
      Timestamp? tsRusak;
      if (_tanggalKeluarController.text.isNotEmpty) {
        tsKeluar = Timestamp.fromDate(DateTime.parse(_tanggalKeluarController.text.trim()));
      }
      if (_tanggalRusakController.text.isNotEmpty) {
        tsRusak = Timestamp.fromDate(DateTime.parse(_tanggalRusakController.text.trim()));
      }

      final docRef = await FirebaseFirestore.instance.collection('items').add({
        'nama': _namaController.text.trim(),
        'namaLower': _namaController.text.trim().toLowerCase(),
        'jenis': _selectedJenis ?? '',
        'tanggal_masuk': Timestamp.fromDate(tanggalMasuk),
        'tanggal_keluar': tsKeluar,
        'tanggal_rusak': tsRusak,
        'no_inventaris': _noInventarisController.text.trim(),
        'sn': _snController.text.trim(),
        'status': _status,
        'keterangan': _keteranganController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Log history (best-effort)
      try {
        await AuditService.logItemHistory(
          itemId: docRef.id,
          action: 'create',
          details: {
            'nama': _namaController.text.trim(),
            'status': _status,
            'no_inventaris': _noInventarisController.text.trim(),
          },
        );
      } catch (_) {}
      // show success dialog
      if (mounted) {
        await _showSuccessDialog();
      }

      // reset form
      _formKey.currentState?.reset();
      _namaController.clear();
      _tanggalController.clear();
      _tanggalKeluarController.clear();
      _tanggalRusakController.clear();
      _noInventarisController.clear();
      _snController.clear();
      _keteranganController.clear();
      setState(() {
        _status = null;
        _selectedJenis = null;
        _saving = false;
      });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  Widget _largeField({required Widget child}) {
    return SizedBox(height: 64, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Colors.teal.shade700;
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFB),
      appBar: AppBar(
        backgroundColor: mainColor,
        centerTitle: true,
        elevation: 0,
        title: const Text('Tambah Barang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      // Header (reset removed)
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: mainColor.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.inventory_2, color: mainColor, size: 30),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(child: Text('Form Tambah Barang', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                      ]),
                      const SizedBox(height: 18),

                      // Nama (full width)
                      _largeField(
                        child: TextFormField(
                          controller: _namaController,
                          style: const TextStyle(fontSize: 16),
                          decoration: _inputDecoration(label: 'Nama Barang', prefix: const Icon(Icons.label)),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Model (stacked)
                      _largeField(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedJenis,
                          decoration: _inputDecoration(label: 'Model Barang', prefix: const Icon(Icons.devices)),
                          itemHeight: 56,
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                          items: _jenisList
                              .map((jenis) => DropdownMenuItem(value: jenis, child: Text(jenis, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedJenis = v),
                          validator: (v) => v == null ? 'Pilih model barang' : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Status (stacked)
                      _largeField(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _status,
                          decoration: _inputDecoration(label: 'Status', prefix: const Icon(Icons.info_outline)),
                          itemHeight: 56,
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                          items: ['masuk', 'keluar', 'rusak']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _status = v;
                              if (v == 'rusak') _tanggalKeluarController.clear();
                              if (v == 'keluar') _tanggalRusakController.clear();
                            });
                          },
                          validator: (v) => v == null ? 'Pilih status' : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dates row
                      Row(children: [
                        Expanded(
                          child: _largeField(
                            child: TextFormField(
                              controller: _tanggalController,
                              readOnly: true,
                              style: const TextStyle(fontSize: 16),
                              onTap: () => _pickDate(_tanggalController),
                              decoration: _inputDecoration(label: 'Tanggal Masuk', prefix: const Icon(Icons.calendar_today)),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _status == 'keluar'
                              ? _largeField(
                                  child: TextFormField(
                                    controller: _tanggalKeluarController,
                                    readOnly: true,
                                    style: const TextStyle(fontSize: 16),
                                    onTap: () => _pickDate(_tanggalKeluarController),
                                    decoration: _inputDecoration(label: 'Tanggal Keluar', prefix: const Icon(Icons.exit_to_app)),
                                    validator: (v) {
                                      if (_status == 'keluar' && (v == null || v.trim().isEmpty)) return 'Wajib diisi';
                                      return null;
                                    },
                                  ),
                                )
                              : _status == 'rusak'
                                  ? _largeField(
                                      child: TextFormField(
                                        controller: _tanggalRusakController,
                                        readOnly: true,
                                        style: const TextStyle(fontSize: 16),
                                        onTap: () => _pickDate(_tanggalRusakController),
                                        decoration: _inputDecoration(label: 'Tanggal Rusak', prefix: const Icon(Icons.report_problem)),
                                        validator: (v) {
                                          if (_status == 'rusak' && (v == null || v.trim().isEmpty)) return 'Wajib diisi';
                                          return null;
                                        },
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // No Inventaris + SN
                      Row(children: [
                        Expanded(
                          child: _largeField(
                            child: TextFormField(
                              controller: _noInventarisController,
                              style: const TextStyle(fontSize: 16),
                              decoration: _inputDecoration(label: 'No. Inventaris', prefix: const Icon(Icons.badge)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _largeField(
                            child: TextFormField(
                              controller: _snController,
                              style: const TextStyle(fontSize: 16),
                              decoration: _inputDecoration(label: 'Serial Number (SN)', prefix: const Icon(Icons.qr_code)),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // Keterangan
                      TextFormField(
                        controller: _keteranganController,
                        style: const TextStyle(fontSize: 15),
                        decoration: _inputDecoration(label: 'Keterangan', prefix: const Icon(Icons.note)),
                        minLines: 3,
                        maxLines: 5,
                      ),
                      const SizedBox(height: 22),

                      // Actions
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton.icon(
                              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                              label: Text(_saving ? 'Menyimpan...' : 'Simpan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mainColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _saving ? null : _simpanBarang,
                            ),
                          ),
                        ),
                      ]),
                    ]),
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
