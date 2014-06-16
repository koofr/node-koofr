# Koofr Node.js SDK

This is a Node.js SDK for easy interaction with Koofr service.

## Install

```
npm install koofr
```

## Example

This is a basic example that lists files in first mount. For detailed usage take a look at tests.

```javascript
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
```

## Running tests

```
KOOFR_API_BASE="https://app.koofr.net" KOOFR_EMAIL="joe@example.com" KOOFR_PASSWORD="secret" npm test
```

## Basic concepts

### Mounts

Mounts are the central concept to Koofr. Each mount is a virtual filesystem root; it may be a physical device, a shared folder or something else. Each mount has a unique identifier to reference it.

A mount may contain other mounts. For example: you have a storage device *My Place* where you have a folder *Pictures*. If you share *Pictures* you will implicitly create a new mount. So a picture stored under `My Place | /Pictures/01.jpg` will also be accessible through `Pictures | /01.jpg`.

### Files

Each file is identified by a pair of mount identifier and a path. Therefore all file operations take a mount id (to specify which filesystem root to use) and a path.

Files stored in Koofr are immutable. This means you cannot modify file after you upload it. You can however delete it and replace it with a modified version - Koofr will detect this as a modification.
