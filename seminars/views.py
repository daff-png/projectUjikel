from rest_framework import viewsets, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from drf_spectacular.utils import extend_schema, extend_schema_view
from django.db.models import Count, Sum, F
from django.db.models.functions import TruncMonth

from .models import Category, Seminar, Ticket
from .serializers import (
    CategorySerializer,
    SeminarListSerializer,
    SeminarDetailSerializer,
    TicketSerializer
)
from accounts.views import IsAdminRole

# Actions yang hanya boleh dilakukan admin
ADMIN_ONLY_ACTIONS = ['create', 'update', 'partial_update', 'destroy']


@extend_schema_view(
    list=extend_schema(summary='Daftar Kategori'),
    retrieve=extend_schema(summary='Detail Kategori'),
    create=extend_schema(summary='Buat Kategori Baru'),
    update=extend_schema(summary='Update Kategori'),
    partial_update=extend_schema(summary='Update Parsial Kategori'),
    destroy=extend_schema(summary='Hapus Kategori')
)
class CategoryViewSet(viewsets.ModelViewSet):
    """
    CRUD Master untuk Category.
    - List & Retrieve: semua user yang sudah login
    - Create, Update, Delete: hanya role admin
    """
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    filterset_fields = ['name']
    search_fields = ['name', 'description']

    def get_permissions(self):
        if self.action in ADMIN_ONLY_ACTIONS:
            return [IsAdminRole()]
        return [permissions.IsAuthenticated()]


@extend_schema_view(
    list=extend_schema(summary='Daftar Seminar'),
    retrieve=extend_schema(summary='Detail Seminar'),
    create=extend_schema(summary='Buat Seminar Baru'),
    update=extend_schema(summary='Update Seminar'),
    partial_update=extend_schema(summary='Update Parsial Seminar'),
    destroy=extend_schema(summary='Hapus Seminar')
)
class SeminarViewSet(viewsets.ModelViewSet):
    """
    CRUD untuk Seminar.
    - List & Retrieve: semua user yang sudah login
    - Create, Update, Delete: hanya role admin
    Mendukung upload file banner (ImageField).
    """
    queryset = Seminar.objects.all()
    parser_classes = (MultiPartParser, FormParser, JSONParser)
    filterset_fields = ['category', 'is_online', 'date']
    search_fields = ['title', 'description']
    ordering_fields = ['date', 'created_at', 'title']

    def get_permissions(self):
        if self.action in ADMIN_ONLY_ACTIONS:
            return [IsAdminRole()]
        return [permissions.IsAuthenticated()]

    def get_serializer_class(self):
        if self.action == 'list':
            return SeminarListSerializer
        return SeminarDetailSerializer

    def perform_create(self, serializer):
        serializer.save(organizer=self.request.user)

    def perform_update(self, serializer):
        serializer.save()


@extend_schema_view(
    list=extend_schema(summary='Daftar Tiket'),
    retrieve=extend_schema(summary='Detail Tiket'),
    create=extend_schema(summary='Buat Tiket Baru'),
    update=extend_schema(summary='Update Tiket'),
    partial_update=extend_schema(summary='Update Parsial Tiket'),
    destroy=extend_schema(summary='Hapus Tiket')
)
class TicketViewSet(viewsets.ModelViewSet):
    """
    CRUD untuk Tiket.
    - List & Retrieve: semua user yang sudah login
    - Create, Update, Delete: hanya role admin
    """
    queryset = Ticket.objects.all()
    serializer_class = TicketSerializer
    filterset_fields = ['seminar', 'ticket_type', 'is_active']

    def get_permissions(self):
        if self.action in ADMIN_ONLY_ACTIONS:
            return [IsAdminRole()]
        return [permissions.IsAuthenticated()]

class ChartDataView(APIView):
    """
    Endpoint untuk mendapatkan data statistik chart.
    Hanya bisa diakses oleh role admin.
    """
    permission_classes = [IsAdminRole]

    @extend_schema(
        summary='Data Statistik Chart',
        description='Mengembalikan data untuk chart: pesanan per seminar, pendapatan per bulan, dan distribusi kategori.',
    )
    def get(self, request):
        try:
            from orders.models import Order, Payment

            # Orders per seminar
            orders_per_seminar = Order.objects.values(
                seminar_title=F('ticket__seminar__title')
            ).annotate(total_orders=Count('id')).order_by('-total_orders')

            # Revenue per month
            revenue_per_month = Payment.objects.filter(status='paid').annotate(
                month=TruncMonth('payment_date')
            ).values('month').annotate(
                total_revenue=Sum('amount')
            ).order_by('month')

        except ImportError:
            orders_per_seminar = []
            revenue_per_month = []

        # Category distribution
        category_distribution = Seminar.objects.values(
            category_name=F('category__name')
        ).annotate(count=Count('id')).order_by('-count')

        data = {
            'orders_per_seminar': list(orders_per_seminar),
            'revenue_per_month': list(revenue_per_month),
            'category_distribution': list(category_distribution)
        }
        return Response(data)
