import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

class OrderMonitorScreen extends StatefulWidget {
  const OrderMonitorScreen({super.key});

  @override
  State<OrderMonitorScreen> createState() => _OrderMonitorScreenState();
}

class _OrderMonitorScreenState extends State<OrderMonitorScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  List<Order> _allOrders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  List<Order> _ordersForTab(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return _allOrders.where((o) => o.status == 'pending').toList();
      case 2:
        return _allOrders.where((o) => o.status == 'confirmed').toList();
      case 3:
        return _allOrders.where((o) => o.status == 'cancelled').toList();
      default:
        return _allOrders;
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final orders = await _apiService.getAdminOrders();
      setState(() => _allOrders = orders);
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

  Future<void> _confirmPayment(Order order) async {
    if (order.payment == null) return;

    final paymentId = order.payment!.id;
    final currentStatus = order.payment!.status;

    // Tentukan opsi konfirmasi berdasarkan status saat ini
    String? selectedAction;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Konfirmasi Pembayaran\nOrder #${order.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${order.user}'),
            Text('Seminar: ${order.ticketInfo.seminarTitle}'),
            Text('Total: ${_formatCurrency(order.totalPrice)}'),
            Text('Status saat ini: ${order.payment!.statusDisplay}'),
            const SizedBox(height: 16),
            const Text('Ubah status pembayaran:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (currentStatus != 'paid')
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Konfirmasi Lunas'),
                onTap: () {
                  selectedAction = 'paid';
                  Navigator.pop(ctx);
                },
              ),
            if (currentStatus != 'failed')
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Tandai Gagal'),
                onTap: () {
                  selectedAction = 'failed';
                  Navigator.pop(ctx);
                },
              ),
            if (currentStatus == 'paid')
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.replay, color: Colors.orange),
                title: const Text('Refund'),
                onTap: () {
                  selectedAction = 'refunded';
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ],
      ),
    );

    if (selectedAction == null || !mounted) return;

    try {
      await _apiService.adminConfirmPayment(paymentId, selectedAction!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status pembayaran berhasil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadOrders();
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

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Color _paymentStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'failed':
      case 'refunded':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _buildOrderCard(Order order) {
    String formattedDate = order.orderDate;
    try {
      final parsed = DateTime.parse(order.orderDate).toLocal();
      formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(parsed);
    } catch (_) {}

    final paymentStatus = order.payment?.status ?? 'pending';
    final paymentStatusDisplay = order.payment?.statusDisplay ?? 'Menunggu';
    final hasProof = order.payment?.proofImage != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text('Order #${order.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                          fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(order.statusDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _statusColor(order.status))),
                ),
              ],
            ),
            const Divider(height: 16),

            // User & seminar info
            Row(
              children: [
                const Icon(Icons.person, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(order.user,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(order.ticketInfo.seminarTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                      '${order.quantity}x ${order.ticketInfo.ticketType}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Text(_formatCurrency(order.totalPrice),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                        fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),

            // Payment status row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _paymentStatusColor(paymentStatus)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasProof
                              ? Icons.receipt_long
                              : Icons.receipt_long_outlined,
                          size: 12,
                          color: _paymentStatusColor(paymentStatus),
                        ),
                        const SizedBox(width: 4),
                        Text(paymentStatusDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color:
                                    _paymentStatusColor(paymentStatus))),
                      ],
                    ),
                  ),
                  if (hasProof) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.image, size: 14, color: Colors.teal),
                    const SizedBox(width: 2),
                    const Text('Ada bukti',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 11, color: Colors.teal)),
                  ],
                  const SizedBox(width: 8),
                  Text(formattedDate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 11)),
                ],
              ),
            ),

            // Tombol konfirmasi (hanya jika ada payment dan status pending/ada bukti)
            if (order.payment != null &&
                order.status != 'cancelled') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmPayment(order),
                  icon: const Icon(Icons.verified, size: 16),
                  label: const Text('Kelola Pembayaran'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: const BorderSide(color: Colors.indigo),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor Pesanan',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.indigo,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Pending'),
            Tab(text: 'Sukses'),
            Tab(text: 'Batal'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: List.generate(4, (tabIndex) {
                final orders = _ordersForTab(tabIndex);
                return RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text('Tidak ada pesanan.',
                                  style:
                                      TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: orders.length,
                          itemBuilder: (context, index) =>
                              _buildOrderCard(orders[index]),
                        ),
                );
              }),
            ),
    );
  }
}
