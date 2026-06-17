from django.contrib import admin
from .models import Order, Payment

@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'ticket', 'quantity', 'total_price', 'status', 'order_date')
    list_filter = ('status', 'order_date')
    search_fields = ('user__username', 'ticket__seminar__title')

@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ('order', 'payment_method', 'amount', 'status', 'payment_date')
    list_filter = ('status', 'payment_method', 'payment_date')
    search_fields = ('order__user__username', 'order__ticket__seminar__title')
