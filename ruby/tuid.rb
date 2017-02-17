require 'securerandom'

class TUID
  attr_accessor :clock
  attr_accessor :last
  attr_accessor :seq
  attr_reader :nid

  private(:last, :seq, :nid, :clock)

  def initialize(nid: 0, clock: ->(){(Time.now.utc.to_f*1000000).to_i})
    @clock = clock
    @nid = nid & 0xff
    @seq = 0
    @last = 0
  end

  def call
    rb = SecureRandom.random_bytes(6).bytes
    us = @clock.()

    if us > @last
      @last = us
      @seq = 0
    else
      @seq += 1
      if @seq > 0xff
        @seq = 0
        @last += 1
      end
    end

    TUID.pack(rb, @last, @nid, @seq)
  end

  def self.pack(rb, t, nid, seq)
    tb = [t].pack('Q>').bytes
    tuid = []
    tuid << tb[0] << tb[1] << tb[2] << tb[3] << tb[4] << tb[5]
    packed = [0x4000800000 | tb[6] << 28 | ((tb[7] & 0xf0) << 20) | ((tb[7] & 0xf) << 18) | (seq << 10) | nid << 2 | (rb[0] & 0x3)].pack('Q>').bytes
    tuid << packed[3] << packed[4] << packed[5] << packed[6] << packed[7] << rb[1] << rb[2] << rb[3] << rb[4] << rb[5]
    format('%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x', *tuid)
  end

  class << self
    def call
      @tuid = @tuid || TUID.new(nid:255)
      @tuid.()
    end
  end

end
