require 'homebus'
require 'homebus_app'
require 'mqtt'
require 'dotenv'
require 'net/http'
require 'json'


class SmokeOStatHomeBusApp < HomeBusApp
  def initialize(options)
    Dotenv.load

    @fan_controller_url = ENV["FAN_CONTROLLER_URL"]
    @smoke_sensor_uuid = ENV["SMOKE_SENSOR_UUID"]
    @access_uuid = ENV["ACCESS_UUID"]
    @tick_uuid = ENV['TICK_UUID']
    @smoke_threshold = ENV["SMOKE_THRESHOLD"].to_i
    @light_threshold = ENV["LIGHT_THRESHOLD"].to_i

    @current_state = nil
    @off_time = 0

    @subscribed = false

    super
  end

  def setup!
    @current_state = _fan_state
    if @current_state
      @current_state_start = Time.now
    end
  end

  def work!
    unless @subscribed
      subscribe! '/tick'
      subscribe_to_devices! @smoke_sensor_uuid, @access_uuid
      @subscribed = true
    end

    listen!
  end

  def _is_smoky?
    unless _is_stale? @last_air_update_time
      @last_air_update[:pm1] > @smoke_threshold || @last_air_update[:pm25] > @smoke_threshold || @last_air_update[:pm10] > @smoke_threshold
    end
  end

  def _is_bright?
    unless _is_stale? @last_light_update_time
      @last_light_update[:lux] > @light_threshold
    end
  end

  def _is_in_use?
    unless _is_stale? @last_access_update_time
      @last_access_update[:'org.pdxhackerspace.access'] && @last_access_update[:'org.pdxhackerspace.access'][:door] == 'laser-access' && @last_access_update[:'org.pdxhackerspace.access'][:action] == 'enabled'
    end
  end

  def _should_still_be_running?(tick)
    @off_time > 0 && tick[:epoch] > @off_time
  end

  def _is_stale?(time)
    time.nil? || Time.now - time > 5*60
  end

  def _is_msg_time?(msg)
    if msg[:'org.homebus.tick']
      @last_time_update = msg[:'org.homebus.tick']
    end
  end

  def _is_msg_air?(msg)
    if msg[:air]
      @last_air_update_time = Time.now
      @last_air_update = msg[:air]
    end
  end

  def _is_msg_light?(msg)
    if msg[:light]
      @last_light_update_time = Time.now
      @last_light_update = msg[:light]
    end
  end

  def _is_msg_access?(msg)
    if msg[:'org.pdxhackerspace.access']
      @last_access_update = Time.now
      @last_access_update = msg[:'org.pdxhackerspace.access']
    end
  end

  def _should_update_fan_state?(tick)
    tick[:second] == 0
  end

  def receive!(msg)
begin
    triggers = []

    fan_should_be_on = nil

    tick = _is_msg_time? msg
    air = _is_msg_air? msg
    light = _is_msg_light? msg
    access = _is_msg_access? msg

    if tick.nil? || tick[:second] == 0
      pp msg
    end

    if tick && _should_still_be_running?(tick)
      fan_should_be_on = false
      triggers.push 'on time exceeded'
    end

    if tick  && tick[:second] == 0
      puts "MSG"
      pp msg
    end
  
    if _is_bright?
      triggers.push "light at #{@last_light_update[:lux]} (> #{@light_threshold})"
      fan_should_be_on = true
    end

    if _is_smoky?
      triggers.push "air at #{@last_air_update[:pm1]}/@last_air_update[:pm25]}/@last_air_update[:pm10] (> #{@smoke_threshold})"
      fan_should_be_on = true
    end

    if _is_in_use?
      triggers.push "laser enabled by #{@last_access_update[:person]}"
      fan_should_be_on = true
    end

    if tick && _should_update_fan_state?(tick)
      puts 'getting fan state'
      @current_state = _fan_state
      puts @current_state
    end

    if fan_should_be_on.nil?
      if @off_time < Time.now.to_i
        @off_time = Time.now.to_i + 5*60
      end
      return
    end

    puts 'cs: ', @current_state, 'fsbo: ', fan_should_be_on, 'triggers: ', triggers

    if fan_should_be_on && @current_state == 'on'
      @off_time = Time.now.to_i + 5*60
      return
    end

    if fan_should_be_on == false && @current_state == 'off'
      return
    end

    if fan_should_be_on
      _fan_on!
      @off_time = Time.now.to_i + 15*60
    elsif fan_should_be_on == false && Time.now.to_i > @off_time
      _fan_off!
    end

    sleep(5)

    if @options[:test]
      @current_state = fan_should_be_on ? 'on' : 'off'
    else
      @current_state = _fan_state
    end

    result = {
      id: @uuid,
      timestamp: Time.now.to_i,
      'org.pdxhackerspace.smokeostat': {
                                         state: fan_should_be_on ? 'on' : 'off',
                                         triggers: triggers
                                       }
    }

    puts 'SMOKEOSTAT'
    pp result

    publish! JSON.generate(result)
rescue => error
    puts "ERROR ", error, error.backtrace
end
  end

  # returns 'on' if the fan is currently on, 'off' if not and nil if we can't reach it
  def _fan_state
    begin
      # https://github.com/arendst/Tasmota/wiki/commands
      # http://#{@fan_controller}/cm?cmnd=Power%20On
      url = @fan_controller_url + '/cm?cmnd=Power'
      puts url
      uri = URI(url)
      puts 'uri'
      pp uri

      result = Net::HTTP.get(uri)
      puts 'result'
      pp result

      if options[:verbose]
        puts 'power response (raw)'
        pp result
      end

      tasmota = JSON.parse result, symbolize_names: true

      if options[:verbose]
        puts 'power response (JSON):'
        pp tasmota
      end

      tasmota[:POWER]

      if tasmota[:POWER] == 'ON'
        return 'on'
      end

      return 'off'
    rescue
      return nil
    end
  end

  # https://github.com/arendst/Tasmota/wiki/commands
  def _fan_on!
    begin
      return if @options[:test]

      uri = URI(@fan_controller_url + '/cm?cmnd=Power%20On')
      result = Net::HTTP.get(uri)

      return true
    rescue
      return false
    end
  end

  def _fan_off!
    begin
      return if @options[:test]

      uri = URI(@fan_controller_url + '/cm?cmnd=Power%20Off')
      result = Net::HTTP.get(uri)

      return true
    rescue
      return false
    end
  end



  def manufacturer
    'HomeBus'
  end

  def model
    'Smoke-o-stat'
  end

  def friendly_name
    'Smoke-o-stat'
  end

  def friendly_location
    'Portland, OR'
  end

  def serial_number
    @fan_controller_url
  end

  def pin
    ''
  end

  def devices
    [
      { friendly_name: '^H Smoke-o-stat',
        friendly_location: 'Portland, OR',
        update_frequency: 0,
        index: 0,
        accuracy: 0,
        precision: 0,
        wo_topics: [ 'fan' ],
        ro_topics: [ 'light', 'air', 'access' ],
        rw_topics: []
      }
    ]
  end
end
