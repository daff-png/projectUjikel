import 'package:flutter/material.dart';
import 'seminar_management_screen.dart';
import 'category_management_screen.dart';
import 'order_monitor_screen.dart';
import 'reports_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard Admin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'Kelola Konten',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 16),
            _buildMenuCard(
              context,
              icon: Icons.event,
              title: 'Kelola Seminar',
              subtitle: 'Tambah, edit, dan hapus seminar',
              color: Colors.indigo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SeminarManagementScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              icon: Icons.category,
              title: 'Kelola Kategori',
              subtitle: 'Tambah, edit, dan hapus kategori',
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoryManagementScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              icon: Icons.receipt_long,
              title: 'Monitor Pesanan',
              subtitle: 'Lihat semua transaksi & konfirmasi pembayaran',
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrderMonitorScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              icon: Icons.bar_chart,
              title: 'Statistik & Export',
              subtitle: 'Lihat chart dan salin link export PDF/XLSX',
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          radius: 28,
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
