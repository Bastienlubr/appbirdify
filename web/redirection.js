(function() {
  try {
    var host = window.location.hostname || '';
    if (host.toLowerCase() === 'www.mindbird.fr') {
      var target = 'https://mindbird.fr' + window.location.pathname + window.location.search + window.location.hash;
      window.location.replace(target);
    }
  } catch (_) {}
})();


