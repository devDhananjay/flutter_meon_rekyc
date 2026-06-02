String buildPermissionInjectionScript(bool granted) {
  return '''
(function() {
  const granted = $granted;
  const permissions = ['camera', 'microphone', 'geolocation'];
  const storePermission = (name, state) => {
    try {
      sessionStorage.setItem('permission_' + name, state);
      localStorage.setItem('permission_' + name, state);
    } catch (e) {}
  };
  permissions.forEach((name) => {
    storePermission(name, granted ? 'granted' : 'prompt');
  });
  window.permissionsGranted = granted;
  if (navigator.permissions && navigator.permissions.query) {
    const originalQuery = navigator.permissions.query.bind(navigator.permissions);
    navigator.permissions.query = function(desc) {
      if (permissions.includes(desc.name)) {
        return Promise.resolve({ state: granted ? 'granted' : 'prompt', onchange: null });
      }
      return originalQuery(desc);
    };
  }
})();
''';
}

bool checkIfIpvStep(String? url) {
  if (url == null || url.isEmpty) return false;
  final lower = url.toLowerCase();
  return url.contains('face-finder.meon.co.in') ||
      lower.contains('/ipv') ||
      lower.contains('/ipv/');
}
