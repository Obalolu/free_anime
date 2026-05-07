class ServiceProtectionException implements Exception {
  const ServiceProtectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpstreamUnavailableException implements Exception {
  const UpstreamUnavailableException([
    this.message = 'Upstream service unavailable',
  ]);

  final String message;

  @override
  String toString() => message;
}
