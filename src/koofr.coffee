url = require('url')
_ = require('lodash')
q = require('q')
HttpClient = require('simple-http-client')

# @private
fmt = (path, query) ->
  url.format pathname: path, query: query

# @private
random32 = ->
  _.range(32).map(-> (Math.random()*16 >> 0).toString(16)).join('')

# Koofr API client
# 
class Koofr
  # Construct a new client
  #
  # @param [String] endpoint API base URL (e.g. https://app.koofr.net)
  # @return [Koofr] Koofr client instance
  #
  constructor: (endpoint) ->
    @options = {}
    @httpClient = new HttpClient()

    endpoint = endpoint.slice(0, -1) if endpoint.slice(-1) == '/'

    _.merge(@options, url.parse(endpoint))

  # Authenticate the user
  #
  # @param [String] email User's email or username
  # @param [String] password User's password
  # @return [Koofr] Koofr client instance
  #
  authenticate: (email, password) =>
    @request('GET', '/token', headers:
      'X-Koofr-Email': email
      'X-Koofr-Password': password
    ).then (res) =>
      if res.headers['x-koofr-token']
        @token = res.headers['x-koofr-token']
        @
      else
        throw new Error('Authentication failed')

  # Internal helper to make requests to API
  #
  # @param [String] method HTTP method (e.g. GET)
  # @param [String] path HTTP path (e.g. /api/v2/user)
  # @param [String] options Additional options for simple-http-client
  # @return [http.IncomingMessage] HTTP response
  #
  request: (method, path, options) =>
    if _.isFunction(options)
      callback = options
      options = {}

    options = _.merge(headers: {}, @options, options)

    file = options.file
    boundaryKey = null
    
    if file?
      delete options.file
      options.pipeReq = yes

      boundaryKey = random32()

      options.headers['Content-Type'] = "multipart/form-data; boundary=\"#{boundaryKey}\""

    if @token?
      options.headers['Authorization'] = "Token #{@token}"

    defer = q.defer()

    request = @httpClient.request(method, path, options, defer.makeNodeResolver())

    if file?
      request.write "--#{boundaryKey}\r\n" +
        "Content-Type: application/octet-stream\r\n" +
        "Content-Disposition: form-data; name=\"file\"; filename=\"#{file.name}\"\r\n" +
        "Content-Transfer-Encoding: binary\r\n\r\n"

      if file.stream.on?
        file.stream.on('end', ->
          request.end "\r\n--#{boundaryKey}--"
        ).pipe(request, end: false)
      else
        request.write(file.stream)
        request.end "\r\n--#{boundaryKey}--"

    process.nextTick ->
      defer.notify(request)

    defer.promise

  # List mounts
  #
  # @return [Array<Object>] Array of mounts
  mounts: =>
    @request('GET', "/api/v2/mounts").then (res) =>
      throw res if res.statusCode != 200
      res.json.mounts

  # List files
  #
  # @param [String] mountId Mount ID
  # @param [String] path Path to files
  # @return [Array<Object>] Array of files
  #
  filesList: (mountId, path) =>
    @request('GET', fmt("/api/v2/mounts/#{mountId}/files/list", path: path)).then (res) =>
      throw res if res.statusCode != 200
      res.json.files

  # File info
  #
  # @param [String] mountId Mount ID
  # @param [String] path Path to file
  # @return [Object] File info
  #
  filesInfo: (mountId, path) =>
    @request('GET', fmt("/api/v2/mounts/#{mountId}/files/info", path: path)).then (res) =>
      throw res if res.statusCode != 200
      res.json

  # Create a new folder/directory
  #
  # @param [String] mountId Mount ID
  # @param [String] path Parent path
  # @param [String] name New folder/directory name
  #
  filesMkdir: (mountId, path, name) =>
    p = fmt("/api/v2/mounts/#{mountId}/files/folder", path: path)
    json =
      name: name

    @request('POST', p, json: json).then (res) =>
      throw res if res.statusCode != 200

  # Rename a file/directory
  #
  # @param [String] mountId Mount ID
  # @param [String] path Path to file/directory
  # @param [String] name New name
  #
  filesRename: (mountId, path, name) =>
    p = fmt("/api/v2/mounts/#{mountId}/files/rename", path: path)
    json =
      name: name

    @request('PUT', p, json: json).then (res) =>
      throw res if res.statusCode != 200

  # Remove a file/directory
  #
  # @param [String] mountId Mount ID
  # @param [String] path Path to file/directory
  #
  filesRemove: (mountId, path) =>
    @request('DELETE', fmt("/api/v2/mounts/#{mountId}/files/remove", path: path)).then (res) =>
      throw res if res.statusCode != 200

  # Copy a file/directory
  #
  # @param [String] mountId Mount ID
  # @param [String] path Path to file/directory
  # @param [String] toMountId Destination mount ID
  # @param [String] toPath Destination path
  #
  filesCopy: (mountId, path, toMountId, toPath) =>
    p = fmt("/api/v2/mounts/#{mountId}/files/copy", path: path)
    json =
      toMountId: toMountId
      toPath: toPath

    @request('PUT', p, json: json).then (res) =>
      throw res if res.statusCode != 200

  # Move a file/directory
  #
  # @param [String] mountId Mount ID
  # @param [String] path Path to file/directory
  # @param [String] toMountId Destination mount ID
  # @param [String] toPath Destination path
  #
  filesMove: (mountId, path, toMountId, toPath) =>
    p = fmt("/api/v2/mounts/#{mountId}/files/move", path: path)
    json =
      toMountId: toMountId
      toPath: toPath

    @request('PUT', p, json: json).then (res) =>
      throw res if res.statusCode != 200

  # Get (download) a file/directory
  #
  # @param [String] mountId Mount ID
  # @param [String] path Path to file/directory
  # @param [Number] start Start offset (optional)
  # @param [Number] end End offset (optional)
  # @return [http.IncomingMessage] HTTP response (file content stream)
  #
  filesGet: (mountId, path, start, end) =>
    link = "/content/api/v2/mounts/#{mountId}/files/get?path=#{encodeURIComponent(path)}"

    headers = {}

    if start? and end?
      headers['Range'] = "bytes=#{start}-#{end}"

    @request('GET', link, headers: headers, pipeRes: yes).then (res) ->
      if res.statusCode != 200 && res.statusCode != 206
        res.on 'data', (->)
        throw res

      res

  # Put (upload) a file
  #
  # @param [String] mountId Mount ID
  # @param [String] path Path to parent directory
  # @param [String] name New file name
  # @param [String, Buffer, Stream] data File content (String, Buffer or Stream)
  # @return [Object] Upload info
  #
  filesPut: (mountId, path, name, data) =>
    link = "/content/api/v2/mounts/#{mountId}/files/put?path=#{encodeURIComponent(path)}"

    file =
      name: name
      stream: data

    @request('POST', link, file: file).then (res) ->
      throw res if res.statusCode != 200

      name: res.json[0].name

module.exports = Koofr
