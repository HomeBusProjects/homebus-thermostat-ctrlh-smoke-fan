#!/usr/bin/env ruby

require './options'
require './app'

smokeostat_app_options = SmokeOStatHomeBusAppOptions.new

smokeostat = SmokeOStatHomeBusApp.new smokeostat_app_options.options
smokeostat.run!
#smokeostat.setup!
#smokeostat.work!

