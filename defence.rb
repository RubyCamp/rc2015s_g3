require 'dxruby'
require_relative 'ev3/ev3'

class Carrier
  LEFT_ARM_MOTOR = "A"
  RIGHT_ARM_MOTOR = "D"
  LEG_MOTOR = "B"
  DISTANCE_SENSOR = "1"
  PORT = "COM3"
  WHEEL_SPEED = 50
  BODY_SPEED = 10
  DOWN_SPEED = 10
  DEGREES_CLAW = 5000
  CLAW_POWER = 30

  attr_reader :distance
  attr_accessor :mode

  def initialize
    @brick = EV3::Brick.new(EV3::Connections::Bluetooth.new(PORT))
    @brick.connect
    @busy = false
    @grabbing = false
    @brick.run_forward(*all_motors)
  end

  # 前のタイや回転
  def go_motor(speed=WHEEL_SPEED)
   # operate do
      #@brick.reverse_polarity(*wheel_motors)
     @brick.run_forward(RIGHT_ARM_MOTOR)
     @brick.start(speed,RIGHT_ARM_MOTOR)
   # end
  end

  # 後ろのタイャ回転
  def ball_push(speed=WHEEL_SPEED)
    operate do
     @brick.reverse_polarity(LEFT_ARM_MOTOR)
     @brick.start(speed,LEFT_ARM_MOTOR)
    end
  end

  # アームを動かす BODY_MOTOR
  def raise_body(speed=BODY_SPEED)
    operate do
      prev_count = @brick.get_count(LEG_MOTOR)
      @brick.reverse_polarity(*wheel_motors)
      @brick.step_velocity(speed,70,90,*wheel_motors)
      sleep 0.1
      #判定のためのsleep
      #motor_readyの役割（ARMが動いている間もkey_contorolを判定するため）
      loop do
        key_contorol
        count = @brick.get_count(LEG_MOTOR)
        break if prev_count == count
        prev_count = count
      end
      #１秒まつ
      prev_now=Time.now
      loop do
        key_contorol
        now=Time.now
        break if now-prev_now>=1
      end
    end
  end

  # アームを下げる
  def down_body(speed=BODY_SPEED)
    operate do
    #@brick.reverse_polarity(BODY_MOTOR)
    @brick.start(speed, *wheel_motors)
    end
  end

  # 動きを止める
  def stop
    @brick.stop(true, *all_motors)
    @busy = false
  end

  # ある動作中は別の動作を受け付けないようにする
  def operate
    unless @busy
      @busy = true
      yield(@brick)
    end
  end

  # センサー情報の更新
  def update
    @distance = @brick.get_sensor(DISTANCE_SENSOR, 0)
  end

  # センサー情報の更新とキー操作受け付け
  def run
    # update
    go_motor if Input.keyDown?(K_UP)
    ball_push if Input.keyDown?(K_DOWN)
    raise_body if Input.keyDown?(K_W)
    down_body if Input.keyDown?(K_S)
    stop if [K_UP, K_DOWN, K_LEFT, K_RIGHT, K_W, K_S].all?{|key| !Input.keyDown?(key) }
  end

  # 終了処理
  def close
    stop
    @brick.clear_all
    @brick.disconnect
  end

  # "～_MOTOR" という名前の定数すべての値を要素とする配列を返す
  def all_motors
    @all_motors ||= self.class.constants.grep(/_MOTOR\z/).map{|c| self.class.const_get(c) }
  end

  def wheel_motors
    [LEFT_ARM_MOTOR, LEG_MOTOR]
  end

  #Hを入力したときの操作
  def key_contorol
    if Input.keyDown?(K_H)
      @mode = :manual
    end
  end

  def arm_move
    raise_body
    stop
    raise_body(70)
    stop
  end
end

begin
  puts "starting..."
  carrier = Carrier.new
  puts "connected..."

  carrier.go_motor
  sleep(3)
  carrier.stop

  carrier.mode = :auto

  Window.loop do
    carrier.key_contorol
    if carrier.mode == :auto
      carrier.arm_move
    else
      carrier.run
    end
    break if Input.keyDown?(K_SPACE)
  end
rescue
  p $!
  $!.backtrace.each{|trace| puts trace}
# 終了処理は必ず実行する
ensure
  puts "closing..."
  carrier.close
  puts "finished..."
end
