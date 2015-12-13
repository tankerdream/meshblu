describe 's_authUser', ->
  beforeEach ->
    @sut = require '../../lib/s_authUser'
    @user = verifyPsd: sinon.stub(), fetch: sinon.stub()
    @dependencies =
      User : sinon.spy => @user

  describe 'when passed an invalid psd and uuid (cause theres nothing in the database)', ->
    beforeEach (done) ->
      @user.verifyPsd.yields new Error('Unable to find valid user')
      storeResults = (@error, @returnUser) => done()
      @sut 'invalid-uuid', 'invalid-psd', storeResults, @dependencies

    it 'should call the callback with no user', ->
      expect(@returnUser).to.not.exist

    it 'should call the callback with an error', ->
      expect(@error).to.exist

  describe 'when passed an invalid psd and uuid', ->
    beforeEach (done) ->
      @user.verifyPsd.yields null, false
      @user.fetch.yields null, {}
      storeResults = (@error, @returnUser) => done()
      @sut 'valid-uuid', 'invalid-psd', storeResults, @dependencies

    it 'should call the callback with a psd', ->
      expect(@returnUser).to.not.exist

    it 'should call fetch', ->
      expect(@user.fetch).to.not.have.been.called

    it 'should call the callback without an error', ->
      expect(@error).to.exist

  describe 'when passed a valid psd and uuid', ->
    beforeEach (done) ->
      @user.verifyPsd.yields null, true
      @user.fetch.yields null, {}
      storeResults = (@error, @returnUser) => done()
      @sut 'invalid-uuid', 'invalid-psd', storeResults, @dependencies

    it 'should call the callback with a user', ->
      expect(@returnUser).to.exist

    it 'should call fetch', ->
      expect(@user.fetch).to.have.been.called

    it 'should call the callback without an error', ->
      expect(@error).to.not.exist
