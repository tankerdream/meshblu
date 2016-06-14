saveDataIfAuthorized = require '../../lib/saveKey'
_ = require 'lodash'

describe 's_saveDataIfAuthorized', ->
  beforeEach ->
    @sut = saveDataIfAuthorized

    @toDevice     = {uuid: 'to-device', sendWhitelist: ['from-device'],owner:'ownerUuid'}
    @getDevice    = sinon.stub().yields null, @toDevice
    @canSend = sinon.stub()
    @logEvent = sinon.stub()
    @sendMessage = sinon.stub()
    @moment = toISOString: sinon.stub().returns('a very important date')
    @Moment = sinon.spy => @moment
    @params = {data:[
        {key: 'temperature',val:23,timestamp:'2016-01-03T15:07:31.143Z'},
        {key:'humidity',val:36}
      ]}
    @dataDB = update: sinon.stub()
    @sendConfigActivity = sinon.spy()

    @dependencies = getDevice: @getDevice, securityImpl: {canSend: @canSend}, dataDB: @dataDB, logEvent: @logEvent, moment: @Moment

    @callback = sinon.spy()

  describe 'when called with invalid data', ->
    describe 'no toDeviceUuid,key,and val ', ->
      beforeEach ->
        @sut @sendMessage, {uuid: 'from-device'}, null, null, @callback, @dependencies

      it 'should call canSend with the fromDevice, the toDevice and the query', ->
        expect(@canSend).to.not.have.been.called
        error = @callback.firstCall.args[0]
        expect(error).to.be.an.instanceOf Error
        expect(error.message).to.deep.equal 'Invalid data'

    describe 'no toDeviceUuid only', ->
      beforeEach ->
        params = @params
        @sut @sendMessage, {uuid: 'from-device'}, null,params, @callback, @dependencies

      it 'should not call canSend with the fromDevice, the toDevice and the query', ->
        expect(@canSend).to.not.have.been.called
        error = @callback.firstCall.args[0]
        expect(error).to.be.an.instanceOf Error
        expect(error.message).to.deep.equal 'Invalid data'

    describe 'no params.val and params.key', ->
      beforeEach ->
        params = @params
        params.data[0].other = 'awful'
        @sut @sendMessage, {uuid: 'from-device'}, 'to-device', params, @callback, @dependencies

      it 'should call canSend with the fromDevice, the toDevice and the query', ->
        expect(@canSend).to.not.have.been.called
        error = @callback.firstCall.args[0]
        expect(error).to.be.an.instanceOf Error
        expect(error.message).to.deep.equal 'Invalid data'

    describe 'no params.key', ->
      beforeEach ->
        params = @params
        @sut @sendMessage, {uuid: 'from-device'}, 'to-device', {val:23,other:'awful'}, @callback, @dependencies

      it 'should call canSend with the fromDevice, the toDevice and the query', ->
        expect(@canSend).to.not.have.been.called
        error = @callback.firstCall.args[0]
        expect(error).to.be.an.instanceOf Error
        expect(error.message).to.deep.equal 'Invalid data'

    describe 'no params.val', ->
      beforeEach ->
        params = @params
        @sut @sendMessage, {uuid: 'from-device'}, 'to-device', {kye:'temperature',other:'awful'}, @callback, @dependencies

      it 'should call canSend with the fromDevice, the toDevice and the query', ->
        expect(@canSend).to.not.have.been.called
        error = @callback.firstCall.args[0]
        expect(error).to.be.an.instanceOf Error
        expect(error.message).to.deep.equal 'Invalid data'

  describe 'when called with the valid data', ->
    beforeEach ->
      params = @params
      @sut @sendMessage, {uuid: 'from-device'}, 'to-device', {key: 'temperature',val:23,other:'awful'}, @callback, @dependencies

    it 'should call canSend with the fromDevice, the toDevice and the query', ->
      expect(@canSend).to.have.been.calledWith {uuid: 'from-device'}, @toDevice, {key: 'temperature',val:23,other:'awful'}

    describe 'when canSend yields an error', ->
      beforeEach ->
        params = @params
        @canSend.yield new Error('Something really, really bad happened')

      it 'should call the callback with the error', ->
        expect(@callback).to.have.been.called

        error = @callback.firstCall.args[0]
        expect(error).to.be.an.instanceOf Error
        expect(error.message).to.deep.equal 'Something really, really bad happened'

    describe 'when canSend yields false', ->
      beforeEach ->
        @canSend.yield null, false

      it 'should yield an error', ->
        expect(@callback).to.have.been.called

        error = @callback.firstCall.args[0]
        expect(error).to.be.an.instanceOf Error
        expect(error.message).to.deep.equal 'Owner has no permission to save data'

    describe 'when canSend yields true', ->
      beforeEach ->
        @canSend.yield null, true

      it 'should not have called the callback yet', ->
        expect(@callback).to.have.not.been.called #yet

      it 'should call update on the database', ->
        expect(@dataDB.update).to.have.been.calledWith {userUuid: 'ownerUuid'},{$push:{temperature:{val:23,uuid:"to-device",timestamp:"a very important date"}}}

      describe 'when update yields an error', ->
        beforeEach ->
          @dataDB.update.yield new Error('data failed to update')

        it 'should call the callback with the error', ->
          expect(@callback).to.have.been.called

          error = @callback.firstCall.args[0]
          expect(error).to.be.an.instanceOf Error
          expect(error.message).to.deep.equal 'data failed to update'

      describe 'when update yields no error', ->
        beforeEach ->
          @dataDB.update.yield null, true

        it 'should call the callback without an error', ->
          expect(@callback).to.have.been.called

          error = @callback.firstCall.args[0]
          saved = @callback.firstCall.args[1]
          expect(error).not.to.be
          expect(saved).to.be.true