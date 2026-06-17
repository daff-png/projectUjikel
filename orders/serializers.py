from rest_framework import serializers
from .models import Order, Payment
from seminars.models import Ticket

class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = '__all__'

class OrderCreateSerializer(serializers.Serializer):
    ticket = serializers.PrimaryKeyRelatedField(queryset=Ticket.objects.all())
    quantity = serializers.IntegerField(min_value=1)
    payment_method = serializers.ChoiceField(choices=Payment.PAYMENT_METHOD_CHOICES)

    def validate(self, attrs):
        ticket = attrs['ticket']
        quantity = attrs['quantity']

        if not ticket.is_active:
            raise serializers.ValidationError('Tiket ini sudah tidak aktif.')
        
        if ticket.available_quota < quantity:
            raise serializers.ValidationError(
                f'Kuota tiket tidak mencukupi. Sisa kuota: {ticket.available_quota}'
            )
        
        return attrs

class OrderListSerializer(serializers.ModelSerializer):
    user = serializers.ReadOnlyField(source='user.username')
    ticket_info = serializers.SerializerMethodField()
    payment_status = serializers.ReadOnlyField(source='payment.status')

    class Meta:
        model = Order
        fields = ['id', 'user', 'ticket_info', 'quantity', 'total_price', 'status', 'order_date', 'payment_status']

    def get_ticket_info(self, obj):
        return {
            'seminar_title': obj.ticket.seminar.title,
            'ticket_type': obj.ticket.get_ticket_type_display(),
            'price': str(obj.ticket.price)
        }

class OrderDetailSerializer(serializers.ModelSerializer):
    user = serializers.ReadOnlyField(source='user.username')
    payment = PaymentSerializer(read_only=True)
    ticket_info = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = ['id', 'user', 'ticket_info', 'quantity', 'total_price', 'status', 'order_date', 'payment']

    def get_ticket_info(self, obj):
        return {
            'seminar_title': obj.ticket.seminar.title,
            'ticket_type': obj.ticket.get_ticket_type_display(),
            'price': str(obj.ticket.price)
        }

class PaymentUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = ['proof_image']
