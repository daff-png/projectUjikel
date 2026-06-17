from django.db import models
from django.db.models import Sum
from django.conf import settings

class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name

    class Meta:
        ordering = ['name']

class Seminar(models.Model):
    title = models.CharField(max_length=200)
    speaker = models.CharField(max_length=150, blank=True, default='')
    description = models.TextField()
    organizer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='seminars')
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, related_name='seminars')
    banner = models.ImageField(upload_to='seminars/banners/', blank=True, null=True)
    date = models.DateField()
    time = models.TimeField()
    location_url = models.CharField(max_length=500, blank=True, help_text='Link meeting online atau alamat lokasi')
    is_online = models.BooleanField(default=True)
    max_participants = models.PositiveIntegerField(default=100)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @property
    def total_sold(self):
        return self.tickets.aggregate(total=Sum('sold_count'))['total'] or 0

    @property
    def total_quota_allocated(self):
        return self.tickets.aggregate(total=Sum('quota'))['total'] or 0

    @property
    def remaining_quota_capacity(self):
        return max(0, self.max_participants - self.total_quota_allocated)

    def __str__(self):
        return self.title

    class Meta:
        ordering = ['-date', '-time']

class Ticket(models.Model):
    TICKET_TYPE_CHOICES = [
        ('regular', 'Regular'),
        ('vip', 'VIP'),
        ('early_bird', 'Early Bird')
    ]
    
    seminar = models.ForeignKey(Seminar, on_delete=models.CASCADE, related_name='tickets')
    ticket_type = models.CharField(max_length=20, choices=TICKET_TYPE_CHOICES, default='regular')
    price = models.DecimalField(max_digits=12, decimal_places=2)
    quota = models.PositiveIntegerField(default=50)
    sold_count = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def available_quota(self):
        return max(0, self.quota - self.sold_count)

    def __str__(self):
        return f'{self.ticket_type} - {self.seminar.title}'

    class Meta:
        unique_together = ['seminar', 'ticket_type']
