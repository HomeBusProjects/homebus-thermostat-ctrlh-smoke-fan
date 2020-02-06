require 'homebus_app_options'

class SmokeOStatHomeBusAppOptions < HomeBusAppOptions
  def app_options(op)
    verbose_help = 'verbose mode'
    test_help = 'test mode - do not actually change the fan settings'

    op.separator 'AQI options:'
    op.on('-v', '--verbose', verbose_help) { options[:verbose] = true }
    op.on('-t', '--test', test_help) { options[:test] = true }
  end

  def banner
    'HomeBus Smoke-o-stat'
  end

  def version
    '0.0.1'
  end

  def name
    'homebus-ctrlh-smoke-fan'
  end
end
