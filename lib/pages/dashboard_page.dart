import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/audit_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';
import 'loading_page.dart';
import 'data_barang_page.dart';
import 'admin_page.dart';
import 'summary_by_category_page.dart'; // <-- tambahkan import ini
import 'global_history_page.dart';
import '../widgets/custom_navbar.dart';


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  String _searchQuery = '';
  int _selectedNavIndex = 0;
  late AnimationController _fadeController;
  late Future<Map<String, int>> _statFuture;

  // Tambahkan variabel untuk filter status
  String _selectedStatus = 'Semua';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeController.forward();
    _statFuture = getStatistik();
  }

  bool _mounted = true;

  @override
  void dispose() {
    _mounted = false;
    _fadeController.dispose();
    super.dispose();
  }

  void _onNavTap(int idx) async {
    setState(() => _selectedNavIndex = idx);
    if (idx == 0) {
      Navigator.pushNamed(context, '/tambah');
    } else if (idx == 1) {
      Navigator.pushNamed(context, '/tambah-barang-keluar');
    } else if (idx == 2) {
      Navigator.pushNamed(context, '/tambah-barang-rusak');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _exportExcel() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .orderBy('createdAt', descending: true)
          .get();
      final data = snapshot.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        String tanggal = '-';
        if (d['tanggal'] != null) {
          if (d['tanggal'] is Timestamp) {
            final dt = (d['tanggal'] as Timestamp).toDate();
            tanggal =
                "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
          } else {
            tanggal = d['tanggal'].toString();
          }
        }
        return [
          d['nama'] ?? '',
          d['jenis'] ?? '',
          tanggal,
          d['jam_input'] ?? '',
          d['no_inventaris'] ?? '',
          d['jumlah']?.toString() ?? '',
          d['sn'] ?? '',
          d['status'] ?? '',
          d['keterangan'] ?? '',
        ];
      }).toList();

      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow([
        'Nama',
        'Jenis',
        'Tanggal',
        'Jam Input',
        'No Inventaris',
        'Jumlah',
        'SN',
        'Status',
        'Keterangan',
      ]);
      for (var row in data) {
        sheet.appendRow(row);
      }

      final fileBytes = excel.encode();
      if (fileBytes == null) throw Exception("Gagal encode file Excel");

      await FileSaver.instance.saveFile(
        name: "Laporan_Stok_Barang.xlsx",
        bytes: Uint8List.fromList(fileBytes),
        ext: "xlsx",
        mimeType: MimeType.other,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil export ke Excel')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export ke Excel: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color mainColor = Colors.teal.shade700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFB),
      appBar: AppBar(
        backgroundColor: mainColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'OpNameGo',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // HEADER (sliver)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: mainColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hi, IT DAOP 3',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        _getTodayDate(),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Statistik (sliver)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('items').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const LinearProgressIndicator();
                    }
                    final docs = snap.data!.docs;
                    int masuk = 0, keluar = 0, rusak = 0;
                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = (data['status'] ?? '').toString().toLowerCase();
                      if (status == 'masuk') masuk++;
                      if (status == 'keluar') keluar++;
                      if (status == 'rusak') rusak++;
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _AnimatedStatCard(label: 'Masuk', value: masuk, color: Colors.blue.shade700, icon: Icons.move_to_inbox),
                        _AnimatedStatCard(label: 'Keluar', value: keluar, color: Colors.orange.shade700, icon: Icons.outbox),
                        _AnimatedStatCard(label: 'Rusak', value: rusak, color: Colors.red.shade700, icon: Icons.warning_amber_rounded),
                      ],
                    );
                  },
                ),
              ),
            ),

            // MENU GRID + SEARCH + FILTER as one sliver block
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.1,
                      ),
                      children: [
                        _MenuButton(
                          icon: Icons.edit_note,
                          label: 'Data Barang',
                          color: Colors.blue.shade700,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoadingPage(nextPage: DataBarangPage()),
                              ),
                            );
                          },
                        ),
                        _MenuButton(
                          icon: Icons.outbox,
                          label: 'Barang Keluar',
                          color: Colors.orange.shade700,
                          onTap: () => Navigator.pushNamed(context, '/tambah-barang-keluar'),
                        ),
                        _MenuButton(
                          icon: Icons.warning_amber_rounded,
                          label: 'Barang Rusak',
                          color: Colors.red.shade700,
                          onTap: () => Navigator.pushNamed(context, '/tambah-barang-rusak'),
                        ),
                        _MenuButton(
                          icon: Icons.table_view,
                          label: 'Export Excel',
                          color: Colors.purple.shade700,
                          onTap: () {
                            Navigator.pushNamed(context, '/rekap-barang');
                          },
                        ),
                        _MenuButton(
                          icon: Icons.history,
                          label: 'Riwayat',
                          color: Colors.teal.shade700,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalHistoryPage()));
                          },
                        ),
                      ],
                    ),

                    // SEARCH
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(24),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Cari SN atau No Inventaris...',
                            prefixIcon: const Icon(Icons.search, color: Colors.teal),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          ),
                          onChanged: (value) {
                            if (_mounted) setState(() => _searchQuery = value.trim().toLowerCase());
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // FILTER STATUS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const Text(
                            'Filter Status:',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _selectedStatus,
                            borderRadius: BorderRadius.circular(12),
                            items: const [
                              DropdownMenuItem(value: 'Semua', child: Text('Semua')),
                              DropdownMenuItem(value: 'masuk', child: Text('Masuk')),
                              DropdownMenuItem(value: 'keluar', child: Text('Keluar')),
                              DropdownMenuItem(value: 'rusak', child: Text('Rusak')),
                            ],
                            onChanged: (val) {
                              if (val != null && _mounted) setState(() => _selectedStatus = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // LIST BARANG (sliver) - stream + sliver list so list can scroll full area
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('items')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return SliverToBoxAdapter(child: Center(child: Text('Gagal memuat data', style: TextStyle(color: Colors.red.shade700))));
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(child: SizedBox(height: 200, child: Center(child: CircularProgressIndicator())));
                }

                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>? ?? {};
                  final sn = (data['sn'] ?? '').toString().toLowerCase();
                  final noInventaris = (data['no_inventaris'] ?? '').toString().toLowerCase();
                  final status = (data['status'] ?? '').toString().toLowerCase();

                  final matchSearch = _searchQuery.isEmpty || sn.contains(_searchQuery) || noInventaris.contains(_searchQuery);
                  final matchStatus = _selectedStatus == 'Semua' || status == _selectedStatus.toLowerCase();
                  return matchSearch && matchStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Barang tidak ditemukan'))));
                }

                // bottom padding so last item not covered by navbar
                final bottomPad = kBottomNavigationBarHeight + 28 + MediaQuery.of(context).padding.bottom;

                return SliverPadding(
                  padding: EdgeInsets.only(bottom: bottomPad),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final doc = filtered[i];
                        final data = doc.data() as Map<String, dynamic>? ?? {};

                        String tanggalMasuk = '-';
                        String tanggalKeluar = '-';
                        String tanggalRusak = '-';

                        if (data['tanggal_masuk'] != null && data['tanggal_masuk'] is Timestamp) {
                          final dt = (data['tanggal_masuk'] as Timestamp).toDate();
                          tanggalMasuk = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
                        }
                        if (data['tanggal_keluar'] != null && data['tanggal_keluar'] is Timestamp) {
                          final dt = (data['tanggal_keluar'] as Timestamp).toDate();
                          tanggalKeluar = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
                        }
                        if (data['tanggal_rusak'] != null && data['tanggal_rusak'] is Timestamp) {
                          final dt = (data['tanggal_rusak'] as Timestamp).toDate();
                          tanggalRusak = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
                        }
                        if (tanggalRusak != '-') tanggalKeluar = '-';

                        final status = (data['status'] ?? '-').toString().toLowerCase();

                        Color statusColor;
                        switch (status) {
                          case 'masuk':
                            statusColor = Colors.green.shade600;
                            break;
                          case 'keluar':
                            statusColor = Colors.orange.shade700;
                            break;
                          case 'rusak':
                            statusColor = Colors.red.shade700;
                            break;
                          default:
                            statusColor = Colors.grey.shade600;
                        }

                        return _ExpandableCard(
                          title: data['nama'] ?? '-',
                          status: status,
                          statusColor: statusColor,
                          popupMenu: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  Navigator.pushNamed(context, '/edit-barang', arguments: {'id': doc.id, ...data, 'statusEditable': false});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Hapus'),
                                      content: const Text('Yakin ingin menghapus data ini?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    try {
                                      await AuditService.logItemHistory(
                                        itemId: doc.id,
                                        action: 'delete',
                                        details: {
                                          'nama': data['nama'],
                                          'status': data['status'],
                                          'no_inventaris': data['no_inventaris'],
                                        },
                                      );
                                    } catch (_) {}
                                    await FirebaseFirestore.instance.collection('items').doc(doc.id).delete();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data dihapus')));
                                  }
                                },
                              ),
                            ],
                          ),
                          detail: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 24,
                                runSpacing: 8,
                                children: [
                                  _InfoItem(label: 'Model Barang', value: data['jenis'] ?? '-'),
                                  _InfoItem(label: 'Tanggal Masuk', value: tanggalMasuk),
                                  if (tanggalRusak != '-')
                                    _InfoItem(label: 'Tanggal Rusak', value: tanggalRusak)
                                  else
                                    _InfoItem(label: 'Tanggal Keluar', value: tanggalKeluar),
                                  _InfoItem(label: 'No. Inventaris', value: data['no_inventaris'] ?? '-'),
                                  _InfoItem(label: 'Serial Number (SN)', value: data['sn'] ?? '-'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Keterangan: ${data['keterangan'] ?? '-'}', style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomNavBar(),
    );
  }

  // Versi 1: getStatistik berdasarkan jumlah dokumen (bukan jumlah field 'jumlah')
  Future<Map<String, int>> getStatistik() async {
    final snapshot = await FirebaseFirestore.instance.collection('items').get();
    int masuk = 0, keluar = 0, rusak = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'masuk') masuk++;
      if (status == 'keluar') keluar++;
      if (status == 'rusak') rusak++;
    }
    return {'masuk': masuk, 'keluar': keluar, 'rusak': rusak};
  }

  String _getTodayDate() {
    final now = DateTime.now();
    const hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    const bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    final hariStr = hari[(now.weekday - 1) % 7];
    final bulanStr = bulan[(now.month - 1) % 12];
    return '$hariStr, ${now.day.toString().padLeft(2, '0')} $bulanStr ${now.year}';
  }
}

// Widget statistik dengan animasi angka
class _AnimatedStatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _AnimatedStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      builder: (context, val, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
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
                '$val',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 14, color: color),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Widget jam real-time
class _RealtimeClock extends StatefulWidget {
  final TextStyle textStyle;
  final TextStyle dateStyle;
  const _RealtimeClock({required this.textStyle, required this.dateStyle});

  @override
  State<_RealtimeClock> createState() => _RealtimeClockState();
}

class _RealtimeClockState extends State<_RealtimeClock> {
  late DateTime _now;
  late final StreamSubscription<int> _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Stream.periodic(const Duration(seconds: 1), (count) => count)
        .listen((_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getHari(int weekday) {
    const hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    return hari[(weekday - 1) % 7];
  }

  String _getBulan(int month) {
    const bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return bulan[(month - 1) % 12];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}',
          style: widget.textStyle,
        ),
        const SizedBox(height: 4),
        Text(
          '${_getHari(_now.weekday)}, ${_now.day.toString().padLeft(2, '0')} ${_getBulan(_now.month)} ${_now.year}',
          style: widget.dateStyle,
        ),
      ],
    );
  }
}

// Tombol menu grid
class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget untuk menampilkan informasi dalam bentuk label dan value
class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.teal.shade700,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// Widget kartu expandable untuk menampilkan detail barang
class _ExpandableCard extends StatefulWidget {
  final String title;
  final String status;
  final Color statusColor;
  final Widget detail;
  final Widget popupMenu;

  const _ExpandableCard({
    required this.title,
    required this.status,
    required this.statusColor,
    required this.detail,
    required this.popupMenu,
  });

  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<_ExpandableCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: widget.statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(
                widget.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: widget.statusColor,
                ),
              ),
              subtitle: Text(
                widget.status.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: widget.statusColor,
                ),
              ),
              trailing: widget.popupMenu,
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
          ),

          // Detail
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isExpanded ? widget.detail : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
