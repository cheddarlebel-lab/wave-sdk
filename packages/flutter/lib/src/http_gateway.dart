import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'gateway.dart';

/// Real gateway client over dart:io HttpClient.
class HttpGateway implements Gateway {
  final WaveConfig config;
  final HttpClient _client;

  HttpGateway(this.config, {HttpClient? client}) : _client = client ?? HttpClient();

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {String? bearer}) async {
    final req = await _client.postUrl(Uri.parse('${config.gatewayUrl}/$path'));
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('apikey', config.anonKey);
    if (bearer != null) req.headers.set('Authorization', 'Bearer $bearer');
    req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    final data = text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
    if (res.statusCode >= 300) {
      throw Exception('gateway $path ${res.statusCode}: ${data['error'] ?? 'error'}');
    }
    return data;
  }

  @override
  Future<String> fetchToken() async {
    final data = await _post('partner-auth/token', {'key': config.publishableKey});
    final token = data['token'];
    if (token is! String) throw Exception('token missing');
    return token;
  }

  @override
  Future<Outcome> readOutcome(String token) async {
    final data = await _post('unlock-stream', {'card_id': config.userNumber}, bearer: token);
    final status = switch (data['status']) {
      'granted' => OutcomeStatus.granted,
      'denied' => OutcomeStatus.denied,
      _ => OutcomeStatus.pending,
    };
    return Outcome(status, data['reason'] as String?);
  }

  @override
  Future<Outcome> awaitOutcome(String token, Duration timeout, {Duration poll = const Duration(milliseconds: 500)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final o = await readOutcome(token);
        if (o.status != OutcomeStatus.pending) return o;
      } catch (_) {}
      await Future.delayed(poll);
    }
    return const Outcome(OutcomeStatus.pending, null);
  }
}
