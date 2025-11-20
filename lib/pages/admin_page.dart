// admin_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  // Theme
  final Color _primary = Colors.teal.shade700;

  // Form
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _role = 'pegawai';
  bool _obscure = true;
  bool _saving = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // --- ADDED: scroll controller to scroll list when a new user is added ---
  final ScrollController _listScrollController = ScrollController();
  // --- END ADDED ---
  
  @override
  void dispose() {
    _namaController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    _listScrollController.dispose(); // dispose added controller
    super.dispose();
  }
  
  @override
  void initState() {
    super.initState();
    // Optional: listen to focus or other events if needed
  }
  
  Future<void> _tambahUser() async {
    if (!_formKey.currentState!.validate()) return;
    final nama = _namaController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _saving = true);
    try {
      // (email removed) no special admin restriction here — keep original behavior

      final byUsername = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (byUsername.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username sudah terdaftar')));
        setState(() => _saving = false);
        return;
      }

      await FirebaseFirestore.instance.collection('users').add({
        'nama': nama,
        'username': username,
        'password': password,
        'role': _role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // clear form and search, unfocus keyboard
      _namaController.clear();
      _usernameController.clear();
      _passwordController.clear();
      setState(() {
        _role = 'pegawai';
        _searchController.clear();
        _searchQuery = '';
      });
      FocusScope.of(context).unfocus();

      // small delay to allow local snapshot update, then scroll list to top so new item is visible
      // StreamBuilder will auto-refresh, this just improves UX
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_listScrollController.hasClients) {
          _listScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pegawai berhasil ditambahkan')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menambah pegawai: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _hapusUser(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Pegawai'),
        content: const Text('Yakin ingin menghapus pegawai ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('users').doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pegawai dihapus')));
      // jangan panggil setState di sini — StreamBuilder akan otomatis memperbarui list
    }
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.admin_panel_settings, color: _primary, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Manajemen Pegawai', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary)),
              const SizedBox(height: 6),
              const Text('Tambahkan, cari, atau hapus pegawai dengan mudah.', style: TextStyle(color: Colors.black54)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(children: [
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _namaController,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person), labelText: 'Nama lengkap'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.badge), labelText: 'Username'),
                  keyboardType: TextInputType.text,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Wajib' : null,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock),
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  validator: (v) => v == null || v.trim().length < 4 ? 'Minimal 4 karakter' : null,
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButton<String>(
                  value: _role,
                  underline: const SizedBox.shrink(),
                  // allow selecting admin at creation time, but logic will block if an admin already exists
                  items: ['pegawai', 'admin'].map((r) => DropdownMenuItem(value: r, child: Text(_capitalize(r)))).toList(),
                  onChanged: (v) => setState(() => _role = v ?? 'pegawai',
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add),
                  label: Text(_saving ? 'Menyimpan...' : 'Tambah Pegawai'),
                  style: ElevatedButton.styleFrom(backgroundColor: _primary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _saving ? null : _tambahUser,
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari nama atau username',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      // Tambahkan option untuk mengurangi refresh yang tidak perlu
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots(includeMetadataChanges: false), // Tambahkan ini
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('Gagal memuat data'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        
        // Filter perubahan yang hanya metadata
        if (snap.data!.metadata.isFromCache && snap.data!.docs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        final filtered = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final q = _searchQuery;
          if (q.isEmpty) return true;
          final nama = (data['nama'] ?? '').toString().toLowerCase();
          final username = (data['username'] ?? '').toString().toLowerCase();
          return nama.contains(q) || username.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Belum ada pegawai atau tidak ada hasil', 
                style: TextStyle(color: Colors.black54)
              )
            ),
          );
        }

        return ListView.builder( // Ganti ke ListView.builder untuk performa
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final doc = filtered[i];
            final data = doc.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, 
                    vertical: 10
                  ),
                  leading: CircleAvatar(
                    backgroundColor: _primary.withOpacity(0.12),
                    foregroundColor: _primary,
                    child: Text(
                      (data['nama'] ?? '-').toString().isNotEmpty ? 
                      (data['nama'] ?? '-').toString()[0].toUpperCase() : 
                      '?'
                    ),
                  ),
                  title: Text(
                    data['nama'] ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w700)
                  ),
                  subtitle: Text(
                    'Username: ${data['username'] ?? '-'}',
                    style: const TextStyle(height: 1.3)
                  ),
                  trailing: PopupMenuButton<String>(
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit')
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Hapus')
                      ),
                    ],
                    onSelected: (v) {
                      if (v == 'delete') _hapusUser(doc.id);
                      if (v == 'edit') _showEditUserDialog(doc.id, data);
                    },
                  ),
                  onTap: () => _showUserDetail(doc.id, data),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // new: show user details in bottom sheet
  void _showUserDetail(String id, Map<String, dynamic> data) {
    final createdRaw = data['createdAt'];
    String createdStr = '-';
    try {
      if (createdRaw != null) {
        if (createdRaw is Timestamp) {
          final dt = createdRaw.toDate();
          createdStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else if (createdRaw is DateTime) {
          final dt = createdRaw as DateTime;
          createdStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else {
          createdStr = createdRaw.toString();
        }
      }
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(radius: 30, backgroundColor: _primary.withOpacity(0.14), foregroundColor: _primary, child: Text((data['nama'] ?? '-').toString().isNotEmpty ? (data['nama'] ?? '-').toString()[0].toUpperCase() : '?', style: const TextStyle(fontSize: 20))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(data['nama'] ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('Role: ${_capitalize((data['role'] ?? '-').toString())}', style: const TextStyle(color: Colors.black54)),
                      ]),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _hapusUser(id);
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Hapus',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(title: const Text('Username'), subtitle: Text(data['username'] ?? '-')),
                ListTile(title: const Text('Password'), subtitle: Text(data['password'] ?? '-')),
                ListTile(title: const Text('Dibuat pada'), subtitle: Text(createdStr)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(backgroundColor: _primary),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditUserDialog(id, data);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      child: const Text('Tutup'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  // new: edit form in bottom sheet
  void _showEditUserDialog(String id, Map<String, dynamic> data) {
    final _editFormKey = GlobalKey<FormState>();
    final TextEditingController _eNama = TextEditingController(text: (data['nama'] ?? '').toString());
  // email removed per request
    final TextEditingController _eUsername = TextEditingController(text: (data['username'] ?? '').toString());
    final TextEditingController _ePassword = TextEditingController(text: (data['password'] ?? '').toString());
    String _eRole = (data['role'] ?? 'pegawai').toString();
    bool _eSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(builder: (contextSB, setStateSB) {
            Future<void> _saveEdit() async {
              if (!_editFormKey.currentState!.validate()) return;
              setStateSB(() => _eSaving = true);
              final newName = _eNama.text.trim();
              final newUsername = _eUsername.text.trim();
              final newPass = _ePassword.text;
              try {
                final qUsername = await FirebaseFirestore.instance
                    .collection('users')
                    .where('username', isEqualTo: newUsername)
                    .get();
                if (qUsername.docs.any((d) => d.id != id)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username sudah digunakan oleh akun lain')));
                  setStateSB(() => _eSaving = false);
                  return;
                }

                await FirebaseFirestore.instance.collection('users').doc(id).update({
                  'nama': newName,
                  'username': newUsername,
                  'password': newPass,
                  'role': _eRole,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data pegawai diperbarui')));
                Navigator.of(ctx).pop();
                // jangan panggil setState di sini — StreamBuilder akan otomatis memperbarui list
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan perubahan: $e')));
                }
              } finally {
                if (mounted) setStateSB(() => _eSaving = false);
              }
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 12),
                  Text('Edit Pegawai', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary)),
                  const SizedBox(height: 12),
                  Form(
                    key: _editFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _eNama,
                          decoration: const InputDecoration(labelText: 'Nama lengkap', prefixIcon: Icon(Icons.person)),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _eUsername,
                          decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.badge)),
                          keyboardType: TextInputType.text,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _ePassword,
                          decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                          obscureText: true,
                          validator: (v) => v == null || v.trim().length < 4 ? 'Minimal 4 karakter' : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Role:'),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: _eRole,
                              items: ['pegawai', 'admin'].map((r) => DropdownMenuItem(value: r, child: Text(_capitalize(r)))).toList(),
                              onChanged: (v) => setStateSB(() => _eRole = v ?? 'pegawai'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _eSaving ? null : _saveEdit,
                                style: ElevatedButton.styleFrom(backgroundColor: _primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                                child: _eSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan Perubahan'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                },
                                child: const Text('Batal'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFB),
      appBar: AppBar(
        title: const Text('Manajemen Pegawai', style: TextStyle(color: Colors.white)),
        backgroundColor: _primary,
        elevation: 0,
      ),
      // SafeArea + SingleChildScrollView avoids overflow when keyboard opens.
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _listScrollController, // <-- pasang controller di sini
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildForm(),
              const SizedBox(height: 12),
              _buildSearchBar(),
              const SizedBox(height: 8),
              // user list (shrink-wrapped) — no Expanded here to avoid overflow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: _buildUserList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
