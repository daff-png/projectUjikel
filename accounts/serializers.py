"""
Serializers untuk accounts app.

Menyediakan serializer untuk:
- Registrasi user baru
- Menampilkan/edit profil user
- Ganti password
"""

from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from .models import UserProfile


class RegisterSerializer(serializers.ModelSerializer):
    """
    Serializer untuk registrasi user baru.
    
    Fields:
    - username: Username unik
    - email: Alamat email
    - password: Password (write-only)
    - password2: Konfirmasi password (write-only)
    - first_name: Nama depan (opsional)
    - last_name: Nama belakang (opsional)
    """
    password = serializers.CharField(
        write_only=True,
        required=True,
        validators=[validate_password],
        style={'input_type': 'password'},
    )
    password2 = serializers.CharField(
        write_only=True,
        required=True,
        style={'input_type': 'password'},
        label='Konfirmasi Password',
    )

    class Meta:
        model = User
        fields = ('username', 'email', 'password', 'password2', 'first_name', 'last_name')
        extra_kwargs = {
            'email': {'required': True},
            'first_name': {'required': False},
            'last_name': {'required': False},
        }

    def validate(self, attrs):
        """Validasi bahwa password dan password2 cocok."""
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError({
                'password': 'Password tidak cocok.'
            })
        return attrs

    def validate_email(self, value):
        """Validasi bahwa email belum digunakan."""
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('Email sudah terdaftar.')
        return value

    def create(self, validated_data):
        """Buat user baru dengan password yang di-hash."""
        validated_data.pop('password2')
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
        )
        return user


class UserSerializer(serializers.ModelSerializer):
    """
    Serializer untuk menampilkan dan mengedit profil user.
    """
    role = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'first_name', 'last_name', 'date_joined', 'role')
        read_only_fields = ('id', 'username', 'date_joined', 'role')

    def get_role(self, obj):
        """Ambil role dari UserProfile."""
        if hasattr(obj, 'profile'):
            return obj.profile.role
        return 'user'


class ChangePasswordSerializer(serializers.Serializer):
    """
    Serializer untuk mengganti password user.
    """
    old_password = serializers.CharField(
        required=True,
        style={'input_type': 'password'},
    )
    new_password = serializers.CharField(
        required=True,
        validators=[validate_password],
        style={'input_type': 'password'},
    )

    def validate_old_password(self, value):
        """Validasi password lama."""
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError('Password lama tidak benar.')
        return value
