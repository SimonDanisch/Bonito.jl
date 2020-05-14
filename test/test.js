const JSModule = (function () {
  function testsetter(x) {
    update_obs(x, 2);
  }

  return {
    testsetter: testsetter,
  }
})();
