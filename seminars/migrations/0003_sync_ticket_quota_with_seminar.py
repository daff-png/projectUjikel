from django.db import migrations


def sync_ticket_quotas(apps, schema_editor):
    Seminar = apps.get_model('seminars', 'Seminar')
    Ticket = apps.get_model('seminars', 'Ticket')
    for seminar in Seminar.objects.all():
        Ticket.objects.filter(seminar_id=seminar.id).update(quota=seminar.max_participants)


class Migration(migrations.Migration):

    dependencies = [
        ('seminars', '0002_change_location_url_to_charfield'),
    ]

    operations = [
        migrations.RunPython(sync_ticket_quotas, migrations.RunPython.noop),
    ]
