class RetryableFutureCache<T> {
  Future<T>? _pending;

  Future<T> get(Future<T> Function() open) async {
    final pending = _pending ??= open();
    try {
      return await pending;
    } on Object {
      if (identical(_pending, pending)) {
        _pending = null;
      }
      rethrow;
    }
  }
}
