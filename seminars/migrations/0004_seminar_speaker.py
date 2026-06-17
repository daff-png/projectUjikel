from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('seminars', '0003_sync_ticket_quota_with_seminar'),
    ]

    operations = [
        migrations.AddField(
            model_name='seminar',
            name='speaker',
            field=models.CharField(blank=True, default='', max_length=150),
        ),
    ]
