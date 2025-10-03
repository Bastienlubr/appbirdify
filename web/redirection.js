(function() {
  try {
    var host = (window.location.hostname || '').toLowerCase();
    if (host === 'www.mindbird.fr') {
      var target = 'https://mindbird.fr' + window.location.pathname + window.location.search + window.location.hash;
      window.location.replace(target);
      return;
    }
    // Redirect Firebase hosting preview domains to canonical domain
    if (host.endsWith('.web.app') || host.endsWith('.firebaseapp.com')) {
      var t2 = 'https://mindbird.fr' + window.location.pathname + window.location.search + window.location.hash;
      window.location.replace(t2);
      return;
    }
  } catch (_) {}
})();


