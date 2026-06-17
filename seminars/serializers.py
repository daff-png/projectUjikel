from django.db.models import Sum
from rest_framework import serializers
from .models import Category, Seminar, Ticket


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = '__all__'


class TicketSerializer(serializers.ModelSerializer):
    available_quota = serializers.ReadOnlyField()

    class Meta:
        model = Ticket
        fields = '__all__'
        read_only_fields = ['sold_count']

    def _validate_quota_capacity(self, seminar, quota, instance=None):
        tickets = Ticket.objects.filter(seminar=seminar)
        if instance:
            tickets = tickets.exclude(pk=instance.pk)
        other_quota = tickets.aggregate(total=Sum('quota'))['total'] or 0
        total_quota = other_quota + quota
        if total_quota > seminar.max_participants:
            raise serializers.ValidationError({
                'quota': (
                    f'Kuota sudah maksimal. Total kuota tiket ({total_quota}) '
                    f'tidak boleh melebihi maks. peserta seminar '
                    f'({seminar.max_participants}).'
                )
            })

    def validate_quota(self, value):
        if value < 1:
            raise serializers.ValidationError('Kuota minimal 1.')
        if self.instance and value < self.instance.sold_count:
            raise serializers.ValidationError(
                f'Kuota tidak boleh kurang dari jumlah terjual ({self.instance.sold_count}).'
            )
        return value

    def validate(self, attrs):
        seminar = attrs.get('seminar') or (self.instance.seminar if self.instance else None)
        quota = attrs.get('quota', self.instance.quota if self.instance else None)

        if seminar is None or quota is None:
            return attrs

        self._validate_quota_capacity(seminar, quota, self.instance)
        return attrs


class SeminarListSerializer(serializers.ModelSerializer):
    organizer = serializers.StringRelatedField()

    class Meta:
        model = Seminar
        fields = [
            'id', 'title', 'speaker', 'organizer', 'category', 'banner', 'date', 'time',
            'is_online', 'max_participants', 'location_url', 'description',
        ]

    def to_representation(self, instance):
        rep = super().to_representation(instance)
        if instance.category:
            rep['category'] = {
                'id': instance.category.id,
                'name': instance.category.name,
            }
        return rep


class SeminarDetailSerializer(serializers.ModelSerializer):
    organizer = serializers.ReadOnlyField(source='organizer.username')
    organizer_name = serializers.SerializerMethodField()
    tickets = TicketSerializer(many=True, read_only=True)

    class Meta:
        model = Seminar
        fields = '__all__'

    def get_organizer_name(self, obj):
        if obj.organizer.first_name or obj.organizer.last_name:
            return f"{obj.organizer.first_name} {obj.organizer.last_name}".strip()
        return obj.organizer.username

    def _should_clear_banner(self):
        request = self.context.get('request')
        if not request:
            return False
        clear_banner = request.data.get('clear_banner')
        if clear_banner in (True, 'true', 'True', '1', 1):
            return 'banner' not in request.FILES
        return False

    def validate_max_participants(self, value):
        if not self.instance:
            return value
        if value < self.instance.total_sold:
            raise serializers.ValidationError(
                f'Maks. peserta tidak boleh kurang dari jumlah terjual ({self.instance.total_sold}).'
            )
        if value < self.instance.total_quota_allocated:
            raise serializers.ValidationError(
                f'Maks. peserta tidak boleh kurang dari total kuota tiket '
                f'({self.instance.total_quota_allocated}). Kurangi kuota tiket terlebih dahulu.'
            )
        return value

    def update(self, instance, validated_data):
        if self._should_clear_banner():
            if instance.banner:
                instance.banner.delete(save=False)
            instance.banner = None
            validated_data.pop('banner', None)
        return super().update(instance, validated_data)

    def to_representation(self, instance):
        rep = super().to_representation(instance)
        if instance.category:
            rep['category'] = {
                'id': instance.category.id,
                'name': instance.category.name,
            }
        return rep
