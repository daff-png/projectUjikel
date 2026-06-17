from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import OrderViewSet, PaymentViewSet, AdminOrderListView, AdminConfirmPaymentView

router = DefaultRouter()
router.register(r'orders', OrderViewSet, basename='order')
router.register(r'payments', PaymentViewSet, basename='payment')

urlpatterns = [
    path('', include(router.urls)),
    path('admin/orders/', AdminOrderListView.as_view(), name='admin-order-list'),
    path('admin/payments/<int:payment_id>/confirm/', AdminConfirmPaymentView.as_view(), name='admin-confirm-payment'),
]
