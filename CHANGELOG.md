## 2.0.1

- Show API `msg` when deeplink is missing (e.g. `Client is Freezed`) instead of generic errors.
- Support `success: true` with top-level `msg` and no `data.deeplink` (same as react-native-meon-rekyc 1.0.15).

## 2.0.0

- Complete rewrite aligned with [react-native-meon-rekyc](https://www.npmjs.com/package/react-native-meon-rekyc).
- New `MeonReKYC` widget with company login, deeplink generation, and WebView flow.
- Exported helpers: `initializeReKycSession`, `companyLogin`, `getDeepLink`.
- Automatic camera, microphone, and location permission handling.
- Configurable header, refresh, and `baseUrl` (default `https://rekyc.meon.co.in`).

## 1.0.4 and earlier

- Legacy `SDKCallReKyc` widget and earlier Re-KYC integration.
