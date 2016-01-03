describe 's_authS_Channel', ->
  beforeEach ->
    @sut = require '../../lib/s_authS_Channel'
    @s_channel = verifyToken: sinon.stub(), fetch: sinon.stub()
    @dependencies =
      S_Channel : sinon.spy => @s_channel

  describe 'when passed an invalid token and uuid (cause there is nothing in the database)', ->
    beforeEach (done) ->
      @s_channel.verifyToken.yields new Error('Unable to find valid s_channel')
      storeResults = (@error, @returnS_Channel) => done()
      @sut 'invalid-uuid', 'invalid-token', storeResults, @dependencies

    it 'should call the callback with no s_channel', ->
      expect(@returnS_Channel).to.not.exist

    it 'should call the callback with an error', ->
      expect(@error).to.exist

  describe 'when passed an invalid token and uuid', ->
    beforeEach (done) ->
      @s_channel.verifyToken.yields null, false
      @s_channel.fetch.yields null, {}
      storeResults = (@error, @returnS_Channel) => done()
      @sut 'valid-uuid', 'invalid-token', storeResults, @dependencies

    it 'should call the callback with a token', ->
      expect(@returnS_Channel).to.not.exist

    it 'should call fetch', ->
      expect(@s_channel.fetch).to.not.have.been.called

    it 'should call the callback without an error', ->
      expect(@error).to.exist

  describe 'when passed a valid token and uuid', ->
    beforeEach (done) ->
      @s_channel.verifyToken.yields null, true
      @s_channel.fetch.yields null, {}
      storeResults = (@error, @returnS_Channel) => done()
      @sut 'invalid-uuid', 'invalid-token', storeResults, @dependencies

    it 'should call the callback with a s_channel', ->
      expect(@returnS_Channel).to.exist

    it 'should call fetch', ->
      expect(@s_channel.fetch).to.have.been.called

    it 'should call the callback without an error', ->
      expect(@error).to.not.exist
