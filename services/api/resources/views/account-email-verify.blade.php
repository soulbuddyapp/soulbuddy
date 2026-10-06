<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>Verify email</title>
</head>
<body>
    <main>
        <p id="status">Verifying email…</p>
    </main>
    <script>
        (() => {
            const status = document.getElementById('status');
            const values = new URLSearchParams(window.location.hash.slice(1));
            const challengeId = values.get('challenge');
            const token = values.get('token');
            history.replaceState(null, '', window.location.pathname);
            if (!challengeId || !token) {
                status.textContent = 'Verification link is no longer valid.';
                return;
            }
            fetch('/auth/email/confirm', {
                method: 'POST',
                credentials: 'same-origin',
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                },
                body: JSON.stringify({challenge_id: challengeId, token}),
            }).then(async (response) => {
                if (!response.ok) throw new Error();
                status.textContent = 'Email verified.';
                window.location.replace('/app/');
            }).catch(() => {
                status.textContent = 'Verification link is no longer valid.';
            });
        })();
    </script>
</body>
</html>
