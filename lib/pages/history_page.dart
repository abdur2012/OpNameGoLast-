import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryPage extends StatelessWidget {
  final String itemId;
  final String? itemName;

  const HistoryPage({super.key, required this.itemId, this.itemName});

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

  Icon _actionIcon(String action) {
    switch (action) {
      case 'create':
        return const Icon(Icons.add, color: Colors.green);
      case 'update':
        return const Icon(Icons.edit, color: Colors.blue);
      case 'delete':
        return const Icon(Icons.delete, color: Colors.red);
      case 'status_change':
        return const Icon(Icons.sync_alt, color: Colors.orange);
      default:
        return const Icon(Icons.history, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = itemName != null ? 'Riwayat: $itemName' : 'Riwayat Item';
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('history')
            .where('itemId', isEqualTo: itemId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Belum ada riwayat untuk item ini.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 8),
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>? ?? {};
              final action = (d['action'] ?? '').toString();
              final user = (d['user'] ?? 'unknown').toString();
              final details = d['details'] ?? {};
              final timestamp = d['timestamp'];

              return ListTile(
                leading: _actionIcon(action),
                title: Text('${action.toUpperCase()} • $user', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    if (details is Map && details.isNotEmpty) Text('Detil: ${details.toString()}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('Waktu: ${_formatTimestamp(timestamp)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
