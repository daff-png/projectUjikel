from django.urls import path
from .views import ExportOrdersPDFView, ExportOrdersXLSXView

app_name = 'exports'

urlpatterns = [
    path('orders/pdf/', ExportOrdersPDFView.as_view(), name='export-orders-pdf'),
    path('orders/xlsx/', ExportOrdersXLSXView.as_view(), name='export-orders-xlsx'),
]
