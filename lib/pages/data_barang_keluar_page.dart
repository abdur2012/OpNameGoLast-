import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_navbar.dart';

class DataBarangPageKeluar extends StatelessWidget {
  const DataBarangPageKeluar({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Barang Keluar', style: TextStyle(color: Colors.white)),
      ),
       bottomNavigationBar: CustomNavBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('barang_keluar') // 🔹 koleksi barang keluar
            .orderBy('tanggal', descending: true) // urut terbaru dulu
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Belum ada data barang keluar'));
          }

          final data = snapshot.data!.docs;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('No')),
                DataColumn(label: Text('Nama Barang')),
                DataColumn(label: Text('Jumlah')),
                DataColumn(label: Text('Tanggal')),
              ],
              rows: List.generate(data.length, (index) {
                final barang = data[index];
                return DataRow(
                  cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(Text(barang['nama'] ?? '')),
                    DataCell(Text('${barang['jumlah']}')),
                    DataCell(Text(barang['tanggal'] ?? '')),
                  ],
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
