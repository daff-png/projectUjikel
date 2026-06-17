from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import CategoryViewSet, SeminarViewSet, TicketViewSet, ChartDataView

router = DefaultRouter()
router.register(r'categories', CategoryViewSet, basename='category')
router.register(r'seminars', SeminarViewSet, basename='seminar')
router.register(r'tickets', TicketViewSet, basename='ticket')

urlpatterns = [
    path('', include(router.urls)),
    path('charts/summary/', ChartDataView.as_view(), name='chart-summary'),
]
