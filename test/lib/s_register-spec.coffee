_      = require 'lodash'
moment = require 'moment'
s_TestDatabase = require '../s_test-database'

describe 's_register', ->
  beforeEach (done) ->
    @sut = require '../../lib/s_register'
    @s_authUser = sinon.stub()
    @register = sinon.stub()
    s_TestDatabase.open (error, s_database) =>
      @s_database = s_database
      @users  = @s_database.users

      @dependencies = {s_database: @s_database, s_authUser: @s_authUser,register: @register}
      done error

  it 'should be a function', ->
    expect(@sut).to.be.a 'function'

  describe 'when called with no params', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @sut null,null, storeDevice, @dependencies

    it 'should return an error', ->
      expect(@error.message).to.deep.equal 'Invalid owner'

    it 'should not call s_authUser()',->
      expect(@s_authUser).to.not.have.been.called

  describe 'when called with owner.uuid but without owner.psd', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @owner = {uuid:'valid-uuid'}
      @sut @owner,null,storeDevice, @dependencies

    it 'should return an error', ->
      expect(@error.message).to.deep.equal 'Invalid owner'

    it 'should not call s_authUser()',->
      expect(@s_authUser).to.not.have.been.called

  describe 'when called with an invalid owner.uuid and owner.psd', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @owner = { uuid:'invalid-uuid',psd:'invalid-psd'}
      @s_authUser.yields Error('Find error'),null
      @sut @owner,null,storeDevice, @dependencies

    it 'should call s_authUser()',->
      expect(@s_authUser).to.have.been.called

    it 'should return an error', ->
      expect(@error.message).to.deep.equal 'Find error'

  describe 'when called with an invalid owner.uuid and owner.psd', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @owner = {uuid:'invalid-uuid',psd:'invalid-psd'}
      @s_authUser.yields null,null
      @sut @owner,null,storeDevice, @dependencies

    it 'should return an error',->
      expect(@error.message).to.deep.equal 'No permission to add device'

    it 'should return no user', ->
      expect(@device).to.not.exist

  describe 'when called with a valid owner.uuid and owner.psd', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @owner = {uuid:'valid-uuid',psd:'valid-psd'}
      @s_authUser.yields null,@owner
      @register.yields Error('Register failure'),null
      @sut @owner,null,storeDevice, @dependencies

    it 'should call register()', ->
      expect(@register).to.have.been.called

    it 'should return an error',->
      expect(@error.message).to.deep.equal 'Register failure'

  describe 'when called with a valid owner.uuid and owner.psd', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @owner = {uuid:'valid-uuid',psd:'valid-psd'}
      @s_authUser.yields null,@owner
      @register.yields null,null
      @sut @owner,null,storeDevice, @dependencies

    it 'should call register()', ->
      expect(@register).to.have.been.called

    it 'should return an error',->
      expect(@error.message).to.deep.equal 'Register failure'

  describe 'when called with a valid owner.uuid and owner.psd', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @owner = {uuid:'valid-uuid',psd:'valid-psd'}
      device = {uuid:'newDeviceUuid'}
      @s_authUser.yields null,@owner
      @register.yields null,device
      @sut @owner,null,storeDevice, @dependencies

    it 'should call register()', ->
      expect(@register).to.have.been.called

    it 'should insert a device into devices list',->
      @users.find {'uuid':'valid-uuid','devices':['newDeviceUuid']}, (error, data) =>
        return done error if error?
        expect(data.devices).to.match 'newDeviceUuid'
        done()

    it 'should return no error', ->
      expect(@error).to.not.exist

    it 'should return a new device', ->
      expect(@device.uuid).to.deep.equal 'newDeviceUuid'
