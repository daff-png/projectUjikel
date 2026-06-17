from rest_framework import viewsets, permissions, mixins, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema, extend_schema_view
from django.db import transaction
from django.utils import timezone

from .models import Order, Payment
from .serializers import (
    OrderCreateSerializer,
    OrderListSerializer,
    OrderDetailSerializer,
    PaymentUpdateSerializer
)
from accounts.views import IsAdminRole

@extend_schema_view(
    list=extend_schema(summary='Daftar Pesanan'),
    retrieve=extend_schema(summary='Detail Pesanan'),
    create=extend_schema(summary='Buat Pesanan Baru')
)
class OrderViewSet(viewsets.ModelViewSet):
    """
    ViewSet untuk mengelola pesanan (Order).
    """
    filterset_fields = ['status']
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post', 'head', 'options']

    def get_queryset(self):
        user = self.request.user
        # Semua user (termasuk admin) hanya lihat order milik sendiri di endpoint ini
        return Order.objects.filter(user=user)

    def get_serializer_class(self):
        if self.action == 'create':
            return OrderCreateSerializer
        elif self.action == 'retrieve':
            return OrderDetailSerializer
        return OrderListSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        ticket = serializer.validated_data['ticket']
        quantity = serializer.validated_data['quantity']
        payment_method = serializer.validated_data['payment_method']
        
        try:
            # DATABASE TRANSACTION: Proses atomic untuk Order + Ticket Kuota + Payment
            with transaction.atomic():
                # 1. Lock tiket untuk menghindari race condition
                # Reload the ticket with select_for_update
                from seminars.models import Ticket
                locked_ticket = Ticket.objects.select_for_update().get(id=ticket.id)

                if locked_ticket.available_quota < quantity:
                    return Response(
                        {
                            'detail': (
                                f'Kuota tiket tidak mencukupi. '
                                f'Sisa: {locked_ticket.available_quota}'
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )
                
                # 2. Buat Order
                total_price = locked_ticket.price * quantity
                order = Order.objects.create(
                    user=request.user,
                    ticket=locked_ticket,
                    quantity=quantity,
                    total_price=total_price,
                    status='pending'
                )
                
                # 3. Update Kuota Tiket
                locked_ticket.sold_count += quantity
                locked_ticket.save()
                
                # 4. Buat Payment
                Payment.objects.create(
                    order=order,
                    payment_method=payment_method,
                    amount=total_price,
                    status='pending'
                )
                
            response_serializer = OrderDetailSerializer(order)
            return Response(response_serializer.data, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            return Response({'detail': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @extend_schema(
        summary='Batalkan Pesanan',
        request=None,
        responses={200: OrderDetailSerializer}
    )
    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        order = self.get_object()
        
        if order.status == 'cancelled':
            return Response({'detail': 'Pesanan sudah dibatalkan sebelumnya.'}, status=status.HTTP_400_BAD_REQUEST)

        if order.status != 'pending':
            return Response(
                {'detail': 'Hanya pesanan dengan status pending yang bisa dibatalkan.'},
                status=status.HTTP_400_BAD_REQUEST
            )
            
        try:
            with transaction.atomic():
                # Lock order and its ticket
                order = Order.objects.select_for_update().get(id=order.id)
                from seminars.models import Ticket
                ticket = Ticket.objects.select_for_update().get(id=order.ticket_id)
                
                # Kembalikan kuota
                ticket.sold_count -= order.quantity
                ticket.save()
                
                # Update status order
                order.status = 'cancelled'
                order.save()
                
                # Update payment status
                if hasattr(order, 'payment'):
                    payment = order.payment
                    payment.status = 'refunded'
                    payment.save()
                    
            return Response(OrderDetailSerializer(order).data)
        except Exception as e:
            return Response({'detail': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@extend_schema_view(
    retrieve=extend_schema(summary='Detail Pembayaran'),
    update=extend_schema(summary='Update Status/Bukti Pembayaran'),
    partial_update=extend_schema(summary='Update Parsial Pembayaran')
)
class PaymentViewSet(mixins.RetrieveModelMixin, mixins.UpdateModelMixin, viewsets.GenericViewSet):
    """
    ViewSet untuk Pembayaran.
    Hanya mendukung operasi Read dan Update.
    Mendukung upload bukti pembayaran.
    """
    queryset = Payment.objects.all()
    serializer_class = PaymentUpdateSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = (MultiPartParser, FormParser, JSONParser)

    def get_queryset(self):
        user = self.request.user
        # Semua user (termasuk admin) hanya lihat payment milik sendiri
        return Payment.objects.filter(order__user=user)

    def perform_update(self, serializer):
        serializer.save()


@extend_schema(
    summary='[Admin] Semua Pesanan',
    description='Menampilkan semua pesanan dari semua user. Hanya untuk admin.',
    tags=['Admin'],
)
class AdminOrderListView(APIView):
    """
    Endpoint khusus admin untuk memonitor semua order dari semua user.
    Mendukung filter by status.
    """
    permission_classes = [IsAdminRole]

    def get(self, request):
        status_filter = request.query_params.get('status', None)
        orders = Order.objects.all().select_related(
            'user', 'ticket__seminar', 'payment'
        ).order_by('-order_date')

        if status_filter:
            orders = orders.filter(status=status_filter)

        serializer = OrderDetailSerializer(orders, many=True)
        return Response(serializer.data)


@extend_schema(
    summary='[Admin] Konfirmasi Pembayaran',
    description='Admin mengkonfirmasi pembayaran order menjadi paid/confirmed.',
    tags=['Admin'],
)
class AdminConfirmPaymentView(APIView):
    """
    Endpoint khusus admin untuk konfirmasi pembayaran.
    """
    permission_classes = [IsAdminRole]

    def patch(self, request, payment_id):
        try:
            payment = Payment.objects.select_related('order').get(id=payment_id)
        except Payment.DoesNotExist:
            return Response({'detail': 'Payment tidak ditemukan.'}, status=status.HTTP_404_NOT_FOUND)

        payment_status = request.data.get('status')
        if payment_status not in ['paid', 'failed', 'refunded']:
            return Response(
                {'detail': 'Status tidak valid. Pilih: paid, failed, refunded.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        order = payment.order

        with transaction.atomic():
            payment.status = payment_status
            if payment_status == 'paid' and not payment.payment_date:
                payment.payment_date = timezone.now()
            payment.save()

            if payment_status == 'paid':
                order.status = 'confirmed'
                order.save()
            elif payment_status in ['failed', 'refunded']:
                from seminars.models import Ticket
                ticket = Ticket.objects.select_for_update().get(id=order.ticket_id)
                ticket.sold_count = max(0, ticket.sold_count - order.quantity)
                ticket.save()
                order.status = 'cancelled'
                order.save()

        return Response(OrderDetailSerializer(order).data)
