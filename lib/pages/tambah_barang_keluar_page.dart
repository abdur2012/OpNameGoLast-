// ignore_for_file: unnecessary_cast

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/audit_service.dart';
import '../widgets/custom_navbar.dart';
import 'data_barang_page.dart';

class TambahBarangKeluarPage extends StatefulWidget {
  const TambahBarangKeluarPage({super.key});

  @override
  State<TambahBarangKeluarPage> createState() => _TambahBarangKeluarPageState();
}

class _TambahBarangKeluarPageState extends State<TambahBarangKeluarPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedDocId;
  String? _jenisBarang;
  String? _noInventaris;
  String? _snBarang;
  String _search = '';
  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _jenisController = TextEditingController();
  final TextEditingController _noInventarisController = TextEditingController();
  final TextEditingController _snController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  bool _saving = false;

  Widget buildLoadingDialog() {
    final mainColor = Colors.teal.shade700;
    return Dialog(
      backgroundColor: mainColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              backgroundColor: Colors.teal.shade200,
              strokeWidth: 5,
            ),
            const SizedBox(height: 24),
            Text(
              'Memuat data...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
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

  Future<void> _simpanBarang() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih nama barang terlebih dahulu')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => buildLoadingDialog(),
    );

    try {
      final tanggalKeluar = DateTime.parse(_tanggalController.text.trim());

      // Update data barang yang dipilih
      await FirebaseFirestore.instance
          .collection('items')
          .doc(_selectedDocId)
          .update({
            'status': 'keluar',
            'tanggal_keluar': Timestamp.fromDate(tanggalKeluar),
            'keterangan': _keteranganController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Log history (best-effort)
      try {
        await AuditService.logItemHistory(
          itemId: _selectedDocId!,
          action: 'status_change',
          details: {
            'new_status': 'keluar',
            'tanggal_keluar': tanggalKeluar.toIso8601String(),
            'keterangan': _keteranganController.text.trim(),
          },
        );
      } catch (_) {}

      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barang keluar berhasil disimpan')),
        );
        // Navigate to Data Barang page, replacing current route
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DataBarangPage()));
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  // Tambahkan fungsi untuk mengambil riwayat barang keluar dari Firestore
  Future<List<Map<String, dynamic>>> _fetchHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('history')
          .where('itemId', isEqualTo: _selectedDocId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat riwayat: $e')),
        );
      }
      return [];
    }
  }

  // Tambahkan widget untuk menampilkan riwayat
  Widget _buildHistorySection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Tidak ada riwayat.'));
        }

        final history = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final entry = history[index];
            return ListTile(
              title: Text(entry['action'] ?? 'Perubahan'),
              subtitle: Text(entry['details']?.toString() ?? ''),
              trailing: Text(entry['timestamp']?.toDate()?.toString() ?? ''),
            );
          },
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
        backgroundColor: mainColor,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'Tambah Barang Keluar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1,
          ),
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
                      // Search SN/No Inventaris
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Cari SN atau No Inventaris',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (v) =>
                            setState(() => _search = v.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 16),
                      // Dropdown Barang (diganti dengan bottom-sheet selector agar tidak overflow)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('items')
                            .where('status', isEqualTo: 'masuk')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final docs = snapshot.data!.docs;

                          // Filter berdasarkan input pencarian atas
                          final filtered = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final sn = (data['sn'] ?? '')
                                .toString()
                                .toLowerCase();
                            final noInventaris = (data['no_inventaris'] ?? '')
                                .toString()
                                .toLowerCase();
                            final nama = (data['nama'] ?? '')
                                .toString()
                                .toLowerCase();
                            return _search.isEmpty ||
                                sn.contains(_search) ||
                                noInventaris.contains(_search) ||
                                nama.contains(_search);
                          }).toList();

                          // Reset selection bila tidak ada
                          if (_selectedDocId != null &&
                              !filtered.any(
                                (doc) => doc.id == _selectedDocId,
                              )) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                _selectedDocId = null;
                                _jenisController.clear();
                                _noInventarisController.clear();
                                _snController.clear();
                              });
                            });
                          }

                          return GestureDetector(
                            onTap: () async {
                              final selectedId = await showModalBottomSheet<String>(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                builder: (ctx) {
                                  // pastikan bottom sheet responsif terhadap keyboard dengan padding viewInsets
                                  String query = _search;
                                  final list = filtered;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: MediaQuery.of(
                                        ctx,
                                      ).viewInsets.bottom,
                                    ),
                                    child: DraggableScrollableSheet(
                                      initialChildSize: 0.60,
                                      minChildSize: 0.30,
                                      maxChildSize: 0.95,
                                      expand: false,
                                      builder: (sheetCtx, scrollController) {
                                        return StatefulBuilder(
                                          builder: (c, setModalState) {
                                            final shown = list.where((doc) {
                                              final data =
                                                  doc.data()
                                                      as Map<String, dynamic>;
                                              final nama = (data['nama'] ?? '')
                                                  .toString()
                                                  .toLowerCase();
                                              final sn = (data['sn'] ?? '')
                                                  .toString()
                                                  .toLowerCase();
                                              final noInv =
                                                  (data['no_inventaris'] ?? '')
                                                      .toString()
                                                      .toLowerCase();
                                              return query.isEmpty ||
                                                  nama.contains(query) ||
                                                  sn.contains(query) ||
                                                  noInv.contains(query);
                                            }).toList();

                                            return Container(
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                      top: Radius.circular(16),
                                                    ),
                                              ),
                                              child: Column(
                                                children: [
                                                  const SizedBox(height: 12),
                                                  Container(
                                                    width: 40,
                                                    height: 4,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade300,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 12,
                                                        ),
                                                  
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Expanded(
                                                    child: shown.isEmpty
                                                        ? Center(
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    24.0,
                                                                  ),
                                                              child: Text(
                                                                'Tidak ada data',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .black54,
                                                                ),
                                                              ),
                                                            ),
                                                          )
                                                        : ListView.separated(
                                                            controller:
                                                                scrollController,
                                                            shrinkWrap: true,
                                                            itemCount:
                                                                shown.length,
                                                            separatorBuilder:
                                                                (
                                                                  _,
                                                                  __,
                                                                ) => Divider(
                                                                  height: 1,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade200,
                                                                ),
                                                            itemBuilder: (context, i) {
                                                              final doc =
                                                                  shown[i];
                                                              final data =
                                                                  doc.data()
                                                                      as Map<
                                                                        String,
                                                                        dynamic
                                                                      >;
                                                              return ListTile(
                                                                title: Text(
                                                                  data['nama'] ??
                                                                      '-',
                                                                  style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                                subtitle: Text(
                                                                  'SN: ${data['sn'] ?? '-'} • Inv: ${data['no_inventaris'] ?? '-'}',
                                                                ),
                                                                onTap: () async {
                                                                  Navigator.of(
                                                                    ctx,
                                                                  ).pop(doc.id);

                                                                  final selectedData =
                                                                      doc.data()
                                                                          as Map<
                                                                            String,
                                                                            dynamic
                                                                          >;
                                                                  final selectedNoInv =
                                                                      selectedData['no_inventaris']
                                                                          ?.toString() ??
                                                                      '';

                                                                  // Ambil ulang dari Firestore berdasarkan no_inventaris
                                                                  final snapshot = await FirebaseFirestore
                                                                      .instance
                                                                      .collection(
                                                                        'items',
                                                                      )
                                                                      .where(
                                                                        'no_inventaris',
                                                                        isEqualTo:
                                                                            selectedNoInv,
                                                                      )
                                                                      .limit(1)
                                                                      .get();

                                                                  if (snapshot
                                                                      .docs
                                                                      .isNotEmpty) {
                                                                    final d =
                                                                        snapshot.docs.first.data()
                                                                            as Map<
                                                                              String,
                                                                              dynamic
                                                                            >;
                                                                    if (mounted) {
                                                                      setState(() {
                                                                        _selectedDocId = snapshot
                                                                            .docs
                                                                            .first
                                                                            .id;
                                                                        _jenisBarang =
                                                                            d['jenis']?.toString();
                                                                        _noInventaris =
                                                                            d['no_inventaris']?.toString();
                                                                        _snBarang =
                                                                            d['sn']?.toString();

                                                                        _jenisController.text =
                                                                            _jenisBarang ??
                                                                            '';
                                                                        _noInventarisController.text =
                                                                            _noInventaris ??
                                                                            '';
                                                                        _snController.text =
                                                                            _snBarang ??
                                                                            '';
                                                                      });
                                                                    }
                                                                  }
                                                                },
                                                              );
                                                            },
                                                          ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  );
                                },
                              );

                              if (selectedId != null) {
                                // ambil data terpilih dari original list (atau firestore jika perlu)
                                final selDoc = filtered.firstWhere(
                                  (d) => d.id == selectedId,
                                  orElse: () => filtered.first as QueryDocumentSnapshot<Map<String, dynamic>>,
                                );
                                final data =
                                    (selDoc.data() as Map<String, dynamic>?) ??
                                    {};
                                setState(() {
                                  _selectedDocId = selectedId;
                                  _jenisBarang = data['jenis']?.toString();
                                  _noInventaris = data['no_inventaris']
                                      ?.toString();
                                  _snBarang = data['sn']?.toString();
                                  _jenisController.text = _jenisBarang ?? '';
                                  _noInventarisController.text =
                                      _noInventaris ?? '';
                                  _snController.text = _snBarang ?? '';
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Pilih Barang',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                              ),
                              child: _selectedDocId == null
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: const [
                                        Text(
                                          'Pilih barang',
                                          style: TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                        Icon(
                                          Icons.keyboard_arrow_down,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _jenisController.text.isNotEmpty
                                              ? _jenisController.text
                                              : (_snBarang ?? '-'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'SN: ${_snController.text} • Inv: ${_noInventarisController.text}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Model Barang (disabled)
                      TextFormField(
                        controller: _jenisController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Model Barang',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // No Inventaris (disabled)
                      TextFormField(
                        controller: _noInventarisController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'No. Inventaris',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Serial Number (SN) (disabled)
                      TextFormField(
                        controller: _snController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Serial Number (SN)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tanggal Keluar
                      TextFormField(
                        controller: _tanggalController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Tanggal Keluar',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onTap: _pickDate,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      // Field Keterangan (tidak wajib diisi)
                      TextFormField(
                        controller: _keteranganController,
                        decoration: InputDecoration(
                          labelText: 'Keterangan (Opsional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 28),

                      // Tambahkan bagian riwayat di bawah form
                      const Text(
                        'Riwayat Barang Keluar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildHistorySection(),

                      const SizedBox(height: 28),

                      // Tombol Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: _saving
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Simpan Barang Keluar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          onPressed: _saving ? null : _simpanBarang,
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
