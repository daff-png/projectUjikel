"""
Root URL Configuration untuk Seminar Ticket Booking API.

Endpoints:
- /admin/           → Django Admin
- /api/auth/        → Authentication (register, login, profile)
- /api/             → Seminars, Categories, Tickets, Orders, Payments
- /api/exports/     → Export data (PDF, XLSX)
- /api/docs/        → Swagger UI Documentation
- /api/schema/      → OpenAPI Schema
- /api/redoc/       → ReDoc Documentation
"""

from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
    SpectacularRedocView,
)

urlpatterns = [
    # Django Admin
    path('admin/', admin.site.urls),

    # API Documentation (Swagger/OpenAPI)
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),

    # Authentication
    path('api/auth/', include('accounts.urls')),

    # Seminars, Categories, Tickets, Charts
    path('api/', include('seminars.urls')),

    # Orders & Payments
    path('api/', include('orders.urls')),

    # Export Data (PDF, XLSX)
    path('api/exports/', include('exports.urls')),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
