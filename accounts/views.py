"""
Views untuk accounts app.

Menyediakan endpoint untuk:
- Registrasi user baru
- Melihat/mengedit profil
- Mengganti password
"""

from django.contrib.auth.models import User
from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated, BasePermission
from rest_framework.response import Response
from drf_spectacular.utils import extend_schema, extend_schema_view

from .serializers import RegisterSerializer, UserSerializer, ChangePasswordSerializer


class IsAdminRole(BasePermission):
    """
    Permission custom: hanya user dengan role 'admin' yang diizinkan.
    """
    message = 'Akses ditolak. Hanya admin yang dapat melakukan aksi ini.'

    def has_permission(self, request, view):
        return (
            request.user and
            request.user.is_authenticated and
            hasattr(request.user, 'profile') and
            request.user.profile.role == 'admin'
        )


@extend_schema_view(
    post=extend_schema(
        summary='Registrasi User Baru',
        description='Daftarkan akun baru dengan username, email, dan password.',
        tags=['Authentication'],
    )
)
class RegisterView(generics.CreateAPIView):
    """
    Endpoint untuk registrasi user baru.
    
    Tidak memerlukan autentikasi.
    """
    queryset = User.objects.all()
    permission_classes = (AllowAny,)
    serializer_class = RegisterSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(
            {
                'message': 'Registrasi berhasil.',
                'user': UserSerializer(user).data,
            },
            status=status.HTTP_201_CREATED,
        )


@extend_schema_view(
    get=extend_schema(
        summary='Lihat Profil',
        description='Menampilkan data profil user yang sedang login.',
        tags=['Authentication'],
    ),
    put=extend_schema(
        summary='Update Profil',
        description='Mengubah data profil user (email, first_name, last_name).',
        tags=['Authentication'],
    ),
    patch=extend_schema(
        summary='Update Profil (Partial)',
        description='Mengubah sebagian data profil user.',
        tags=['Authentication'],
    ),
)
class ProfileView(generics.RetrieveUpdateAPIView):
    """
    Endpoint untuk melihat dan mengedit profil user yang sedang login.
    
    Memerlukan autentikasi JWT.
    """
    serializer_class = UserSerializer
    permission_classes = (IsAuthenticated,)

    def get_object(self):
        return self.request.user


@extend_schema_view(
    put=extend_schema(
        summary='Ganti Password',
        description='Mengganti password user. Memerlukan password lama dan password baru.',
        tags=['Authentication'],
    ),
    patch=extend_schema(
        summary='Ganti Password',
        description='Mengganti password user. Memerlukan password lama dan password baru.',
        tags=['Authentication'],
    ),
)
class ChangePasswordView(generics.UpdateAPIView):
    """
    Endpoint untuk mengganti password user yang sedang login.
    
    Memerlukan autentikasi JWT.
    """
    serializer_class = ChangePasswordSerializer
    permission_classes = (IsAuthenticated,)

    def get_object(self):
        return self.request.user

    def update(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user = self.get_object()
        user.set_password(serializer.validated_data['new_password'])
        user.save()

        return Response(
            {'message': 'Password berhasil diubah.'},
            status=status.HTTP_200_OK,
        )
