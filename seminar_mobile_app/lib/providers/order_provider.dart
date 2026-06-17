import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class OrderProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Order> _orders = [];
  Order? _selectedOrder;
  bool _isLoading = false;
  String? _errorMessage;

  List<Order> get orders => _orders;

  List<Order> ordersForTab(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return _orders.where((o) => o.status == 'pending').toList();
      case 2:
        return _orders.where((o) => o.status == 'confirmed').toList();
      case 3:
        return _orders.where((o) => o.status == 'cancelled').toList();
      default:
        return _orders;
    }
  }
  Order? get selectedOrder => _selectedOrder;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Hapus semua data order dari memory (dipanggil saat logout)
  void clear() {
    _orders = [];
    _selectedOrder = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchOrders({String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await _apiService.getOrders(status: status);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchOrderDetail(int id) async {
    _isLoading = true;
    _selectedOrder = null;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedOrder = await _apiService.getOrderDetail(id);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Order?> bookTicket({
    required int ticketId,
    required int quantity,
    required String paymentMethod,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final order = await _apiService.createOrder(
        ticketId: ticketId,
        quantity: quantity,
        paymentMethod: paymentMethod,
      );
      await fetchOrders();
      return order;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelOrder(int orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final order = await _apiService.cancelOrder(orderId);
      _selectedOrder = order;
      await fetchOrders();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadPaymentProof({
    required int paymentId,
    required String imagePath,
    List<int>? imageBytes,
    String? filename,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.uploadPaymentProof(
        paymentId: paymentId,
        imagePath: imagePath,
        imageBytes: imageBytes,
        filename: filename,
      );

      if (_selectedOrder != null && _selectedOrder!.payment?.id == paymentId) {
        await fetchOrderDetail(_selectedOrder!.id);
      }

      await fetchOrders();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
