"""Check the public sync endpoint before producing a Play release bundle."""

import ipaddress
import os
import re
from urllib.parse import urlsplit


def validate_endpoint(value: str) -> str:
    if not value or value != value.strip() or any(ch.isspace() for ch in value):
        raise ValueError('A PowerSync HTTPS endpoint is required.')
    try:
        url = urlsplit(value)
        host = url.hostname
        if host:
            host = host.rstrip('.')
        _ = url.port
    except ValueError as exc:
        raise ValueError('Invalid PowerSync endpoint.') from exc
    if (url.scheme != 'https' or not host or url.username is not None
            or url.password is not None or url.query or url.fragment
            or host.lower() == 'localhost'
            or host.lower().endswith(('.localhost', '.local', '.invalid', '.test'))):
        raise ValueError('PowerSync must use a public HTTPS endpoint without credentials.')
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        labels = host.rstrip('.').split('.')
        if (len(labels) < 2 or len(host) > 253
                or any(not re.fullmatch(r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?', label)
                       for label in labels)):
            raise ValueError('PowerSync requires a public hostname.')
    else:
        if not address.is_global:
            raise ValueError('PowerSync requires a public address.')
    if url.path and not url.path.endswith('/'):
        raise ValueError('A PowerSync endpoint path must end in a slash.')
    return value


if __name__ == '__main__':
    try:
        validate_endpoint(os.environ.get('SOULBUDDY_POWERSYNC_URL', ''))
    except ValueError as error:
        raise SystemExit(str(error)) from error
    print('PowerSync release endpoint is configured.')
