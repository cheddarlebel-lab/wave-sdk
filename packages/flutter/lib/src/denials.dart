/// SICM reason -> member-facing message. Verbatim from contract/conformance/denial-mapping.json.
const List<List<String>> _table = [
  ['Granted by provider cache', 'Access Granted'],
  ['Client not found', 'Member not found'],
  ['Blocked by schedule', 'Outside access hours'],
  ['Maximum active signins', 'Maximum active sign-ins reached'],
  ['Checkins limitation', 'Daily check-in limit reached'],
  ['Blocked by restriction', 'Membership restriction'],
  ['Blocked by client alert', 'Account alert'],
  ['Over account balance', 'Outstanding balance'],
  ['Liability release', 'Liability release required'],
  ['Scheduled visit', 'No booking found'],
  ['No member picture', 'Photo required'],
  ['Provider not found', 'System error - provider unavailable'],
  ['Inactive', 'Membership inactive'],
  ['Expired', 'Membership expired'],
];

String friendly(String? raw) {
  if (raw == null || raw.isEmpty) return 'Access denied';
  final cleaned = raw.startsWith('[mock] ') ? raw.substring(7) : raw;
  final lc = cleaned.toLowerCase();
  for (final row in _table) {
    if (lc.contains(row[0].toLowerCase())) return row[1];
  }
  for (final row in _table) {
    if (lc == row[1].toLowerCase()) return row[1];
  }
  return cleaned;
}

int get denialTableLength => _table.length;
