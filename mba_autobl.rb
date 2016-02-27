#!/usr/bin/ruby
#
# Copyright (c) 2014 Takuma Nakajima
#
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php
#

# ambient light sensor
ALS_SOURCE = '/sys/devices/platform/applesmc.768/light'
# backlight
BL_SOURCE = '/sys/class/backlight/acpi_video0/brightness'

ALS_MAX = 35
ALS_MIN = 0
BL_MAX = 255
BL_MIN = (255 * 0.25).round

SINGLE_UPDATE_THRESH = 25
UPDATE_INTERVAL = 0.25 # second

if ENV["USER"] != "root"
	puts "root permission required."
	exit 1
end

Process.daemon

def panel_open?
	true
  #fd = open('/proc/acpi/button/lid/LID0/state', 'r')
  #is_open = fd.read.split.last == 'open'
  #fd.close
  #is_open
end

def current_als
  fd = open(ALS_SOURCE, 'r')
  value = fd.read.chomp.gsub(/[()]/, '').split(',').first.to_i
  fd.close
  value.to_i
end

def smooth_als
  $als_history ||= Queue.new
  $als_history.enq current_als
  $als_history.deq if $als_history.size > 10
  sum = 0.0
	$als_history.instance_variable_get('@que').each do |val|
    sum += val
  end
  sum / $als_history.size.to_f
end

def current_bl
  fd = open(BL_SOURCE, 'r')
  bl = fd.read
  fd.close
  bl.to_i
end

def set_bl(bl)
  fd = open(BL_SOURCE, 'w')
  fd.write(bl.to_s)
  fd.close
end

def als2bl(als)
  return BL_MIN if als < ALS_MIN
  return BL_MAX if als > ALS_MAX
  (BL_MIN + (BL_MAX - BL_MIN) * (als - ALS_MIN).to_f / (ALS_MAX - ALS_MIN).to_f).round
end

def update_bl
  if panel_open?

    bl_cur = current_bl
    bl_new = als2bl(smooth_als)

    if (bl_new - bl_cur).abs > SINGLE_UPDATE_THRESH
      if bl_cur < bl_new
        bl_new = [bl_cur + SINGLE_UPDATE_THRESH, BL_MAX].min
      else
        bl_new = [bl_cur - SINGLE_UPDATE_THRESH, BL_MIN].max
      end
    end

    unless bl_new == bl_cur
      set_bl(bl_new)
    end

  end
end

loop do
  update_bl
  sleep UPDATE_INTERVAL
end
