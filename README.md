# autolight
Ruby daemon script for automatic monitor brightness adjustment on imac and macbooks under Linux
Tested under Ubuntu 15.10 with Gnome 3.18

This script will work for you too if you have two files in you system
- /sys/devices/platform/applesmc.768/light (ambient light sensor current value source)
- /sys/class/backlight/acpi_video0/brightness (place to change for backlight brightness adjustment)
 

# install
- Install Ruby if not
- (optional) Change config params in sctipt code

# start
sudo ./autolight.rb

# stop
sudo kill $(cat /tmp/autolight.pid)

I used the following code to create this script  
  
- @penguin2716 gist  
mba_autobl.rb https://gist.github.com/penguin2716/a0f48e4b3c14009c46ed  


- @sbusso simple daemon gist  
simple_ruby_daemon.rb https://gist.github.com/sbusso/1978385

Enjoy!
