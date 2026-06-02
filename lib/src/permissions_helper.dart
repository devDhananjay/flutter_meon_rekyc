import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsHelper {
  static Future<bool> requestReKycPermissions({bool showAlert = true}) async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
    ].request();

    final granted = statuses.values.every((status) => status.isGranted);

    if (!granted && showAlert) {
      // Caller shows dialog when context is available.
    }

    return granted;
  }

  static Future<void> showPermissionDialog(BuildContext context) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Camera and microphone access are required for video verification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AppSettings.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await requestReKycPermissions(showAlert: false);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  static Future<void> openAppSettings() => AppSettings.openAppSettings();
}
