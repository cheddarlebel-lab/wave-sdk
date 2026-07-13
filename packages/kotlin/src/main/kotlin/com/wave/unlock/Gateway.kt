package com.wave.unlock

/** Config for the Wave gateway (Supabase edge functions). */
data class WaveConfig(
    val gatewayUrl: String,
    val anonKey: String,
    val publishableKey: String,
    val userNumber: String,
)

data class Outcome(val status: Status, val reason: String?) {
    enum class Status { GRANTED, DENIED, PENDING }
}

/** Gateway abstraction so the engine is testable without real HTTP. */
interface Gateway {
    suspend fun fetchToken(): String
    suspend fun readOutcome(token: String): Outcome
    suspend fun awaitOutcome(token: String, timeoutMs: Long, pollMs: Long = 500): Outcome
}
