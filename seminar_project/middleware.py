"""
Custom Middleware untuk Seminar Ticket Booking API.

1. RequestLoggingMiddleware - Log setiap HTTP request
2. APIRateLimitMiddleware - Rate limiting per IP address
"""

import time
import logging
import json
from collections import defaultdict
from django.http import JsonResponse

logger = logging.getLogger('middleware')


class RequestLoggingMiddleware:
    """
    Middleware untuk mencatat log setiap HTTP request yang masuk.
    
    Log mencakup:
    - HTTP method (GET, POST, PUT, DELETE, dll)
    - Request path
    - Response status code
    - Waktu pemrosesan (dalam milidetik)
    - IP address client
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Catat waktu mulai
        start_time = time.time()

        # Proses request
        response = self.get_response(request)

        # Hitung durasi
        duration_ms = (time.time() - start_time) * 1000

        # Dapatkan IP address
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip_address = x_forwarded_for.split(',')[0].strip()
        else:
            ip_address = request.META.get('REMOTE_ADDR', 'unknown')

        # Log request
        logger.info(
            '[RequestLog] %s %s %s %.2fms (IP: %s)',
            request.method,
            request.get_full_path(),
            response.status_code,
            duration_ms,
            ip_address,
        )

        return response


class APIRateLimitMiddleware:
    """
    Middleware untuk membatasi jumlah request per IP address.
    
    Konfigurasi:
    - Maksimal 100 request per menit per IP
    - Hanya berlaku untuk path yang dimulai dengan /api/
    - Mengembalikan response 429 Too Many Requests jika melebihi batas
    """

    # Simpan data request per IP: {ip: [timestamp1, timestamp2, ...]}
    _request_log = defaultdict(list)
    MAX_REQUESTS = 100  # Maksimal request
    TIME_WINDOW = 60    # Dalam detik (1 menit)

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Hanya terapkan rate limiting untuk API endpoints
        if not request.path.startswith('/api/'):
            return self.get_response(request)

        # Dapatkan IP address
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip_address = x_forwarded_for.split(',')[0].strip()
        else:
            ip_address = request.META.get('REMOTE_ADDR', 'unknown')

        current_time = time.time()
        cutoff_time = current_time - self.TIME_WINDOW

        # Bersihkan request lama di luar time window
        self._request_log[ip_address] = [
            timestamp for timestamp in self._request_log[ip_address]
            if timestamp > cutoff_time
        ]

        # Cek apakah sudah melebihi batas
        if len(self._request_log[ip_address]) >= self.MAX_REQUESTS:
            logger.warning(
                '[RateLimit] IP %s telah melebihi batas %d request per menit',
                ip_address,
                self.MAX_REQUESTS,
            )
            return JsonResponse(
                {
                    'error': 'Too Many Requests',
                    'detail': f'Anda telah melebihi batas {self.MAX_REQUESTS} request per menit. '
                              f'Silakan coba lagi nanti.',
                },
                status=429,
            )

        # Catat request ini
        self._request_log[ip_address].append(current_time)

        return self.get_response(request)
