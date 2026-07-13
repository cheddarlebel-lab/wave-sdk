package com.wave.unlock

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse

/** Real gateway client over java.net.http. Minimal JSON parsing (no extra deps). */
class HttpGateway(
    private val config: WaveConfig,
    private val client: HttpClient = HttpClient.newHttpClient(),
) : Gateway {

    private fun post(path: String, body: String, bearer: String?): HttpResponse<String> {
        val builder = HttpRequest.newBuilder()
            .uri(URI.create("${config.gatewayUrl}/$path"))
            .header("Content-Type", "application/json")
            .header("apikey", config.anonKey)
        if (bearer != null) builder.header("Authorization", "Bearer $bearer")
        return client.send(builder.POST(HttpRequest.BodyPublishers.ofString(body)).build(),
            HttpResponse.BodyHandlers.ofString())
    }

    private fun field(json: String, key: String): String? {
        val m = Regex("\"$key\"\\s*:\\s*\"([^\"]*)\"").find(json)
        return m?.groupValues?.get(1)
    }

    override suspend fun fetchToken(): String = withContext(Dispatchers.IO) {
        val res = post("partner-auth/token", "{\"key\":\"${config.publishableKey}\"}", null)
        field(res.body(), "token") ?: throw IllegalStateException("token missing")
    }

    override suspend fun readOutcome(token: String): Outcome = withContext(Dispatchers.IO) {
        val res = post("unlock-stream", "{\"card_id\":\"${config.userNumber}\"}", token)
        val status = when (field(res.body(), "status")) {
            "granted" -> Outcome.Status.GRANTED
            "denied" -> Outcome.Status.DENIED
            else -> Outcome.Status.PENDING
        }
        Outcome(status, field(res.body(), "reason"))
    }

    override suspend fun awaitOutcome(token: String, timeoutMs: Long, pollMs: Long): Outcome {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            val o = runCatching { readOutcome(token) }.getOrNull()
            if (o != null && o.status != Outcome.Status.PENDING) return o
            delay(pollMs)
        }
        return Outcome(Outcome.Status.PENDING, null)
    }
}
