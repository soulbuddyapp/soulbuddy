import '../domain/guard_definition.dart';

abstract final class BundledGuardCatalogue {
  static final DateTime _reviewedAt = DateTime.utc(2026, 8, 29);

  static final List<GuardDefinition> definitions = List.unmodifiable([
    GuardDefinition(
      id: 'dns-adguard-family',
      contentVersion: 1,
      kind: GuardKind.contentFilter,
      title: 'AdGuard Family Protection',
      description:
          'Route DNS through AdGuard Family Protection to block adult sites and enable safe-search features where supported.',
      steps: const [
        'Open the DNS settings for the device or router you want to protect.',
        'Use AdGuard Family Protection: 94.140.14.15 and 94.140.15.16, or the family DNS-over-HTTPS/TLS endpoint shown in the official guide.',
        'Save the setting and verify the device is using the chosen resolver.',
        'If changing the setting is part of the problem, let a trusted person keep the administrator password where practical.',
      ],
      platforms: const {
        GuardPlatform.router,
        GuardPlatform.android,
        GuardPlatform.ios,
        GuardPlatform.windows,
        GuardPlatform.macos,
        GuardPlatform.linux,
      },
      goalContextTags: const {'sexual_compulsion', 'digital_distraction'},
      reviewedAt: _reviewedAt,
      sourceUri: Uri.parse('https://adguard-dns.io/en/public-dns.html'),
    ),
    GuardDefinition(
      id: 'dns-cleanbrowsing-family',
      contentVersion: 1,
      kind: GuardKind.contentFilter,
      title: 'CleanBrowsing Family Filter',
      description:
          'Use CleanBrowsing Family Filter to block adult and explicit sites, common bypass domains, and enable safe-search controls.',
      steps: const [
        'Open DNS settings on the device or router you want to protect.',
        'Use 185.228.168.168 and 185.228.169.168, or the Family Filter encrypted-DNS endpoint from the official setup guide.',
        'Save the setting and test that the Family Filter is active.',
        'Where appropriate, give the settings or router administrator password to a trusted person instead of keeping an easy bypass.',
      ],
      platforms: const {
        GuardPlatform.router,
        GuardPlatform.android,
        GuardPlatform.ios,
        GuardPlatform.windows,
        GuardPlatform.macos,
        GuardPlatform.linux,
      },
      goalContextTags: const {'sexual_compulsion', 'digital_distraction'},
      reviewedAt: _reviewedAt,
      sourceUri: Uri.parse('https://cleanbrowsing.org/filters'),
    ),
    GuardDefinition(
      id: 'dns-nextdns-configured',
      contentVersion: 1,
      kind: GuardKind.contentFilter,
      title: 'Configured NextDNS',
      description:
          'Use a personal NextDNS configuration when you want blocklists, parental controls, and device-specific DNS settings you can tune yourself.',
      steps: const [
        'Create or open your NextDNS configuration.',
        'Choose the protection, blocklist, parental-control, and deny-list settings that match the door you want closed.',
        'Open the Setup page for that configuration and follow the instructions for your device or router.',
        'Test the configuration after setup. If easy changes defeat the wall, consider giving account or device administration to a trusted person.',
      ],
      platforms: const {
        GuardPlatform.router,
        GuardPlatform.android,
        GuardPlatform.ios,
        GuardPlatform.windows,
        GuardPlatform.macos,
        GuardPlatform.linux,
      },
      goalContextTags: const {'sexual_compulsion', 'digital_distraction'},
      reviewedAt: _reviewedAt,
      sourceUri: Uri.parse('https://help.nextdns.io/'),
    ),
    GuardDefinition(
      id: 'os-restrictions',
      contentVersion: 1,
      kind: GuardKind.osRestriction,
      title: 'Use device restrictions',
      description:
          'Use the operating system’s own account, app, web, or installation restrictions to make the unwanted path harder to reopen.',
      steps: const [
        'Identify the device setting that controls the app, browser, account, installation, or web access you want restricted.',
        'Enable the narrowest restriction that closes that path without blocking necessary use.',
        'Where practical, let a trusted person hold the PIN or administrator credential.',
        'Record only what you chose here; SoulBuddy does not claim to verify that the restriction remains enabled.',
      ],
      platforms: const {
        GuardPlatform.android,
        GuardPlatform.ios,
        GuardPlatform.windows,
        GuardPlatform.macos,
      },
      goalContextTags: const {
        'sexual_compulsion',
        'gambling',
        'digital_distraction',
      },
      reviewedAt: _reviewedAt,
    ),
    GuardDefinition(
      id: 'remove-access',
      contentVersion: 1,
      kind: GuardKind.appOrAccountRemoval,
      title: 'Remove the easy access',
      description:
          'Delete or sign out of the app, account, saved shortcut, stored payment method, or other access point that keeps the behavior one tap away.',
      steps: const [
        'Name the exact app, account, bookmark, file, shortcut, or stored credential that opens the door.',
        'Remove, sign out, delete, or disable that access point.',
        'Remove saved credentials or recovery shortcuts when doing so is safe and does not risk losing something you need.',
        'Write down any necessary recovery information somewhere appropriate instead of keeping the unwanted path frictionless.',
      ],
      platforms: const {GuardPlatform.any, GuardPlatform.account},
      goalContextTags: const {
        'sexual_compulsion',
        'gambling',
        'nicotine',
        'alcohol',
        'digital_distraction',
      },
      reviewedAt: _reviewedAt,
    ),
    GuardDefinition(
      id: 'physical-boundary',
      contentVersion: 1,
      kind: GuardKind.physicalBoundary,
      title: 'Move the trigger out of reach',
      description:
          'Change the physical environment so the unwanted behavior requires a deliberate reversal instead of a reflex.',
      steps: const [
        'Identify the place, object, time, or routine that repeatedly opens the door.',
        'Move the device, substance, card, cash, or other trigger out of that place or routine.',
        'Choose a replacement location or routine before the vulnerable time arrives.',
      ],
      platforms: const {GuardPlatform.physical},
      goalContextTags: const {
        'sexual_compulsion',
        'gambling',
        'nicotine',
        'alcohol',
        'digital_distraction',
      },
      reviewedAt: _reviewedAt,
    ),
    GuardDefinition(
      id: 'payment-friction',
      contentVersion: 1,
      kind: GuardKind.paymentFriction,
      title: 'Add payment friction',
      description:
          'Remove instant payment paths or add limits so spending requires a pause or another person’s involvement.',
      steps: const [
        'Remove saved cards, wallets, or one-click payment methods from the unwanted service.',
        'Use bank or wallet limits where available and appropriate.',
        'For high-risk spending, consider a trusted-person control or provider self-exclusion tool rather than relying on willpower alone.',
      ],
      platforms: const {GuardPlatform.account},
      goalContextTags: const {'gambling', 'nicotine', 'alcohol'},
      reviewedAt: _reviewedAt,
    ),
    GuardDefinition(
      id: 'trusted-person-control',
      contentVersion: 1,
      kind: GuardKind.trustedPersonControl,
      title: 'Give one key to someone you trust',
      description:
          'Where it is safe and practical, let a trusted person hold the password, PIN, approval, or check-in that makes an impulsive reversal harder.',
      steps: const [
        'Choose one specific control you are willing to hand over.',
        'Agree what the trusted person will hold or approve and what they should not access.',
        'Keep the arrangement narrow enough to respect privacy and safety.',
        'Use the arrangement as practical friction, not as punishment or surveillance.',
      ],
      platforms: const {GuardPlatform.any},
      goalContextTags: const {
        'sexual_compulsion',
        'gambling',
        'nicotine',
        'alcohol',
        'digital_distraction',
      },
      reviewedAt: _reviewedAt,
    ),
  ]);

  static GuardDefinition? find(String id) {
    for (final definition in definitions) {
      if (definition.id == id && !definition.archived) return definition;
    }
    return null;
  }
}
