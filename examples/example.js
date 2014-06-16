var Koofr = require('koofr');

var client = new Koofr('https://app.koofr.net');

client.authenticate('joe@example.com', 'secret')
  .then(function () {
    return client.mounts();
  })
  .then(function (mounts) {
    return client.filesList(mounts[0].id, '/');
  })
  .then(function (files) {
    console.log(files);
  })
  .done();
