_      = require 'lodash'
moment = require 'moment'
s_TestDatabase = require '../s_test-database'

describe 's_register', ->
  beforeEach (done) ->
    @sut = require '../../lib/s_register'
    @s_authS_Channel = sinon.stub()
    @register = sinon.stub()
    s_TestDatabase.open (error, s_database) =>
      @s_database = s_database
      @s_channels  = @s_database.s_channels

      @dependencies = {s_database: @s_database, s_authS_Channel: @s_authS_Channel,register: @register}
      done error

  it 'should be a function', ->
    expect(@sut).to.be.a 'function'

  describe 'when called with no params', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @sut null,null, storeDevice, @dependencies

    it 'should return an error', ->
      expect(@error.message).to.deep.equal 'Invalid channel'

    it 'should not call s_authS_Channel()',->
      expect(@s_authS_Channel).to.not.have.been.called

  describe 'when called with s_channel.uuid but without s_channel.token', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @s_channel = {uuid:'valid-uuid'}
      @params = {channel:@s_channel}
      @sut @s_channel,@params,storeDevice, @dependencies

    it 'should return an error', ->
      expect(@error.message).to.deep.equal 'Invalid channel'

    it 'should not call s_authS_Channel()',->
      expect(@s_authS_Channel).to.not.have.been.called

  describe 'when called with an invalid s_channel.uuid and s_channel.token', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @s_channel = { uuid:'invalid-uuid',token:'invalid-token'}
      @s_authS_Channel.yields Error('Find error'),null
      @params = {channel:@s_channel}
      @sut @s_channel,@params,storeDevice, @dependencies

    it 'should call s_authS_Channel()',->
      expect(@s_authS_Channel).to.have.been.called

    it 'should return an error', ->
      expect(@error.message).to.deep.equal 'Find error'

  describe 'when called with an invalid s_channel.uuid and s_channel.token', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @s_channel = {uuid:'invalid-uuid',token:'invalid-token'}
      @s_authS_Channel.yields null,null
      @params = {channel:@s_channel}
      @sut @s_channel,@params,storeDevice, @dependencies

    it 'should return an error',->
      expect(@error.message).to.deep.equal 'No permission to add device'

    it 'should return no s_channel', ->
      expect(@device).to.not.exist

  describe 'when called with a valid s_channel.uuid and s_channel.token', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @s_channel = {uuid:'valid-uuid',token:'valid-token'}
      @s_authS_Channel.yields null,@s_channel
      @register.yields Error('Register failure'),null
      @params = {channel:@s_channel}
      @sut @s_channel,@params,storeDevice, @dependencies

    it 'should call register()', ->
      expect(@register).to.have.been.called

    it 'should return an error',->
      expect(@error.message).to.deep.equal 'Register failure'

  describe 'when called with a valid s_channel.uuid and s_channel.token', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @s_channel = {uuid:'valid-uuid',token:'valid-token'}
      @s_authS_Channel.yields null,@s_channel
      @register.yields null,null
      @params = {channel:@s_channel}
      @sut @s_channel,@params,storeDevice, @dependencies

    it 'should call register()', ->
      expect(@register).to.have.been.called

    it 'should return an error',->
      expect(@error.message).to.deep.equal 'Register failure'

  describe 'when called with a valid s_channel.uuid and s_channel.token', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @s_channel = {uuid:'valid-uuid',token:'valid-token'}
      @s_authS_Channel.yields null,@s_channel
      device = {uuid:'newDeviceUuid'}
      @register.yields null,device
      @params = {channel:@s_channel}
      @sut @s_channel,@params,storeDevice, @dependencies

    it 'should call register()', ->
      expect(@register).to.have.been.called

    it 'should insert a device into devices list',->
      @s_channels.find {'uuid':'valid-uuid','devices':['newDeviceUuid']}, (error, data) =>
        return done error if error?
        expect(data.devices).to.match 'newDeviceUuid'
        done()

    it 'should return no error', ->
      expect(@error).to.not.exist

    it 'should return a new device', ->
      expect(@device.uuid).to.deep.equal 'newDeviceUuid'
