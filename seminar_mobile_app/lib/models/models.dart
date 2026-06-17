// ============================================================
// Models — sesuai dengan Django serializers
// ============================================================

// Sesuai: UserSerializer (accounts/serializers.py)
class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String dateJoined;
  final String role; // dari UserProfile.role: 'admin' | 'user'

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.dateJoined,
    this.role = 'user',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      dateJoined: json['date_joined'] ?? '',
      role: json['role'] ?? 'user',
    );
  }

  bool get isAdmin => role == 'admin';

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? username : name;
  }
}

// Sesuai: CategorySerializer (seminars/serializers.py)
class Category {
  final int id;
  final String name;
  final String description;

  Category({required this.id, required this.name, required this.description});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

// Sesuai: TicketSerializer (seminars/serializers.py)
// Fields: id, seminar, ticket_type, price, quota, sold_count, available_quota, is_active
class Ticket {
  final int id;
  final int seminarId;
  final String ticketType; // raw value: 'regular' | 'vip' | 'early_bird'
  final double price;
  final int quota;
  final int soldCount;
  final int availableQuota; // @property dari model
  final bool isActive;

  Ticket({
    required this.id,
    required this.seminarId,
    required this.ticketType,
    required this.price,
    required this.quota,
    required this.soldCount,
    required this.availableQuota,
    required this.isActive,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] ?? 0,
      seminarId: json['seminar'] ?? 0,
      ticketType: json['ticket_type'] ?? 'regular',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      quota: json['quota'] ?? 0,
      soldCount: json['sold_count'] ?? 0,
      availableQuota: json['available_quota'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }

  // Display label sesuai TICKET_TYPE_CHOICES di Django
  String get ticketTypeDisplay {
    switch (ticketType) {
      case 'vip':
        return 'VIP';
      case 'early_bird':
        return 'Early Bird';
      case 'regular':
      default:
        return 'Regular';
    }
  }
}

// Sesuai: SeminarListSerializer & SeminarDetailSerializer (seminars/serializers.py)
// List: id, title, organizer(str), category(str), banner, date, time, is_online, max_participants
// Detail: semua field + organizer_name, tickets, description, location_url, category(id)
class Seminar {
  final int id;
  final String title;
  final String speaker;
  final String description; // kosong di list response
  final String
  organizer; // username (StringRelatedField di list, ReadOnlyField di detail)
  final String organizerName; // hanya ada di detail response
  final String?
  categoryName; // StringRelatedField di list → string nama kategori
  final int? categoryId; // ForeignKey id, ada di detail response
  final String? banner; // path relatif, null jika tidak ada
  final String date; // format: YYYY-MM-DD
  final String time; // format: HH:MM:SS
  final String locationUrl; // CharField, bisa kosong
  final bool isOnline;
  final int maxParticipants;
  final List<Ticket> tickets; // hanya ada di detail response

  Seminar({
    required this.id,
    required this.title,
    required this.speaker,
    required this.description,
    required this.organizer,
    required this.organizerName,
    this.categoryName,
    this.categoryId,
    this.banner,
    required this.date,
    required this.time,
    required this.locationUrl,
    required this.isOnline,
    required this.maxParticipants,
    required this.tickets,
  });

  factory Seminar.fromJson(Map<String, dynamic> json) {
    // Parse tickets (hanya ada di detail response)
    final ticketsList = <Ticket>[];
    if (json['tickets'] is List) {
      for (final t in json['tickets'] as List) {
        ticketsList.add(Ticket.fromJson(t));
      }
    }

    // category bisa berupa String (list), int (detail), atau null
    String? catName;
    int? catId;
    final cat = json['category'];
    if (cat is String) {
      catName = cat;
    } else if (cat is int) {
      catId = cat;
    } else if (cat is Map) {
      catId = cat['id'];
      catName = cat['name'];
    }

    return Seminar(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      speaker: json['speaker'] ?? '',
      description: json['description'] ?? '',
      organizer: json['organizer']?.toString() ?? '',
      organizerName:
          json['organizer_name'] ?? json['organizer']?.toString() ?? '',
      categoryName: catName,
      categoryId: catId,
      banner: json['banner'] as String?,
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      locationUrl: json['location_url'] ?? '',
      isOnline: json['is_online'] ?? true,
      maxParticipants: json['max_participants'] ?? 0,
      tickets: ticketsList,
    );
  }
}

// Sesuai: ticket_info di OrderListSerializer & OrderDetailSerializer
// Fields: seminar_title, ticket_type (display), price
class TicketInfo {
  final String seminarTitle;
  final String ticketType; // sudah display name dari get_ticket_type_display()
  final double price;

  TicketInfo({
    required this.seminarTitle,
    required this.ticketType,
    required this.price,
  });

  factory TicketInfo.fromJson(Map<String, dynamic> json) {
    return TicketInfo(
      seminarTitle: json['seminar_title'] ?? '',
      ticketType: json['ticket_type'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
    );
  }
}

// Sesuai: PaymentSerializer (orders/serializers.py)
// Fields: id, order, payment_method, amount, status, proof_image, payment_date, created_at
class Payment {
  final int id;
  final int orderId;
  final String paymentMethod; // 'bank_transfer' | 'e_wallet' | 'credit_card'
  final double amount;
  final String status; // 'pending' | 'paid' | 'failed' | 'refunded'
  final String? proofImage; // path relatif, null jika belum upload
  final String? paymentDate; // null jika belum dibayar
  final String createdAt;

  Payment({
    required this.id,
    required this.orderId,
    required this.paymentMethod,
    required this.amount,
    required this.status,
    this.proofImage,
    this.paymentDate,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] ?? 0,
      orderId: json['order'] ?? 0,
      paymentMethod: json['payment_method'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'pending',
      proofImage: json['proof_image'] as String?,
      paymentDate: json['payment_date'] as String?,
      createdAt: json['created_at'] ?? '',
    );
  }

  // Display label sesuai PAYMENT_METHOD_CHOICES di Django
  String get paymentMethodDisplay {
    switch (paymentMethod) {
      case 'e_wallet':
        return 'E-Wallet';
      case 'credit_card':
        return 'Kartu Kredit';
      case 'bank_transfer':
      default:
        return 'Transfer Bank';
    }
  }

  // Display label sesuai PAYMENT_STATUS_CHOICES di Django
  String get statusDisplay {
    switch (status) {
      case 'paid':
        return 'Lunas';
      case 'failed':
        return 'Gagal';
      case 'refunded':
        return 'Dikembalikan';
      case 'pending':
      default:
        return 'Menunggu Pembayaran';
    }
  }
}

// Sesuai: OrderListSerializer & OrderDetailSerializer (orders/serializers.py)
// Fields: id, user(username), ticket_info, quantity, total_price, status, order_date
// List tambahan: payment_status
// Detail tambahan: payment (PaymentSerializer)
class Order {
  final int id;
  final String user; // username
  final TicketInfo ticketInfo;
  final int quantity;
  final double totalPrice;
  final String status; // 'pending' | 'confirmed' | 'cancelled'
  final String orderDate; // ISO datetime string
  final String? paymentStatus; // hanya di list: payment.status
  final Payment? payment; // hanya di detail response

  Order({
    required this.id,
    required this.user,
    required this.ticketInfo,
    required this.quantity,
    required this.totalPrice,
    required this.status,
    required this.orderDate,
    this.paymentStatus,
    this.payment,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? 0,
      user: json['user']?.toString() ?? '',
      ticketInfo: TicketInfo.fromJson(json['ticket_info'] ?? {}),
      quantity: json['quantity'] ?? 0,
      totalPrice:
          double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'pending',
      orderDate: json['order_date'] ?? '',
      paymentStatus: json['payment_status'] as String?,
      payment: json['payment'] != null
          ? Payment.fromJson(json['payment'])
          : null,
    );
  }

  // Display label sesuai ORDER_STATUS_CHOICES di Django
  String get statusDisplay {
    switch (status) {
      case 'confirmed':
        return 'Terkonfirmasi';
      case 'cancelled':
        return 'Dibatalkan';
      case 'pending':
      default:
        return 'Menunggu Pembayaran';
    }
  }
}

class AdminChartSummary {
  final List<OrdersPerSeminar> ordersPerSeminar;
  final List<RevenuePerMonth> revenuePerMonth;
  final List<CategoryDistribution> categoryDistribution;

  AdminChartSummary({
    required this.ordersPerSeminar,
    required this.revenuePerMonth,
    required this.categoryDistribution,
  });

  factory AdminChartSummary.fromJson(Map<String, dynamic> json) {
    final orders = json['orders_per_seminar'] as List? ?? [];
    final revenue = json['revenue_per_month'] as List? ?? [];
    final categories = json['category_distribution'] as List? ?? [];

    return AdminChartSummary(
      ordersPerSeminar: orders
          .map((item) => OrdersPerSeminar.fromJson(item))
          .toList(),
      revenuePerMonth: revenue
          .map((item) => RevenuePerMonth.fromJson(item))
          .toList(),
      categoryDistribution: categories
          .map((item) => CategoryDistribution.fromJson(item))
          .toList(),
    );
  }
}

class OrdersPerSeminar {
  final String seminarTitle;
  final int totalOrders;

  OrdersPerSeminar({required this.seminarTitle, required this.totalOrders});

  factory OrdersPerSeminar.fromJson(Map<String, dynamic> json) {
    return OrdersPerSeminar(
      seminarTitle: json['seminar_title']?.toString() ?? 'Tanpa Judul',
      totalOrders: json['total_orders'] ?? 0,
    );
  }
}

class RevenuePerMonth {
  final String? month;
  final double totalRevenue;

  RevenuePerMonth({this.month, required this.totalRevenue});

  factory RevenuePerMonth.fromJson(Map<String, dynamic> json) {
    return RevenuePerMonth(
      month: json['month']?.toString(),
      totalRevenue:
          double.tryParse(json['total_revenue']?.toString() ?? '0') ?? 0,
    );
  }
}

class CategoryDistribution {
  final String categoryName;
  final int count;

  CategoryDistribution({required this.categoryName, required this.count});

  factory CategoryDistribution.fromJson(Map<String, dynamic> json) {
    return CategoryDistribution(
      categoryName: json['category_name']?.toString() ?? 'Tanpa Kategori',
      count: json['count'] ?? 0,
    );
  }
}
