import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../core/constants.dart';
import 'seminar_form_screen.dart';
import 'ticket_management_screen.dart';

class SeminarManagementScreen extends StatefulWidget {
  const SeminarManagementScreen({super.key});

  @override
  State<SeminarManagementScreen> createState() =>
      _SeminarManagementScreenState();
}

class _SeminarManagementScreenState extends State<SeminarManagementScreen> {
  final ApiService _apiService = ApiService();
  List<Seminar> _seminars = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSeminars();
  }

  Future<void> _loadSeminars() async {
    setState(() => _isLoading = true);
    try {
      final seminars = await _apiService.getSeminars();
      setState(() => _seminars = seminars);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSeminar(int id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Seminar'),
        content: Text('Yakin ingin menghapus "$title"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.deleteSeminar(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Seminar berhasil dihapus'),
              backgroundColor: Colors.green),
        );
      }
      _loadSeminars();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Widget _buildBanner(Seminar seminar) {
    final imageUrl = AppConstants.buildMediaUrl(seminar.banner);

    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: Image.network(
          imageUrl,
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildBannerPlaceholder(seminar.title),
        ),
      );
    }
    return _buildBannerPlaceholder(seminar.title);
  }

  Widget _buildBannerPlaceholder(String title) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo, Colors.indigoAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Seminar',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SeminarFormScreen()),
          );
          if (result == true) _loadSeminars();
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Seminar'),
        backgroundColor: Colors.indigo,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSeminars,
              child: _seminars.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text('Belum ada seminar.',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _seminars.length,
                      itemBuilder: (context, index) {
                        final seminar = _seminars[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Banner
                              _buildBanner(seminar),
                              // Info
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(seminar.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    if (seminar.speaker.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.record_voice_over,
                                              size: 12, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              seminar.speaker,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today,
                                            size: 12, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(seminar.date,
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12)),
                                        const SizedBox(width: 12),
                                        Icon(
                                          seminar.isOnline
                                              ? Icons.videocam
                                              : Icons.location_on,
                                          size: 12,
                                          color: Colors.teal,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          seminar.isOnline
                                              ? 'Online'
                                              : 'Offline',
                                          style: const TextStyle(
                                              color: Colors.teal, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Action buttons
                              const Divider(height: 1),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              TicketManagementScreen(
                                                  seminar: seminar),
                                        ),
                                      ),
                                      icon: const Icon(
                                          Icons.confirmation_number,
                                          size: 16),
                                      label: const Text('Tiket'),
                                      style: TextButton.styleFrom(
                                          foregroundColor: Colors.teal),
                                    ),
                                  ),
                                  const VerticalDivider(width: 1),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SeminarFormScreen(
                                                seminar: seminar),
                                          ),
                                        );
                                        if (result == true) _loadSeminars();
                                      },
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Edit'),
                                      style: TextButton.styleFrom(
                                          foregroundColor: Colors.indigo),
                                    ),
                                  ),
                                  const VerticalDivider(width: 1),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _deleteSeminar(seminar.id, seminar.title),
                                      icon: const Icon(Icons.delete, size: 16),
                                      label: const Text('Hapus'),
                                      style: TextButton.styleFrom(
                                          foregroundColor: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
