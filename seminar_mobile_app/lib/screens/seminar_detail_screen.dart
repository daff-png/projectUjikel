import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/seminar_provider.dart';
import '../core/constants.dart';
import '../models/models.dart';
import 'checkout_screen.dart';

class SeminarDetailScreen extends StatefulWidget {
  final int seminarId;
  const SeminarDetailScreen({super.key, required this.seminarId});

  @override
  State<SeminarDetailScreen> createState() => _SeminarDetailScreenState();
}

class _SeminarDetailScreenState extends State<SeminarDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SeminarProvider>(context, listen: false)
          .fetchSeminarDetail(widget.seminarId);
    });
  }

  String _formatCurrency(double amount) {
    if (amount == 0.0) return 'Gratis';
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(amount);
  }

  Widget _buildImageHeader(Seminar seminar) {
    final imageUrl = AppConstants.buildMediaUrl(seminar.banner);

    return Stack(
      children: [
        imageUrl != null
            ? Image.network(
                imageUrl,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(seminar.title),
              )
            : _buildPlaceholder(seminar.title),
        Positioned(
          top: 16,
          left: 16,
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(String title) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo, Colors.indigoAccent, Colors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTicketCard(Ticket ticket, Seminar seminar) {
    final isInactive = !ticket.isActive;
    final isSoldOut = ticket.availableQuota <= 0;
    final isUnavailable = isInactive || isSoldOut;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUnavailable ? Colors.grey[300]! : Colors.indigo[100]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        ticket.ticketTypeDisplay.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isUnavailable ? Colors.grey : Colors.indigo[900],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isInactive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'NONAKTIF',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      else if (isSoldOut)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'SOLD OUT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(ticket.price),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isUnavailable ? Colors.grey : Colors.teal[700],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sisa Kuota: ${ticket.availableQuota} / ${ticket.quota}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: isUnavailable
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CheckoutScreen(
                            seminar: seminar,
                            ticket: ticket,
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Pesan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seminarProvider = Provider.of<SeminarProvider>(context);
    final seminar = seminarProvider.selectedSeminar;
    final isLoading = seminarProvider.isLoading;
    final errorMessage = seminarProvider.errorMessage;

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => seminarProvider.fetchSeminarDetail(widget.seminarId),
                        child: const Text('Coba Lagi'),
                      )
                    ],
                  ),
                )
              : seminar == null
                  ? const Center(child: Text('Data tidak ditemukan.'))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildImageHeader(seminar),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        seminar.categoryName ?? 'Kategori',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo[900],
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      seminar.isOnline ? Icons.videocam : Icons.location_on,
                                      color: Colors.teal,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      seminar.isOnline ? 'Online' : 'Offline',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  seminar.title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Date & Time Info
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      seminar.date,
                                      style: const TextStyle(color: Colors.black87),
                                    ),
                                    const SizedBox(width: 20),
                                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppConstants.formatTimeShort(seminar.time),
                                      style: const TextStyle(color: Colors.black87),
                                    ),
                                  ],
                                ),
                                if (seminar.speaker.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.record_voice_over,
                                          size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Speaker: ${seminar.speaker}',
                                          style: const TextStyle(
                                              color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text('Penyelenggara: ${seminar.organizerName}'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (seminar.locationUrl.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.link, size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          seminar.locationUrl,
                                          style: const TextStyle(color: Colors.blue),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Tentang Seminar',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  seminar.description,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Tiket Tersedia',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                seminar.tickets.isEmpty
                                    ? const Text('Tidak ada tiket yang tersedia untuk seminar ini.')
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: seminar.tickets.length,
                                        itemBuilder: (context, index) {
                                          return _buildTicketCard(seminar.tickets[index], seminar);
                                        },
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
