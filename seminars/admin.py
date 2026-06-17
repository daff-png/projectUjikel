from django.contrib import admin
from .models import Category, Seminar, Ticket

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'created_at', 'updated_at')
    search_fields = ('name', 'description')

@admin.register(Seminar)
class SeminarAdmin(admin.ModelAdmin):
    list_display = ('title', 'speaker', 'organizer', 'category', 'date', 'time', 'is_online')
    list_filter = ('is_online', 'category', 'date')
    search_fields = ('title', 'speaker', 'description')

@admin.register(Ticket)
class TicketAdmin(admin.ModelAdmin):
    list_display = ('seminar', 'ticket_type', 'price', 'quota', 'sold_count', 'is_active')
    list_filter = ('ticket_type', 'is_active')
    search_fields = ('seminar__title',)
