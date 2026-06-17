"""
URL configuration untuk accounts app.

Endpoints:
- POST   /api/auth/register/          → Registrasi user baru
- POST   /api/auth/token/             → Login (dapatkan JWT token)
- POST   /api/auth/token/refresh/     → Refresh JWT token
- GET    /api/auth/profile/           → Lihat profil
- PUT    /api/auth/profile/           → Update profil
- PUT    /api/auth/change-password/   → Ganti password
"""

from django.urls import path
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

from .views import RegisterView, ProfileView, ChangePasswordView

app_name = 'accounts'

urlpatterns = [
    # Registrasi
    path('register/', RegisterView.as_view(), name='register'),

    # JWT Token (Login & Refresh)
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    # Profil & Password
    path('profile/', ProfileView.as_view(), name='profile'),
    path('change-password/', ChangePasswordView.as_view(), name='change-password'),
]
