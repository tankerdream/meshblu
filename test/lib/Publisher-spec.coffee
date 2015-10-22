Publisher = require '../../lib/Publisher'
{createClient} = require '../../lib/redis'

describe 'Publisher', ->
  beforeEach ->
    @redis = createClient()

  describe '->publish', ->
    describe 'when called', ->
      beforeEach (done) ->
        @sut = new Publisher namespace: 'test'
        @redis.subscribe 'test:received:mah-uuid', done

      beforeEach (done) ->
        @redis.once 'message', (@channel,@message) => done()
        @sut.publish 'received', 'mah-uuid', bee_sting: 'hey, free honey!'

      it 'should publish into redis', ->
        expect(JSON.parse @message).to.deep.equal bee_sting: 'hey, free honey!'

      it 'should publish into the correct channel', ->
        expect(@channel).to.deep.equal 'test:received:mah-uuid'

    describe 'when called again', ->
      beforeEach (done) ->
        @sut = new Publisher namespace: 'testy'
        @redis.subscribe 'testy:sent:yer-id', done

      beforeEach (done) ->
        @redis.once 'message', (@channel, @message) =>
        @sut.publish 'sent', 'yer-id', carnivorousPlant: 'Feed me, Seymour!', done

      it 'should publish into redis', ->
        expect(@message).to.exist
        expect(JSON.parse @message).to.deep.equal carnivorousPlant: 'Feed me, Seymour!'

      it 'should publish into the correct channel', ->
        expect(@channel).to.exist
        expect(@channel).to.deep.equal 'testy:sent:yer-id'