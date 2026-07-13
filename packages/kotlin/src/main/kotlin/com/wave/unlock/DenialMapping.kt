package com.wave.unlock

/** SICM reason -> member-facing message. Verbatim from contract/conformance/denial-mapping.json. */
object DenialMapping {
    val table: List<Pair<String, String>> = listOf(
        "Granted by provider cache" to "Access Granted",
        "Client not found" to "Member not found",
        "Blocked by schedule" to "Outside access hours",
        "Maximum active signins" to "Maximum active sign-ins reached",
        "Checkins limitation" to "Daily check-in limit reached",
        "Blocked by restriction" to "Membership restriction",
        "Blocked by client alert" to "Account alert",
        "Over account balance" to "Outstanding balance",
        "Liability release" to "Liability release required",
        "Scheduled visit" to "No booking found",
        "No member picture" to "Photo required",
        "Provider not found" to "System error - provider unavailable",
        "Inactive" to "Membership inactive",
        "Expired" to "Membership expired",
    )

    fun friendly(raw: String?): String {
        if (raw.isNullOrEmpty()) return "Access denied"
        val cleaned = if (raw.startsWith("[mock] ")) raw.substring(7) else raw
        table.firstOrNull { cleaned.contains(it.first, ignoreCase = true) }?.let { return it.second }
        table.firstOrNull { cleaned.equals(it.second, ignoreCase = true) }?.let { return it.second }
        return cleaned
    }
}
