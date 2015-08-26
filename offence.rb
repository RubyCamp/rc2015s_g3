require 'dxruby'
require_relative 'ev3/ev3'

class Carrier
  PORT = "COM3"
  ARM_MOTOR = "D"
  LEFT_MOTOR = "C"
  RIGHT_MOTOR = "B"
  WHEEL_SPEED = 10
  DISTANCE_SENSOR = "2"
  COLOR1_SENSOR = "4"
  COLOR2_SENSOR = "3"
  ARM_SPEED = 100

  attr_reader :color1
  attr_reader :color2
  attr_reader :distance

  def initialize
    @brick = EV3::Brick.new(EV3::Connections::Bluetooth.new(PORT))
    @brick.connect
    @busy = false
  end

  # 前進する
  def run_forward(speed=WHEEL_SPEED)
    operate do
      @brick.reverse_polarity(*wheel_motors)
      @brick.start(speed, *wheel_motors)
    end
  end
  def run_forward1(speed=WHEEL_SPEED)
      @brick.reverse_polarity(LEFT_MOTOR)
      @brick.start(speed, LEFT_MOTOR)
  end
  def run_forward2(speed=WHEEL_SPEED)
      @brick.reverse_polarity(RIGHT_MOTOR)
      @brick.start(speed, RIGHT_MOTOR)
  end
  # バックする
  def run_backward(speed=WHEEL_SPEED)
    operate do
      @brick.start(speed, *wheel_motors)
    end
  end
  # 右に回る
  def turn_right(speed=WHEEL_SPEED)
      @brick.reverse_polarity(RIGHT_MOTOR)
      @brick.start(speed, *wheel_motors)
  end
  # 左に回る
  def turn_left(speed=WHEEL_SPEED)
      @brick.reverse_polarity(LEFT_MOTOR)
      @brick.start(speed, *wheel_motors)
  end
  # 羽根を回す
  def raise_arm(speed=ARM_SPEED)
    @up_speed = ARM_SPEED
    @brick.start(speed, ARM_MOTOR)
  end
  # 動きを止める
  def stop
    @brick.stop(true, *wheel_motors)
    @brick.run_forward(*wheel_motors)
    @busy = false
  end
  def arm_stop
    @brick.stop(true, *ARM_MOTOR)
    @brick.run_forward(*ARM_MOTOR)
    @busy = false
  end

  def line_tracer
    @brick.reverse_polarity(*wheel_motors)
    @brick.start(MOTOR_SPEED, *wheel_motors)
    sleep 0.1
    @brick.stop(*wheel_motors)
    # 少しだけ左に曲がる（右タイヤ前進、左タイア後退）
    @brick.reverse_polarity(RIGHT_MOTOR)
    @brick.start(MOTOR_SPEED, *wheel_motors)
    sleep 0.1
    @brick.stop(false, *wheel_motors)
    @brick.run_forward(*wheel_motors)
  end
  # ある動作中は別の動作を受け付けないようにする
  def operate
    unless @busy
      @busy = true
      yield(@brick)
    end
  end
    def update
    @color1 = @brick.get_sensor(COLOR1_SENSOR, 2)
    @color2 = @brick.get_sensor(COLOR2_SENSOR, 2)
    @distance = @brick.get_sensor(DISTANCE_SENSOR, 0)
  end
  # 終了処理
  def close
    stop
    arm_stop
    @brick.clear_all
    @brick.disconnect
  end
  # "～_MOTOR" という名前の定数すべての値を要素とする配列を返す
  def all_motors
    @all_motors ||= self.class.constants.grep(/_MOTOR\z/).map{|c| self.class.const_get(c) }
  end
  def wheel_motors
    [LEFT_MOTOR, RIGHT_MOTOR]
  end
  def runrun
    @brick.run_forward(*wheel_motors)
  end

  def on_road?(brick)
    4 != brick.get_sensor(COLOR1_SENSOR, 2)
  end

  def help
    loop do
      if on_road?(@brick)
        #前進する
        @brick.start(WHEEL_SPEED, *wheel_motors)
        sleep 0.2
        @brick.stop(false, *wheel_motors)
        break
      else
        p "ELSE"
        # 少し戻る
        @brick.reverse_polarity(*wheel_motors)
        @brick.start(WHEEL_SPEED, *wheel_motors)
        sleep 0.1
        @brick.stop(*wheel_motors)
        # 少しだけ左に曲がる（右タイヤ前進、左タイア後退）
        @brick.reverse_polarity(RIGHT_MOTOR)
        @brick.start(WHEEL_SPEED, *wheel_motors)
        sleep 0.1
        @brick.stop(false, *wheel_motors)
        @brick.run_forward(*wheel_motors)
      end
    end
  end
end

begin
  puts "starting..."
  font = Font.new(32)
  carrier = Carrier.new
  puts "connected..."
  carrier.update
  i = 0
  carrier.raise_arm
  Window.loop do
    carrier.update
    Window.draw_font(100, 200, "front > #{carrier.color1.to_i}", font)
    Window.draw_font(100, 300, "out > #{carrier.color2.to_i}", font)
    Window.draw_font(100, 400, "#{carrier.distance.to_i}cm", font)
    Window.draw_font(100, 100, "#{i}cm", font)
    break if Input.keyDown?(K_SPACE)

    carrier.run_forward
    if i == 0 && carrier.distance.to_i < 12
      carrier.stop
      sleep 3
      carrier.turn_right
      sleep
         carrier.stop
      sleep 2.0
      i = 1
    end
    carrier.run_forward
    if i == 1 && carrier.distance.to_i < 5
      i = 2
      #carrier.runrun
      carrier.stop
      sleep 3
    end
    carrier.update
    carrier.run_backward
    if i == 2 && carrier.distance.to_i > 57
      carrier.stop
      sleep 3
      carrier.turn_left
      sleep 7
         carrier.stop
      sleep 2.0
      i = 3
    end
    carrier.run_backward
    if i == 3 && carrier.distance.to_i > 62
      i = 0
      carrier.stop
      sleep 3
    end
  end
  carrier.stop
  carrier.arm_stop
rescue
  p $!
  $!.backtrace.each{|trace| puts trace}
# 終了処理は必ず実行する
ensure
  puts "closing..."
  carrier.close
  puts "finished..."
end
