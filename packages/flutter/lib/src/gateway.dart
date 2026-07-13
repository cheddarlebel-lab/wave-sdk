/// Config for the Wave gateway.
class WaveConfig {
  final String gatewayUrl;
  final String anonKey;
  final String publishableKey;
  final String userNumber;
  const WaveConfig({
    required this.gatewayUrl,
    required this.anonKey,
    required this.publishableKey,
    required this.userNumber,
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
