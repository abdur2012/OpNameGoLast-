import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/audit_service.dart';
import '../widgets/custom_navbar.dart';
import 'data_barang_page.dart';

class EditBarangPage extends StatefulWidget {
  const EditBarangPage({super.key});

  @override
  State<EditBarangPage> createState() => _EditBarangPageState();
}

class _EditBarangPageState extends State<EditBarangPage> {
  final _formKey = GlobalKey<FormState>();

  final _namaController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _tanggalKeluarController = TextEditingController();
  final _tanggalRusakController = TextEditingController();
  final _noInventarisController = TextEditingController();
  final _snController = TextEditingController();
  final _keteranganController = TextEditingController();
  
  String? _selectedJenis;
  String? _status;
  bool _initDone = false;
  bool _statusEditable = true;
  // kontrol apakah field Tanggal Keluar boleh diedit. Default: false (tidak bisa diedit)
  bool _tanggalKeluarEditable = false;
  late String docId;

  List<String> _jenisList = [
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

  // fallback defaults (kept for offline/fallback)
  final List<String> _defaultJenis = [
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

  @override
  void initState() {
    super.initState();
    _loadJenisFromFirestore();
  }

  Future<void> _loadJenisFromFirestore() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('item_models').orderBy('name').get();
      if (snap.docs.isNotEmpty) {
        final remote = snap.docs.map((d) => (d.data()['name'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
        // merge remote list with existing, keeping unique values and preserving order
        final merged = <String>[];
        for (final s in remote) {
          if (!merged.contains(s)) merged.add(s);
        }
        for (final s in _jenisList) {
          if (!merged.contains(s)) merged.add(s);
        }
        _jenisList = merged;
      } else {
        _jenisList = List.from(_defaultJenis);
      }

      // ensure selected value is present
      if (_selectedJenis != null && !_jenisList.contains(_selectedJenis)) {
        _jenisList.insert(0, _selectedJenis!);
      }

      if (mounted) setState(() {});
    } catch (e) {
      // fallback to defaults on error
      _jenisList = List.from(_defaultJenis);
      if (_selectedJenis != null && !_jenisList.contains(_selectedJenis)) {
        _jenisList.insert(0, _selectedJenis!);
      }
      if (mounted) setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    final argsRaw = route?.settings.arguments;
    Map<String, dynamic> args = {};
    if (argsRaw is Map<String, dynamic>) {
      args = argsRaw;
    } else {
      // Jika tidak ada arguments, tampilkan error dan kembali
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data barang tidak ditemukan.')),
        );
        Navigator.of(context).pop();
      });
      return;
    }

    // guard initialization so subsequent didChangeDependencies calls (caused by rebuilds)
    // don't overwrite runtime user changes (like _status) before save.
      if (!_initDone) {
      // ignore: avoid_print
      print('EditBarangPage: didChangeDependencies init');
      docId = args['id'];
      _namaController.text = args['nama'] ?? '';
      // normalize jenis to a non-empty string or null
      final rawJenis = args['jenis'];
      _selectedJenis = (rawJenis == null || rawJenis.toString().trim().isEmpty) ? null : rawJenis.toString();
      // ensure dropdown items contain the current jenis value to avoid Dropdown assertions
      if (_selectedJenis != null && !_jenisList.contains(_selectedJenis)) {
        _jenisList.insert(0, _selectedJenis!);
      }
      _noInventarisController.text = args['no_inventaris'] ?? '';
      _snController.text = args['sn'] ?? '';
      _keteranganController.text = args['keterangan'] ?? '';
      // normalize status to lowercase to match dropdown item values
      _status = (args['status'] ?? '').toString().toLowerCase();
      // statusEditable flag: default true (admin). If passed false, status cannot be changed by user
      if (args.containsKey('statusEditable')) {
        _statusEditable = args['statusEditable'] == true;
      }
      _initDone = true;
    }

    // Tanggal Masuk
    final tanggalMasuk = args['tanggal_masuk'];
    if (tanggalMasuk is Timestamp) {
      final d = tanggalMasuk.toDate();
      _tanggalController.text =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    } else if (tanggalMasuk is String) {
      _tanggalController.text = tanggalMasuk;
    }

    // Tanggal Keluar
    final tanggalKeluar = args['tanggal_keluar'];
    if (tanggalKeluar is Timestamp) {
      final d = tanggalKeluar.toDate();
      _tanggalKeluarController.text =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    } else if (tanggalKeluar is String) {
      _tanggalKeluarController.text = tanggalKeluar;
    }

    // Tanggal Rusak
    final tanggalRusak = args['tanggal_rusak'];
    if (tanggalRusak is Timestamp) {
      final d = tanggalRusak.toDate();
      _tanggalRusakController.text =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    } else if (tanggalRusak is String) {
      _tanggalRusakController.text = tanggalRusak;
    }

    // (no jumlah/keterangan fields — each item is single quantity)

    // Ensure opposite status-specific controllers cleared on init to avoid stale data
    if (_status == 'rusak') {
      _tanggalKeluarController.clear();
    } else if (_status == 'keluar') {
      _tanggalRusakController.clear();
    } else {
      // status == 'masuk' or unspecified — clear both dates
      _tanggalKeluarController.clear();
      _tanggalRusakController.clear();
    }
  }

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
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _updateData() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // debug log for troubleshooting
      // ignore: avoid_print
      print('EditBarangPage: saving docId=$docId status=$_status');
      // also print relevant controller values to help debug
      // ignore: avoid_print
      print('EditBarangPage: tanggalKeluar="${_tanggalKeluarController.text}"');
      final Map<String, dynamic> updateData = {
        'nama': _namaController.text.trim(),
        'jenis': _selectedJenis ?? '',
        'no_inventaris': _noInventarisController.text.trim(),
        'sn': _snController.text.trim(),
        'keterangan': _keteranganController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Only include status in update payload when editing of status is allowed
      if (_statusEditable) {
        updateData['status'] = _status ?? '';
      }

      if (_tanggalController.text.trim().isNotEmpty) {
        try {
          final dt = DateTime.parse(_tanggalController.text.trim());
          updateData['tanggal_masuk'] = Timestamp.fromDate(dt);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Format Tanggal Masuk tidak valid')));
          return;
        }
      }

      if (_status == 'keluar') {
        // Only require/parse Tanggal Keluar when the field is editable.
        if (_tanggalKeluarEditable) {
          if (_tanggalKeluarController.text.trim().isNotEmpty) {
            try {
              final dt = DateTime.parse(_tanggalKeluarController.text.trim());
              updateData['tanggal_keluar'] = Timestamp.fromDate(dt);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Format Tanggal Keluar tidak valid')));
              return;
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Tanggal keluar wajib diisi untuk status KELUAR')));
            return;
          }
        }
        // no jumlah/keterangan stored (single item)
        updateData['tanggal_rusak'] = FieldValue.delete();
        // ensure rusak fields removed
        updateData['jumlah_rusak'] = FieldValue.delete();
        updateData['keterangan_rusak'] = FieldValue.delete();
      } else if (_status == 'rusak') {
        if (_tanggalRusakController.text.trim().isNotEmpty) {
          try {
            final dt = DateTime.parse(_tanggalRusakController.text.trim());
            updateData['tanggal_rusak'] = Timestamp.fromDate(dt);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Format Tanggal Rusak tidak valid')));
            return;
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Tanggal rusak wajib diisi untuk status RUSAK')));
          return;
        }
        // no jumlah/keterangan stored (single item)
        updateData['tanggal_keluar'] = FieldValue.delete();
        // ensure keluar fields removed
        updateData['jumlah_keluar'] = FieldValue.delete();
        updateData['keterangan_keluar'] = FieldValue.delete();
      } else {
        // clear any status-specific fields when back to 'masuk' or unspecified
        updateData['tanggal_keluar'] = FieldValue.delete();
        updateData['tanggal_rusak'] = FieldValue.delete();
        updateData['jumlah_keluar'] = FieldValue.delete();
        updateData['keterangan_keluar'] = FieldValue.delete();
        updateData['jumlah_rusak'] = FieldValue.delete();
        updateData['keterangan_rusak'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('items')
          .doc(docId)
          .update(updateData);

        // ignore: avoid_print
        print('EditBarangPage: update successful for $docId');

      // Log history (best-effort). Only include safe fields in details.
      try {
        // build audit details from controllers and parsed values (avoid FieldValue.delete sentinel)
        final details = <String, dynamic>{
          'nama': _namaController.text.trim(),
        };
        if (_statusEditable) {
          details['status'] = _status ?? '';
        }
        if (_status == 'keluar') {
          details['tanggal_keluar'] = _tanggalKeluarController.text.trim();
        } else if (_status == 'rusak') {
          details['tanggal_rusak'] = _tanggalRusakController.text.trim();
        }

        await AuditService.logItemHistory(itemId: docId, action: 'update', details: details);
      } catch (_) {}

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil diupdate')));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DataBarangPage()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal update data: $e')));
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w500),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Colors.teal.shade700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFB),
      appBar: AppBar(
        backgroundColor: mainColor,
        elevation: 2,
        title: const Text(
          'Edit Barang',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Nama & Model
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _namaController,
                                    decoration: _inputDecoration('Nama Barang'),
                                    validator: (value) => value == null ||
                                            value.isEmpty
                                        ? 'Wajib diisi'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true, // allow using full available width
                                    value: _selectedJenis,
                                    decoration: _inputDecoration('Model'),
                                    iconSize: 20,
                                    items: _jenisList.map((jenis) {
                                      return DropdownMenuItem(
                                        value: jenis,
                                        child: Text(jenis, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedJenis = val),
                                    validator: (v) => v == null || v.isEmpty ? 'Pilih model' : null,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Tanggal Masuk & Tanggal Keluar (selalu ditampilkan)
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _tanggalController,
                                    readOnly: true,
                                    decoration: _inputDecoration('Tanggal Masuk'),
                                    onTap: () => _pickDate(_tanggalController),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                        controller: _tanggalKeluarController,
                                        // make non-editable according to the new flag
                                        enabled: _tanggalKeluarEditable,
                                        readOnly: true,
                                        decoration: _inputDecoration('Tanggal Keluar'),
                                        onTap: () {
                                          if (_tanggalKeluarEditable) {
                                            _pickDate(_tanggalKeluarController);
                                          }
                                        },
                                        validator: (v) {
                                          // only validate when the field is editable by the user
                                          if (_status == 'keluar' && _tanggalKeluarEditable) {
                                            if (v == null || v.trim().isEmpty) return 'Wajib diisi untuk status KELUAR';
                                          }
                                          return null;
                                        },
                                      ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // No Inventaris, SN & Status
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _noInventarisController,
                                    decoration: _inputDecoration('No. Inventaris'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _snController,
                                    decoration: _inputDecoration('Serial Number (SN)'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _status,
                                    iconSize: 20,
                                    items: ['masuk', 'keluar', 'rusak']
                                        .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), overflow: TextOverflow.ellipsis)))
                                        .toList(),
                                    onChanged: _statusEditable
                                        ? (v) {
                                            setState(() {
                                              final prev = _status;
                                              _status = v?.toString();
                                              // debug when status changes
                                              // ignore: avoid_print
                                              print('EditBarangPage: status changed $prev -> $_status');
                                              // Clear opposite status-specific dates when switching
                                              if (_status == 'rusak') {
                                                _tanggalKeluarController.clear();
                                              } else if (_status == 'keluar') {
                                                _tanggalRusakController.clear();
                                              } else {
                                                // switched to 'masuk' — clear both dates
                                                _tanggalKeluarController.clear();
                                                _tanggalRusakController.clear();
                                              }
                                            });
                                          }
                                        : null,
                                    decoration: _inputDecoration('Status'),
                                    validator: (v) => v == null ? 'Pilih status' : null,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Informasi jika status tidak dapat diedit oleh user
                            if (!_statusEditable)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  'Status tidak dapat diubah.',
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),

                            // Conditional inputs when status == 'keluar' or 'rusak'
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _status == 'keluar'
                                  ? const SizedBox.shrink()
                                  : _status == 'rusak'
                                      ? Column(
                                          key: const ValueKey('rusak_fields'),
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            const SizedBox(height: 12),
                                            TextFormField(
                                              controller: _tanggalRusakController,
                                              readOnly: true,
                                              decoration: _inputDecoration('Tanggal Rusak'),
                                              onTap: () => _pickDate(_tanggalRusakController),
                                              validator: (v) {
                                                if (_status == 'rusak' && (v == null || v.trim().isEmpty)) return 'Wajib diisi untuk status RUSAK';
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                        )
                                      : const SizedBox.shrink(),
                            ),

                            TextFormField(
                              controller: _keteranganController,
                              decoration: _inputDecoration('Keterangan'),
                              maxLines: 2,
                            ),

                            const Spacer(),

                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _updateData,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Simpan Perubahan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mainColor,
                                foregroundColor: Colors.white,
                                minimumSize:
                                    const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Batal'),
                              style: OutlinedButton.styleFrom(
                                minimumSize:
                                    const Size(double.infinity, 50),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const CustomNavBar(),
    );
  }
}
