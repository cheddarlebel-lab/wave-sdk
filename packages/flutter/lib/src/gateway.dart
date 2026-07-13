/// Config for the Wave gateway. No Supabase key — the branded gateway is tenant-scoped
/// and injects its backend key server-side, so the SDK can only reach the scoped
/// unlock endpoints, never the data plane.
class WaveConfig {
  final String publishableKey;
  final String userNumber;

  /// Production gateway. Override only for a documented staging environment.
  final String gatewayUrl;
  const WaveConfig({
    required this.publishableKey,
    required this.userNumber,
    this.gatewayUrl = 'https://app.wavepassport.com/api',
  });
}

enum OutcomeStatus { granted, denied, pending }

class Outcome {
  final OutcomeStatus status;
  final String? reason;
  const Outcome(this.status, this.reason);
}

/// Gateway abstraction so the engine is testable without real HTTP.
abstract class Gateway {
  Future<String> fetchToken();
  Future<Outcome> readOutcome(String token);
  Future<Outcome> awaitOutcome(String token, Duration timeout, {Duration poll});
}
