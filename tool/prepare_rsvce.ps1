param(
  [string]$Source = 'C:\dev\catholicdaily-flutter\assets\rsvce.db'
)

$ErrorActionPreference = 'Stop'

$sourcePath = (Resolve-Path -LiteralPath $Source -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
  throw "RSVCE source is not a file: $sourcePath"
}

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$destinationDirectory = Join-Path $repositoryRoot 'apps\soulbuddy\assets\scripture'
$destinationPath = Join-Path $destinationDirectory 'rsvce.db'
New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null

$temporaryName = ([System.IO.Path]::GetRandomFileName()) + '.db'
$temporaryPath = Join-Path $destinationDirectory $temporaryName
$resolvedDestinationDirectory = (Resolve-Path -LiteralPath $destinationDirectory).Path
$resolvedTemporaryParent = [System.IO.Path]::GetDirectoryName(
  [System.IO.Path]::GetFullPath($temporaryPath)
)
if ($resolvedTemporaryParent -ne $resolvedDestinationDirectory) {
  throw 'The generated database path escaped the Scripture asset directory.'
}

$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
$python = @'
import sqlite3
import sys

source_path, database_path, source_hash = sys.argv[1], sys.argv[2], sys.argv[3]
source = sqlite3.connect(f'file:{source_path}?mode=ro', uri=True)
connection = sqlite3.connect(database_path)
try:
    source_check = source.execute('PRAGMA quick_check').fetchone()[0]
    if source_check != 'ok':
        raise RuntimeError(f'source quick_check failed: {source_check}')

    connection.execute("PRAGMA encoding = 'UTF-8'")
    dump = (
        statement
        for statement in source.iterdump()
        if statement != 'DELETE FROM "sqlite_sequence";'
    )
    connection.executescript('\n'.join(dump))

    connection.execute(
        'CREATE INDEX IF NOT EXISTS verses_lookup '
        'ON verses(book_id, chapter_id, verse_id)'
    )
    connection.execute(
        'CREATE TABLE IF NOT EXISTS soulbuddy_manifest ('
        'schema_version INTEGER NOT NULL, '
        'source_sha256 TEXT NOT NULL)'
    )
    connection.execute('DELETE FROM soulbuddy_manifest')
    connection.execute(
        'INSERT INTO soulbuddy_manifest(schema_version, source_sha256) '
        'VALUES (?, ?)',
        (2, source_hash),
    )
    connection.commit()

    quick_check = connection.execute('PRAGMA quick_check').fetchone()[0]
    if quick_check != 'ok':
        raise RuntimeError(f'quick_check failed: {quick_check}')
    encoding = connection.execute('PRAGMA encoding').fetchone()[0]
    if encoding != 'UTF-8':
        raise RuntimeError(f'unexpected encoding: {encoding}')

    query_plan = connection.execute(
        'EXPLAIN QUERY PLAN '
        'SELECT verse_id, text FROM verses '
        'WHERE book_id = ? AND chapter_id = ? ORDER BY verse_id',
        (1, 1),
    ).fetchall()
    plan_details = ' '.join(str(row[3]) for row in query_plan)
    if 'verses_lookup' not in plan_details or 'SCAN verses' in plan_details:
        raise RuntimeError(f'verse lookup index is not used: {plan_details}')

    books = connection.execute('SELECT COUNT(*) FROM books').fetchone()[0]
    verses = connection.execute('SELECT COUNT(*) FROM verses').fetchone()[0]
    print(f'quick_check: {quick_check}')
    print(f'books: {books}')
    print(f'verses: {verses}')
    print(f'encoding: {encoding}')
    print('index: verses_lookup')
finally:
    connection.close()
    source.close()
'@

try {
  $python | python - $sourcePath $temporaryPath $sourceHash
  if ($LASTEXITCODE -ne 0) {
    throw "RSVCE validation failed with exit code $LASTEXITCODE"
  }
  Move-Item -LiteralPath $temporaryPath -Destination $destinationPath -Force
  Write-Output "prepared: $destinationPath"
} finally {
  if (Test-Path -LiteralPath $temporaryPath) {
    Remove-Item -LiteralPath $temporaryPath -Force
  }
}
