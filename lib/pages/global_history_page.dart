import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalHistoryPage extends StatefulWidget {
  const GlobalHistoryPage({super.key});

  @override
  State<GlobalHistoryPage> createState() => _GlobalHistoryPageState();
}

class _GlobalHistoryPageState extends State<GlobalHistoryPage> {
  String _filter = 'All'; // All | Auth | Item

  String _formatTimestamp(dynamic ts) {
    try {
      if (ts == null) return '-';
      if (ts is Timestamp) return ts.toDate().toString();
      if (ts is DateTime) return ts.toString();
      return ts.toString();
    } catch (_) {
      return '-';
    }
  }

  Widget _actionIcon(String action, {String? eventType}) {
    // Use CircleAvatar with light background and clear icon for better visuals
    if (eventType == 'auth') {
      return CircleAvatar(
        backgroundColor: Colors.indigo.shade50,
        child: Icon(Icons.person, color: Colors.indigo.shade700),
      );
    }

    switch (action) {
      case 'create':
        return CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: Icon(Icons.add_box, color: Colors.green.shade700),
        );
      case 'update':
        return CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Icon(Icons.edit, color: Colors.blue.shade700),
        );
      case 'delete':
        return CircleAvatar(
          backgroundColor: Colors.red.shade50,
          child: Icon(Icons.delete_forever, color: Colors.red.shade700),
        );
      case 'status_change':
        return CircleAvatar(
          backgroundColor: Colors.orange.shade50,
          child: Icon(Icons.swap_horiz, color: Colors.orange.shade700),
        );
      case 'login_failed':
        return CircleAvatar(
          backgroundColor: Colors.amber.shade50,
          child: Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700),
        );
      default:
        return CircleAvatar(
          backgroundColor: Colors.grey.shade100,
          child: Icon(Icons.history, color: Colors.grey.shade700),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Keseluruhan', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal.shade700,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filter,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('Semua', style: TextStyle(color: Colors.black))),
                  DropdownMenuItem(value: 'Auth', child: Text('Auth (Login/Logout)', style: TextStyle(color: Colors.black))),
                  DropdownMenuItem(value: 'Item', child: Text('Item (Create/Update/Delete)', style: TextStyle(color: Colors.black))),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _filter = v);
                },
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                iconEnabledColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('history').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snap.data?.docs ?? [];

          // apply client-side filter
          final filteredDocs = docs.where((doc) {
            final d = doc.data() as Map<String, dynamic>? ?? {};
            final eventType = (d['eventType'] ?? '').toString();
            final hasItemId = d.containsKey('itemId') && (d['itemId'] ?? '').toString().isNotEmpty;
            if (_filter == 'Auth') return eventType == 'auth' || (d['action'] ?? '').toString().startsWith('login');
            if (_filter == 'Item') return eventType != 'auth' && hasItemId;
            return true;
          }).toList();

          if (filteredDocs.isEmpty) return const Center(child: Text('Belum ada riwayat.'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filteredDocs.length,
            separatorBuilder: (_, __) => const Divider(height: 8),
            itemBuilder: (context, i) {
              final d = filteredDocs[i].data() as Map<String, dynamic>? ?? {};
              final action = (d['action'] ?? '').toString();
              final user = (d['user'] ?? 'unknown').toString();
              final details = d['details'] ?? {};
              final timestamp = d['timestamp'];
              final itemId = d['itemId'] ?? '-';
              final eventType = (d['eventType'] ?? '').toString();

              final isAuth = eventType == 'auth' || action.startsWith('login') || action.startsWith('logout') || action.startsWith('login_failed');

              return ListTile(
                tileColor: isAuth ? Colors.indigo.shade50 : null,
                leading: _actionIcon(action, eventType: eventType.isEmpty ? null : eventType),
                title: Text(
                  isAuth ? '${action.toUpperCase()} • $user' : '${action.toUpperCase()} • $user',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    if (details is Map && details.isNotEmpty) Text('Detil: ${details.toString()}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    if (!isAuth) Text('Item ID: $itemId', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 6),
                    Text('Waktu: ${_formatTimestamp(timestamp)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
                isThreeLine: true,
                trailing: isAuth ? Chip(label: Text('AUTH', style: TextStyle(color: Colors.indigo.shade700))) : null,
              );
            },
          );
        },
      ),
    );
  }
}
