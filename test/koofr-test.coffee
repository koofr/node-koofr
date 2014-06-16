os = require('os')
fs = require('fs')
q = require('q')
assert = require('assert')
should = require('chai').should()
require('mocha-as-promised')()

Koofr = require('../src/koofr')

consume = (stream) ->
  defer = q.defer()

  content = ''

  stream.on 'data', (data) ->
    content += data

  stream.on 'end', ->
    defer.resolve(content)

  defer.promise

describe 'Koofr', ->
  apiBase = process.env.KOOFR_API_BASE
  email = process.env.KOOFR_EMAIL
  password = process.env.KOOFR_PASSWORD

  should.exist(apiBase, 'Missing env variable KOOFR_API_BASE')
  should.exist(email, 'Missing env variable KOOFR_EMAIL')
  should.exist(password, 'Missing env variable KOOFR_PASSWORD')

  koofr = new Koofr(apiBase)

  authenticate = ->
    koofr.authenticate email, password

  describe 'Auth', ->
    it 'should authenticate', ->
      koofr.token = null

      authenticate().then(->
        should.exist(koofr.token)
      , (err) ->
        should.not.exist(err)
      )

  describe 'API', ->
    beforeEach ->
      if not koofr.token?
        authenticate()

    describe 'Mounts', ->
      it 'should list mounts', ->
        koofr.mounts().then((mounts) ->
          (mounts.length > 0).should.be.true
        , (err) ->
          should.not.exist(err)
        )

    describe 'Files', ->
      mount = null

      beforeEach ->
        koofr.mounts().then((mounts) ->
          mount = mounts[0]
        ).then ->
          koofr.filesList(mount.id, '/').then (files) ->
            q.all(files.map((file) ->
              koofr.filesRemove(mount.id, '/' + file.name)
            ))

      it 'should list files', ->
        koofr.filesList(mount.id, '/').then((files) ->
          files.length.should.equal(0)
        )

      it 'should get file info', ->
        koofr.filesInfo(mount.id, '/').then((info) ->
          info.name.should.equal('')
        )

      it 'should create new folder', ->
        koofr.filesMkdir(mount.id, '/', 'folder')

      it 'should rename a folder', ->
        koofr.filesMkdir(mount.id, '/', 'folder').then ->
          koofr.filesRename(mount.id, '/folder', 'new folder name').then ->
            koofr.filesInfo(mount.id, '/folder').fail((err) ->
              should.exist(err)

              koofr.filesInfo(mount.id, '/new folder name').then((info) ->
                should.exist(info)
              )
            )

      it 'should copy a folder', ->
        koofr.filesMkdir(mount.id, '/', 'folder').then ->
          koofr.filesCopy(mount.id, '/folder', mount.id, '/folder copy').then ->
            koofr.filesInfo(mount.id, '/folder').then((info) ->
              should.exist(info)

              koofr.filesInfo(mount.id, '/folder copy').then((info) ->
                should.exist(info)
              )
            )

      it 'should move a folder', ->
        koofr.filesMkdir(mount.id, '/', 'folder').then ->
          koofr.filesCopy(mount.id, '/folder', mount.id, '/folder moved').then ->
            koofr.filesInfo(mount.id, '/folder').fail((err) ->
              should.exist(err)

              koofr.filesInfo(mount.id, '/folder moved').then((info) ->
                should.exist(info)
              )
            )

      it 'should remove file', ->
        koofr.filesMkdir(mount.id, '/', 'folder').then ->
          koofr.filesRemove(mount.id, '/folder')

      it 'should upload file', ->
        koofr.filesPut(mount.id, '/', 'test.txt', 'foo').then (file) ->
          file.name.should.equal('test.txt')

      it 'should upload file from stream', ->
        tmpPath = os.tmpDir() + '/koofr-upload-test'
        fs.writeFileSync(tmpPath, 'test123')
        stream = fs.createReadStream(tmpPath)

        koofr.filesPut(mount.id, '/', 'test.txt', stream).then (file) ->
          file.name.should.equal('test.txt')

          koofr.filesGet(mount.id, '/test.txt').then (res) ->
            consume(res).then (content) ->
              content.should.equal('test123')

      it 'should download file', ->
        koofr.filesPut(mount.id, '/', 'test.txt', 'foo').then ->
          koofr.filesGet(mount.id, '/test.txt').then (res) ->
            consume(res).then (content) ->
              content.should.equal('foo')

      it 'should download file range', ->
        koofr.filesPut(mount.id, '/', 'test.txt', 'test123').then ->
          koofr.filesGet(mount.id, '/test.txt', 2, 5).then (res) ->
            consume(res).then (content) ->
              content.should.equal('st12')
