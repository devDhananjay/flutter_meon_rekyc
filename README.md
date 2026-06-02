# flutter_meon_rekyc

Re-KYC SDK for Flutter. Company login karta hai, deeplink generate karta hai, aur Re-KYC journey WebView mein open karta hai — same flow as [react-native-meon-rekyc](https://www.npmjs.com/package/react-native-meon-rekyc).

## Installation

`pubspec.yaml` mein add karo:

```yaml
dependencies:
  flutter_meon_rekyc: ^2.0.0
```

Phir:

```bash
flutter pub get
```

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

`android/app/build.gradle` — `minSdkVersion` at least **21**.

### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>Camera permission is required for Re-KYC verification</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone permission is required for Re-KYC verification</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location permission is required for Re-KYC verification</string>
```

iOS deployment target: **12.0+** recommended.

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:flutter_meon_rekyc/flutter_meon_rekyc.dart';

class ReKycScreen extends StatelessWidget {
  const ReKycScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeonReKYC(
        username: 'your@email.com',
        password: 'your-password',
        companyId: '1',
        workflowId: '7cd3b329-7b79-46c4-b4f3-abb6664f99f4',
        clientCode: 'meon1',
        baseUrl: 'https://rekyc.meon.co.in',
        onSuccess: (data) => debugPrint('Re-KYC ready: $data'),
        onError: (error) => debugPrint('Re-KYC error: $error'),
        onClose: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
```

## API Flow

1. `POST /v1/company/company-login` — `username`, `password`, `company_id`
2. `GET /v1/company/get_deep_link/{workflow_id}/{client_code}` — `Authorization: Bearer <token>`
3. `data.deeplink` WebView mein open

## Widget parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `username` | `String` | Yes | - | Company login username |
| `password` | `String` | Yes | - | Company login password |
| `companyId` | `String` | Yes | - | Company ID |
| `workflowId` | `String` | Yes | - | Workflow ID |
| `clientCode` | `String` | Yes | - | Client code |
| `baseUrl` | `String` | No | `https://rekyc.meon.co.in` | API base URL |
| `onSuccess` | `Function` | No | - | Deeplink ready |
| `onError` | `Function` | No | - | API / WebView error |
| `onClose` | `Function` | No | - | User closed flow |
| `showHeader` | `bool` | No | `true` | Header bar |
| `headerTitle` | `String` | No | `Re-KYC` | Header title |
| `showRefreshButton` | `bool` | No | `true` | Header refresh (⟳) |
| `autoRequestPermissions` | `bool` | No | `true` | Camera / mic / location |

## Exported API helpers

```dart
import 'package:flutter_meon_rekyc/flutter_meon_rekyc.dart';

final session = await initializeReKycSession(
  username: '...',
  password: '...',
  companyId: '1',
  workflowId: '...',
  clientCode: 'meon1',
);

// Or step-by-step:
final login = await companyLogin(...);
final link = await getDeepLink(...);
```

## License

MIT
