#!/usr/bin/env ruby
# == Simple Daemon
#
# A simple ruby daemon that you copy and change as needed.
# 
# === How does it work?
#
# All this program does is fork the current process (creates a copy of
# itself) then exits, the fork (child process) then goes on to run your
# daemon code. In this example we are just running a while loop with a
# 1 second sleep.
#
# Most of the code is dedicated to managing a pid file. We want a pid
# file so we can use a monitoring tool to make sure our daemon keeps
# running.
#
# === Why?
#
# Writing a daemon sounds hard but as you can see is not that
# complicated, so lets strip away the magic and just write some ruby.
#
# === Usage
#
# You can run this daemon by running:
#
#     $ ./simple_ruby_daemon.rb
#
# or with an optional pid file location as its first argument:
#
#     $ ./simple_ruby_daemon.rb tmp/simple_ruby_daemon.pid
#
# check that it is running by running the following:
#
#     $ ps aux | grep simple_ruby_daemon
#
# Author:: Rufus Post  (mailto:rufuspost@gmail.com)
class SimpleDaemon
  # Checks to see if the current process is the child process and if not
  # will update the pid file with the child pid.
  def self.start pid, pidfile, outfile, errfile
    unless pid.nil?
      raise "Fork failed" if pid == -1
      write pid, pidfile if kill pid, pidfile
      exit
    else
      redirect outfile, errfile
    end
  end

  # Attempts to write the pid of the forked process to the pid file.
  def self.write pid, pidfile
    File.open pidfile, "w" do |f|
      f.write pid
    end
  rescue ::Exception => e
    $stderr.puts "While writing the PID to file, unexpected #{e.class}: #{e}"
    Process.kill "HUP", pid
  end

  # Try and read the existing pid from the pid file and signal the
  # process. Returns true for a non blocking status.
  def self.kill(pid, pidfile)
    opid = open(pidfile).read.strip.to_i
    Process.kill "HUP", opid
    true
  rescue Errno::ENOENT
    $stdout.puts "#{pidfile} did not exist: Errno::ENOENT"
    true
  rescue Errno::ESRCH
    $stdout.puts "The process #{opid} did not exist: Errno::ESRCH"
    true
  rescue Errno::EPERM
    $stderr.puts "Lack of privileges to manage the process #{opid}: Errno::EPERM"
    false
  rescue ::Exception => e
    $stderr.puts "While signaling the PID, unexpected #{e.class}: #{e}"
    false
  end

  # Send stdout and stderr to log files for the child process
  def self.redirect outfile, errfile
    $stdin.reopen '/dev/null'
    out = File.new outfile, "a"
    err = File.new errfile, "a"
    $stdout.reopen out
    $stderr.reopen err
    $stdout.sync = $stderr.sync = true
  end


	def update
	end
end

# Process name of your daemon
#$0 = "simplerubydaemon"

# Spawn a daemon
SimpleDaemon.start fork, (ARGV[0] || '/tmp/daemon.pid'), (ARGV[1] || '/tmp/daemon.stdout.log'), (ARGV[2] || '/tmp/daemon.stderr.log')

# Set up signals for our daemon, for now they just exit the process.
Signal.trap("HUP") { $stdout.puts "SIGHUP and exit"; exit }
Signal.trap("INT") { $stdout.puts "SIGINT and exit"; exit }
Signal.trap("QUIT") { $stdout.puts "SIGQUIT and exit"; exit }

#############################################################################################
#
# ambient light sensor
ALS_SOURCE = '/sys/devices/platform/applesmc.768/light'
# backlight
BL_SOURCE = '/sys/class/backlight/acpi_video0/brightness'

ALS_MAX = 66
ALS_MIN = 0
BL_MAX = 89
BL_MIN = (BL_MAX * 0.15).round

SINGLE_UPDATE_THRESH = 5
UPDATE_INTERVAL = 0.25 # second
#Personal correction in percents, +10 — increases backlight by 10% to normal calculation,  -10 decreases by 10%,  0 means  no correction
PERSONAL_CORRECTION = +30 

def panel_open?
  #fd = open('/proc/acpi/button/lid/LID0/state', 'r')
  #is_open = fd.read.split.last == 'open'
  #fd.close
  #is_open
	true
end

def current_als
  fd = open(ALS_SOURCE, 'r')
  value = fd.read.chomp.gsub(/[()]/, '').split(',').first.to_i
  fd.close
  value.to_i
end

def smooth_als
  $als_history ||= [] 
  $als_history.push current_als
	$als_history.shift if $als_history.size > 10
  sum = 0.0
	$als_history.each do |val|
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
rescue ::Exception => e
	e
end

def als2bl(als)
  return BL_MIN if als < ALS_MIN
  return BL_MAX if als > ALS_MAX
  (BL_MIN + (BL_MAX - BL_MIN) * (als - ALS_MIN).to_f / (ALS_MAX - ALS_MIN).to_f).round
end

def bl_corrected(bl)
	bl = bl + (bl.to_f*(PERSONAL_CORRECTION.to_f/100.to_f)).round
end

def update_bl
  if panel_open?

    bl_cur = current_bl
    bl_new = bl_corrected als2bl(smooth_als)

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
		$stdout.puts "Brightness increased to #{bl_new} from #{bl_cur}" if bl_new > bl_cur
		$stdout.puts "Brightness decreased to #{bl_new} from #{bl_cur}" if bl_new < bl_cur

  end
end

loop do
	update_bl
  sleep UPDATE_INTERVAL
end
