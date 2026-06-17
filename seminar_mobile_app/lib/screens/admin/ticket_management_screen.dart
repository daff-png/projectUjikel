import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

class TicketManagementScreen extends StatefulWidget {
  final Seminar seminar;
  const TicketManagementScreen({super.key, required this.seminar});

  @override
  State<TicketManagementScreen> createState() => _TicketManagementScreenState();
}

class _TicketManagementScreenState extends State<TicketManagementScreen> {
  final ApiService _apiService = ApiService();
  List<Ticket> _tickets = [];
  bool _isLoading = false;

  // Ticket type choices sesuai Django TICKET_TYPE_CHOICES
  static const _ticketTypes = [
    {'value': 'regular', 'label': 'Regular'},
    {'value': 'vip', 'label': 'VIP'},
    {'value': 'early_bird', 'label': 'Early Bird'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  int get _allocatedQuota =>
      _tickets.fold(0, (sum, ticket) => sum + ticket.quota);

  int get _remainingCapacity =>
      widget.seminar.maxParticipants - _allocatedQuota;

  int _otherTicketsQuota({Ticket? editing}) {
    return _tickets
        .where((t) => editing == null || t.id != editing.id)
        .fold(0, (sum, t) => sum + t.quota);
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final tickets = await _apiService.getTicketsBySeminar(widget.seminar.id);
      setState(() => _tickets = tickets);
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

  Future<void> _showTicketDialog({Ticket? ticket}) async {
    if (ticket == null && _remainingCapacity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Kuota sudah maksimal. Kurangi kuota tiket lain terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final priceController =
        TextEditingController(text: ticket?.price.toStringAsFixed(0) ?? '');
    final quotaController = TextEditingController(
      text: ticket?.quota.toString() ??
          (_remainingCapacity > 0 ? _remainingCapacity.toString() : '1'),
    );
    String selectedType = ticket?.ticketType ?? 'regular';
    bool isActive = ticket?.isActive ?? true;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    // Cek tipe yang sudah ada (tidak boleh duplikat per seminar)
    final existingTypes = _tickets
        .where((t) => ticket == null || t.id != ticket.id)
        .map((t) => t.ticketType)
        .toSet();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(ticket == null ? 'Tambah Tiket' : 'Edit Tiket'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tipe tiket
                  const Text('Tipe Tiket',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _ticketTypes.map((t) {
                      final isDisabled = existingTypes.contains(t['value']);
                      return DropdownMenuItem(
                        value: t['value'],
                        enabled: !isDisabled,
                        child: Text(
                          t['label']! +
                              (isDisabled ? ' (sudah ada)' : ''),
                          style: TextStyle(
                              color: isDisabled ? Colors.grey : null),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedType = val);
                      }
                    },
                    validator: (v) =>
                        v == null ? 'Pilih tipe tiket' : null,
                  ),
                  const SizedBox(height: 16),

                  // Harga
                  TextFormField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga (Rp)',
                      border: OutlineInputBorder(),
                      prefixText: 'Rp ',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Harga wajib diisi';
                      if (double.tryParse(v) == null) return 'Harus angka';
                      if (double.parse(v) < 0) return 'Harga tidak boleh negatif';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Kuota per tiket
                  TextFormField(
                    controller: quotaController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Kuota Tiket',
                      border: const OutlineInputBorder(),
                      helperText:
                          'Maks. seminar: ${widget.seminar.maxParticipants} | '
                          'Sisa alokasi: ${widget.seminar.maxParticipants - _otherTicketsQuota(editing: ticket)}',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Kuota wajib diisi';
                      final parsed = int.tryParse(v);
                      if (parsed == null) return 'Harus angka bulat';
                      if (parsed < 1) return 'Kuota minimal 1';
                      if (ticket != null && parsed < ticket.soldCount) {
                        return 'Kuota tidak boleh kurang dari terjual (${ticket.soldCount})';
                      }
                      final total = _otherTicketsQuota(editing: ticket) + parsed;
                      if (total > widget.seminar.maxParticipants) {
                        return 'Kuota sudah maksimal (maks. ${widget.seminar.maxParticipants})';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.indigo.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      'Total kuota semua tiket tidak boleh melebihi maks. peserta seminar (${widget.seminar.maxParticipants}). '
                      'Contoh: VIP 15 + Regular 15 = 30.',
                      style: const TextStyle(fontSize: 12, color: Colors.indigo),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status aktif
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tiket Aktif'),
                    subtitle: Text(isActive
                        ? 'Tiket bisa dibeli'
                        : 'Tiket tidak bisa dibeli'),
                    value: isActive,
                    activeColor: Colors.indigo,
                    onChanged: (val) =>
                        setDialogState(() => isActive = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      final quota = int.parse(quotaController.text.trim());
                      final totalQuota =
                          _otherTicketsQuota(editing: ticket) + quota;
                      if (totalQuota > widget.seminar.maxParticipants) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kuota sudah maksimal'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        final data = {
                          'seminar': widget.seminar.id,
                          'ticket_type': selectedType,
                          'price': priceController.text.trim(),
                          'quota': quota,
                          'is_active': isActive,
                        };
                        if (ticket == null) {
                          await _apiService.createTicket(data);
                        } else {
                          await _apiService.updateTicket(ticket.id, data);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadTickets();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ticket == null
                                  ? 'Tiket berhasil ditambahkan'
                                  : 'Tiket berhasil diperbarui'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: Colors.red[700],
                            ),
                          );
                        }
                      }
                    },
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Simpan',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTicket(int id, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Tiket'),
        content: Text('Yakin ingin menghapus tiket "$label"?'),
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
      await _apiService.deleteTicket(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tiket berhasil dihapus'),
              backgroundColor: Colors.green),
        );
      }
      _loadTickets();
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

  String _formatCurrency(double amount) {
    if (amount == 0) return 'Gratis';
    return NumberFormat.currency(
            locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'vip':
        return Colors.amber[700]!;
      case 'early_bird':
        return Colors.green[700]!;
      default:
        return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cek apakah semua tipe tiket sudah ada
    final existingTypes = _tickets.map((t) => t.ticketType).toSet();
    final canAddMore = existingTypes.length < _ticketTypes.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kelola Tiket',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.seminar.title,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      floatingActionButton: canAddMore
          ? FloatingActionButton.extended(
              onPressed: () => _showTicketDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Tiket'),
              backgroundColor: Colors.teal,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _remainingCapacity > 0
                        ? Colors.teal.withValues(alpha: 0.08)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _remainingCapacity > 0
                          ? Colors.teal.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.pie_chart_outline,
                        color: _remainingCapacity > 0
                            ? Colors.teal[700]
                            : Colors.orange[800],
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Alokasi kuota: $_allocatedQuota / ${widget.seminar.maxParticipants}'
                          '${_remainingCapacity > 0 ? ' (sisa $_remainingCapacity)' : ' (penuh)'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _remainingCapacity > 0
                                ? Colors.teal[800]
                                : Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
              onRefresh: _loadTickets,
              child: _tickets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.confirmation_number_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text('Belum ada tiket untuk seminar ini.',
                              style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          Text('Tap tombol + untuk menambah tiket.',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _tickets.length,
                      itemBuilder: (context, index) {
                        final ticket = _tickets[index];
                        final color = _typeColor(ticket.ticketType);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        ticket.ticketTypeDisplay,
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (!ticket.isActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text('Nonaktif',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11)),
                                      ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.indigo, size: 20),
                                      onPressed: () =>
                                          _showTicketDialog(ticket: ticket),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red, size: 20),
                                      onPressed: () => _deleteTicket(
                                          ticket.id,
                                          ticket.ticketTypeDisplay),
                                      tooltip: 'Hapus',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _infoItem(
                                        Icons.attach_money,
                                        'Harga',
                                        _formatCurrency(ticket.price),
                                        color,
                                      ),
                                    ),
                                    Expanded(
                                      child: _infoItem(
                                        Icons.people,
                                        'Kuota',
                                        '${ticket.quota}',
                                        Colors.grey[700]!,
                                      ),
                                    ),
                                    Expanded(
                                      child: _infoItem(
                                        Icons.check_circle_outline,
                                        'Tersisa',
                                        '${ticket.availableQuota}',
                                        ticket.availableQuota > 0
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
