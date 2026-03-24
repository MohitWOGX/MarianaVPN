class VpnServer {
  final String name;
  final String country;
  final String flagEmoji;
  final String ovpnAsset;
  final int ping;

  const VpnServer({
    required this.name,
    required this.country,
    required this.flagEmoji,
    required this.ovpnAsset,
    required this.ping,
  });

  // ─── REAL servers from your .ovpn files ───────────────────────────────────
  // Username is "openvpn" for both (OVPN_ACCESS_SERVER_USERNAME=openvpn)
  // Password is passed in from VpnProvider at connect time
  static const String vpnUsername = 'openvpn';

  // ⚠️  PUT YOUR REAL PASSWORD HERE (the one from your credentials.txt)
  static const String vpnPassword = 'Simon99007@';

  static const List<VpnServer> servers = [
    VpnServer(
      name: 'Mumbai',
      country: 'India',
      flagEmoji: '🇮🇳',
      ovpnAsset: 'assets/ovpn/mumbai.ovpn',
      ping: 12,
    ),
    VpnServer(
      name: 'Singapore',
      country: 'Singapore',
      flagEmoji: '🇸🇬',
      ovpnAsset: 'assets/ovpn/singapore.ovpn',
      ping: 48,
    ),
  ];
}
