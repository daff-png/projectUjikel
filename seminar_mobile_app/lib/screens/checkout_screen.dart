import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/order_provider.dart';
import 'order_detail_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Seminar seminar;
  final Ticket ticket;

  const CheckoutScreen({
    super.key,
    required this.seminar,
    required this.ticket,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _quantity = 1;
  String _selectedPaymentMethod = 'bank_transfer';

  final List<Map<String, String>> _paymentMethods = [
    {
      'id': 'bank_transfer',
      'name': 'Transfer Bank',
      'desc': 'Transfer via Virtual Account (BCA, Mandiri, BNI)',
      'icon': 'account_balance'
    },
    {
      'id': 'e_wallet',
      'name': 'E-Wallet',
      'desc': 'Bayar instan via GoPay, OVO, atau Dana',
      'icon': 'account_balance_wallet'
    },
    {
      'id': 'credit_card',
      'name': 'Kartu Kredit',
      'desc': 'Bayar via Visa, Mastercard, atau JCB',
      'icon': 'credit_card'
    },
  ];

  String _formatCurrency(double amount) {
    if (amount == 0.0) return 'Gratis';
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(amount);
  }

  void _submitOrder() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final order = await orderProvider.bookTicket(
      ticketId: widget.ticket.id,
      quantity: _quantity,
      paymentMethod: _selectedPaymentMethod,
    );

    if (order != null && mounted) {
      // Clear navigation history and open order details
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailScreen(orderId: order.id, justBooked: true),
        ),
        (route) => route.isFirst,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orderProvider.errorMessage ?? 'Gagal membuat pesanan.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalPrice = widget.ticket.price * _quantity;
    final orderProvider = Provider.of<OrderProvider>(context);
    final isLoading = orderProvider.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout Tiket'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Seminar info card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.seminar.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(widget.seminar.date, style: const TextStyle(color: Colors.grey)),
                        const SizedBox(width: 16),
                        const Icon(Icons.confirmation_number, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          widget.ticket.ticketTypeDisplay,
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quantity selector
            const Text(
              'Jumlah Tiket',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Text(
                      _formatCurrency(widget.ticket.price),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.indigo),
                      onPressed: _quantity > 1
                          ? () {
                              setState(() {
                                _quantity--;
                              });
                            }
                          : null,
                    ),
                    Text(
                      '$_quantity',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.indigo),
                      onPressed: _quantity < widget.ticket.availableQuota
                          ? () {
                              setState(() {
                                _quantity++;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Payment method selector
            const Text(
              'Metode Pembayaran',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _paymentMethods.length,
              itemBuilder: (context, index) {
                final method = _paymentMethods[index];
                final isSelected = _selectedPaymentMethod == method['id'];
                
                IconData iconData = Icons.payment;
                if (method['icon'] == 'account_balance') {
                  iconData = Icons.account_balance;
                } else if (method['icon'] == 'account_balance_wallet') {
                  iconData = Icons.account_balance_wallet;
                } else if (method['icon'] == 'credit_card') {
                  iconData = Icons.credit_card;
                }

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? Colors.indigo : Colors.grey[200]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: RadioListTile<String>(
                    value: method['id']!,
                    groupValue: _selectedPaymentMethod,
                    onChanged: (val) {
                      setState(() {
                        _selectedPaymentMethod = val!;
                      });
                    },
                    title: Text(
                      method['name']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(method['desc']!),
                    secondary: Icon(iconData, color: isSelected ? Colors.indigo : Colors.grey),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Total section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Pembayaran',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                Text(
                  _formatCurrency(totalPrice),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
              ],
            ),
            const SizedBox(height: 24),

            isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Bayar Sekarang',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
