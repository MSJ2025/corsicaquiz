import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _contact() async {
    final uri = Uri.parse('mailto:support@example.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final name = info?.appName ?? 'Application';
        final version = info?.version ?? '';
        return Scaffold(
          appBar: AppBar(title: const Text('À propos')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Version: $version'),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Contact'),
                  onTap: _contact,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
