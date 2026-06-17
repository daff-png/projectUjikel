import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/order_provider.dart';
import '../core/constants.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  final bool justBooked;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.justBooked = false,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false)
          .fetchOrderDetail(widget.orderId);
    });
  }

  String _formatCurrency(double amount) {
    if (amount == 0.0) return 'Gratis';
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(amount);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
      );
      if (file != null) {
        setState(() {
          _selectedImage = file;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar: $e')),
      );
    }
  }

  void _uploadProof(int paymentId) async {
    if (_selectedImage == null) return;

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    List<int>? imageBytes;
    String? filename;
    if (kIsWeb) {
      imageBytes = await _selectedImage!.readAsBytes();
      filename = _selectedImage!.name;
    }

    final success = await orderProvider.uploadPaymentProof(
      paymentId: paymentId,
      imagePath: _selectedImage!.path,
      imageBytes: imageBytes,
      filename: filename,
    );

    if (success && mounted) {
      setState(() {
        _selectedImage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bukti pembayaran berhasil diunggah. Menunggu verifikasi admin.'),
          backgroundColor: Colors.green,
        ),
      );
      // Reload order details
      orderProvider.fetchOrderDetail(widget.orderId);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orderProvider.errorMessage ?? 'Gagal mengunggah bukti.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _cancelOrder() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content: const Text('Apakah Anda yakin ingin membatalkan pesanan tiket ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await orderProvider.cancelOrder(widget.orderId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan berhasil dibatalkan.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(orderProvider.errorMessage ?? 'Gagal membatalkan pesanan.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildPaymentInstructions(String method, double amount) {
    String detailInfo = '';
    String instructions = '';

    if (method == 'bank_transfer') {
      detailInfo = 'Virtual Account Mandiri: 8891-0812-3456-7890';
      instructions = '1. Masuk ke M-Banking Anda\n'
          '2. Pilih menu Transfer Virtual Account\n'
          '3. Masukkan nomor VA di atas\n'
          '4. Pastikan jumlah tagihan sesuai\n'
          '5. Upload bukti pembayaran di form bawah.';
    } else if (method == 'e_wallet') {
      detailInfo = 'QRIS E-Wallet (Gopay/OVO/Dana)';
      instructions = '1. Scan kode QRIS yang tersedia\n'
          '2. Masukkan nominal pembayaran sebesar ${_formatCurrency(amount)}\n'
          '3. Selesaikan pembayaran di aplikasi e-wallet Anda\n'
          '4. Simpan screenshot transaksi dan unggah sebagai bukti di bawah.';
    } else {
      detailInfo = 'Kartu Kredit (Visa/Mastercard)';
      instructions = 'Untuk pembayaran dengan Kartu Kredit, silakan selesaikan proses otentikasi di merchant gate.';
    }

    return Card(
      color: Colors.indigo[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Instruksi Pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
            ),
            const SizedBox(height: 8),
            Text(
              detailInfo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              instructions,
              style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final order = orderProvider.selectedOrder;
    final isLoading = orderProvider.isLoading;
    final errorMessage = orderProvider.errorMessage;

    // Check dates formatting
    String formattedOrderDate = '';
    if (order != null) {
      try {
        final parsed = DateTime.parse(order.orderDate).toLocal();
        formattedOrderDate = DateFormat('dd MMMM yyyy, HH:mm').format(parsed);
      } catch (_) {
        formattedOrderDate = order.orderDate;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await orderProvider.fetchOrderDetail(widget.orderId);
        },
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(child: Text('Error: $errorMessage'))
                : order == null
                    ? const Center(child: Text('Data tidak ditemukan.'))
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.justBooked)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Pemesanan Berhasil! Silakan lakukan pembayaran agar kuota Anda aman.',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),

                            // Main booking summary card
                            Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Order ID: #${order.id}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(order.status).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            order.statusDisplay,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _getStatusColor(order.status),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Dipesan pada: $formattedOrderDate',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                    ),
                                    const Divider(height: 24),
                                    Text(
                                      order.ticketInfo.seminarTitle,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Jenis Tiket: ${order.ticketInfo.ticketType.toUpperCase()}',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          '${order.quantity} x ${_formatCurrency(order.ticketInfo.price)}',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total Pembayaran',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Text(
                                          _formatCurrency(order.totalPrice),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Colors.indigo,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Payment instructions details
                            if (order.status == 'pending' && order.payment != null)
                              _buildPaymentInstructions(
                                order.payment!.paymentMethod,
                                order.totalPrice,
                              ),
                            const SizedBox(height: 20),

                            // Upload proof / Display payment proof section
                            if (order.payment != null) ...[
                              const Text(
                                'Status Pembayaran',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Metode: ${order.payment!.paymentMethodDisplay}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Status: ${order.payment!.statusDisplay}'),
                                      const SizedBox(height: 12),
                                      if (order.payment!.proofImage != null) ...[
                                        const Text('Bukti Pembayaran yang Diunggah:'),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            AppConstants.buildMediaUrl(order.payment!.proofImage) ?? '',
                                            height: 200,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                          ),
                                        ),
                                      ] else if (order.status == 'pending') ...[
                                        // Form to upload proof
                                        const Text('Anda belum mengunggah bukti pembayaran.'),
                                        const SizedBox(height: 12),
                                        if (_selectedImage != null) ...[
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: kIsWeb
                                                ? Image.network(
                                                    _selectedImage!.path,
                                                    height: 180,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Image.file(
                                                    File(_selectedImage!.path),
                                                    height: 180,
                                                    fit: BoxFit.cover,
                                                  ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _selectedImage = null;
                                                    });
                                                  },
                                                  child: const Text('Hapus'),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () => _uploadProof(order.payment!.id),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.indigo,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  child: const Text('Kirim Bukti'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else ...[
                                          OutlinedButton.icon(
                                            onPressed: _pickImage,
                                            icon: const Icon(Icons.photo_library),
                                            label: const Text('Unggah Bukti Transaksi'),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),

                            // Cancel button
                            if (order.status == 'pending')
                              OutlinedButton(
                                onPressed: _cancelOrder,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text(
                                  'Batalkan Pesanan',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
      ),
    );
  }
}
