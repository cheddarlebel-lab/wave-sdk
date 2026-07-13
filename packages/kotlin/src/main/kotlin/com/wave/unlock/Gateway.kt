package com.wave.unlock

/** Config for the Wave gateway. No Supabase key — the branded gateway is tenant-scoped
 *  and injects its backend key server-side, so the SDK can only reach the scoped
 *  unlock endpoints, never the data plane. */
data class WaveConfig(
    val publishableKey: String,
    val userNumber: String,
    /** Production gateway. Override only for a documented staging environment. */
    val gatewayUrl: String = "https://app.wavepassport.com/api",
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
