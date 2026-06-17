"""
Models untuk accounts app.

Menggunakan UserProfile sebagai extension dari User bawaan Django
untuk menyimpan informasi tambahan seperti role.
"""

from django.contrib.auth.models import User
from django.db import models
from django.db.models.signals import post_save
from django.dispatch import receiver


class UserProfile(models.Model):
    """
    Extension dari User model untuk menyimpan role dan info tambahan.
    
    Roles:
    - 'admin': Akses penuh ke semua fitur manajemen
    - 'user': User biasa, hanya bisa melihat dan memesan seminar
    """
    ROLE_CHOICES = [
        ('admin', 'Admin'),
        ('user', 'User'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='user')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'User Profile'
        verbose_name_plural = 'User Profiles'

    def __str__(self):
        return f'{self.user.username} - {self.role}'

    @property
    def is_admin(self):
        return self.role == 'admin'


@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    """Otomatis buat UserProfile saat User baru dibuat."""
    if created:
        role = 'admin' if instance.is_staff or instance.is_superuser else 'user'
        UserProfile.objects.create(user=instance, role=role)


@receiver(post_save, sender=User)
def save_user_profile(sender, instance, **kwargs):
    """Otomatis simpan UserProfile saat User di-save."""
    if hasattr(instance, 'profile'):
        instance.profile.save()
