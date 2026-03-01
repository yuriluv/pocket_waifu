import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/screen_share_settings.dart';
import '../providers/global_runtime_provider.dart';
import '../providers/screen_share_provider.dart';

class ScreenShareSettingsScreen extends StatelessWidget {
  const ScreenShareSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScreenShareProvider>();
    final globalRuntimeProvider = context.watch<GlobalRuntimeProvider>();
    final masterEnabled = globalRuntimeProvider.isEnabled;
    final settings = provider.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Screen Share Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!masterEnabled)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'All features are paused. Toggle Master Switch to resume.',
              ),
            ),
          Opacity(
            opacity: masterEnabled ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !masterEnabled,
              child: Column(
                children: [
          _SectionCard(
            title: 'Permission Status',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                settings.isPermissionGranted
                    ? Icons.verified_outlined
                    : Icons.warning_amber_outlined,
                color: settings.isPermissionGranted
                    ? Colors.green
                    : Colors.orange,
              ),
              title: Text(
                settings.isPermissionGranted ? 'Granted' : 'Not Granted',
              ),
              subtitle: const Text('MediaProjection screen capture permission'),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: provider.isLoading
                        ? null
                        : settings.isPermissionGranted
                            ? provider.refreshPermission
                            : provider.requestPermission,
                    child: Text(settings.isPermissionGranted ? 'Refresh' : 'Grant'),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton(
                    onPressed: provider.isLoading || !settings.isPermissionGranted
                        ? null
                        : provider.revokePermission,
                    child: const Text('Revoke'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Capture Settings',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable screen share'),
                  value: settings.enabled,
                  onChanged: provider.setEnabled,
                ),
                const SizedBox(height: 8),
                Text('Capture interval: ${settings.captureInterval}s'),
                Slider(
                  value: settings.captureInterval.toDouble(),
                  min: 5,
                  max: 600,
                  divisions: 119,
                  label: '${settings.captureInterval}s',
                  onChanged: (value) => provider.setCaptureInterval(value.round()),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto capture'),
                  value: settings.autoCapture,
                  onChanged: provider.setAutoCapture,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Image quality'),
                  trailing: DropdownButton<ImageQuality>(
                    value: settings.imageQuality,
                    onChanged: (value) {
                      if (value != null) {
                        provider.setImageQuality(value);
                      }
                    },
                    items: ImageQuality.values
                        .map(
                          (quality) => DropdownMenuItem(
                            value: quality,
                            child: Text(quality.name),
                          ),
                        )
                        .toList(),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Max resolution'),
                  trailing: DropdownButton<int>(
                    value: settings.maxResolution,
                    onChanged: (value) {
                      if (value != null) {
                        provider.setMaxResolution(value);
                      }
                    },
                    items: const [720, 1024, 1440]
                        .map(
                          (size) => DropdownMenuItem(
                            value: size,
                            child: Text('${size}px'),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Privacy Notice',
            child: const Text(
              'Screen sharing allows the AI to analyze screenshots. '
              'Nothing is captured unless you trigger capture.',
            ),
          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
