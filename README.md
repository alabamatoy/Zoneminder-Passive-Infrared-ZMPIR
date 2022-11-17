# Zoneminder-Guardline-Numato
This software (numato.pl) is written for Ubuntu 18.04 but should work on other similar OSes.  This software leverages the Zoneminder zmtrigger.pl socket functionality to create a capability to read the state of a Guardline Passive InfraRed (PIR) motion sensor via a Numato IO device connected to the computer via USB.  Within this description, the software will be referred to as ZMPIR.  

More info about Zoneminder is here: https://zoneminder.com/ 

More info about the Guardline devices is here: https://www.guardlinesecurity.com/ 

More info about the Numato IO board is here: https://numato.com/product/8-channel-usb-gpio-module-with-analog-inputs/

OVERALL EXPLANATION of the app:  ZMPIR is meant to run on a highly configurable timing scheme.  I use CRON to fire it off on the hour and half hour.  ZMPIR looks for a semaphore (a simple temp file) to use as a motion detection defeat feature, so the motion detection can be controlled easily through a simple web page (also provided herein, see numato.php and numatostat.php).  If ZMPIR does not see the defeat semaphore, it will check the Numato IO device repeatedly using timing which is highly controllable through variable constants.  When ZMPIR sees a motion detection, it connects to the Zoneminder zmtrigger.pl socket and turns on recording on a preconfigured set of Zoneminder monitors.  It then waits a preconfigured amount of time, either until its recording time expires or the preset runtime expires.  If the recording time expires before the end of the ZMPIR run it will restart repeatedly checking the Numato device for another motion detection event.  If its overall time has expired, it will exit, and this should happen a few seconds before another ZMPIR run is initiated by CRON. 

HARDWARE: Here are some pictures of the simple hardware configuration:

This is the Numato board showing the wires that connect to the Guardline receiver and the 1Kohm resistor.  Note that this tiny little board can actually manage up to 8 Guardline receivers, and each Guardline receiver can monitor up to 4 PIR sensors, so this can become a very robust system with addition of more Guardline devices.  The Numato board has a simple USB connection to the server running ZM and ZMPIR.
![PXL_20221025_155530481](https://user-images.githubusercontent.com/28680526/202463775-7c8dfbf6-5fdf-4d55-970c-67155d5512ea.jpg)

Here is the Guardline receiver with the back cover attached:
![PXL_20221025_160119577](https://user-images.githubusercontent.com/28680526/202463873-4be0a9cf-6cdc-4cdf-ba40-d74c5d9c71c1.jpg)

Here is the Guardline receiver with the back cover removed.  The Guardline documentation describes all the connections and DIP switches:
![PXL_20221117_134728974](https://user-images.githubusercontent.com/28680526/202463941-3cda8d1f-1d06-42a2-9705-e03cb7e637c2.jpg)


The overall end result is that the Guardline PIR motion detection sensors are used to control Zoneminder video recording, turning on recording when motion is detected, ignoring further motion detection events until recording is completed, then again repeatedly checking for motion detection.

FLAWS: This is a somewhat complicated timing-based process.  Depending on the speed of server running ZMPIR, a motion detection may occur at such a time that when ZMPIR cycles through its processes and check the Numato device, the motion detection signal has already expired.  So sometimes motion detection events are missed, but this is rare on fast servers.  Also, a motion detection event that occurs once recording has already been commanded will be ignored.  All of the timing can be adjusted, so one can have very long recording times with subsequent motion events being ignored, or very short recording times which with subsequent motion events detected and further recording initiated.

INSTALLATION: ZMPIR is a simple perl script.  It may be placed anywhere on the server.  Following is a listing of the various confguration options in the script, with explanations of each:

#### This is the USB device where the Numato is connected.
Numato has instructions on how to determine this value, but the easiest way is to open a command prompt and enter "lsusb" and note the results.  Then connect the Numato USB connection, and rerun the command - the Numato device should be the only delta between the to runs of the command.  Note that sometimes rights become an issue - if you cannot successfully read the device you may need to address the access rights to the device.  You can confirm that the Numato device is functioning correctly by opening a command prompt and entering "screen /dev/ttyACM0"  You should get a different prompt back, then enter "ver" for version, and you should get back a integer version number of the device.  Then you can enter "gpio read 0" and you should get back the status of shunt number 0 on the GPIO board. To get out of the screen tool, enter "ctrl a" (control and letter a simultaneously) followed by a backslash "\". 
my $portName = "/dev/ttyACM0";

#### Name of the file that acts as a semaphore for operation of the motion detection.
Existence of this file will cause ZMPIR to immediately exit, and can be used by some other means to control disabling the motion detection sensing.  The PHP files included herein work together to make this capability happen.  If you dont want this, just ignore it as ZMPIR just checks for existence of the file and if it doesnt exist, it continues unaffected.
my $MDSemaphore = "/etc/numato_zmtrigger/numatoMDdisable";

All of these timing values are in seconds unless otherwise noted.

#### seconds to wait after sending query to device
This is how long the routine waits for the Numato device to respond.
my $sleepvalue = 1;

#### seconds to wait between checks of alarm status
This is how long the routine waits between check of the Numato device
my $sleepvalue2 = 2;

#### number of seconds to wait before checking for motion again AFTER motion was detected
This needs to be a wee bit longer than the cameras are set to record ($alarmtime)
my $sleepvalue3 = 605;

#### number of seconds to wait between calls to zmtrigger socket, 1 seems to work well, too fast and zmtrigger ignores the call
my $sleepvalue4 = 1;

#### number of seconds to allow the script to run, should be slightly longer than sleepvalue2*looplength
If this script is run on a cron schedule, the actual runtime may be 1-3 seconds longer than this value, so set it slightly less than how often cron is going to fire off the script. Getting minutes desired to run from input to script, first arg value is number of minutes
my $timelimitminutes = $ARGV[0];

#### calculate timelimit in seconds, deduct 10 for end of script and cleanup
my $timelimit = $timelimitminutes*60 - 10;

#### number of times the alarm status will be checked, looplength * sleepvalue2 approx accumulated time this script runs
my $looplength = 900;

#### number of seconds the alarm (recording) should last. 
Sleepvalue3 and alarmtime should be about the same.
my $alarmtime = 600;

#### where to write the log data
my $logfilename = "/var/log/numatotrigger.log";

#### location of the zmtrigger socket, this requires OPT_TRIGGERS to be on in ZM config.  
See zmtrigger documentation in Zoneminder documentation or the wiki
my $SOCK_PATH = "/var/run/zm/zmtrigger.sock";

#### Which camera ID(s) to turn on to alarm (recording).  
Note that sleepvalue4 is the delay between calls to zmtrigger socket, so consider total time for turning on recording, ie 3 cameras will take 3X sleepvalue4 to turn on recording.
my @monitorId = ("9","21","17","22","5");  

#### How many cameras to alarm, max is limited by how long each socket call requires
my $numcameras = @monitorId;

#### Value to use to set alarm on, "on" turn on alarm, and "on+X" turns alarm on for X seconds
my $recordState = "on+".$alarmtime;

#### Set to any value to turn on verbose logging for troubleshooting.  This produces a lot of log data!
my $verboselog = "";

#### entity to receive emails, can be multiple addresses separated by comma  
Note that this can be used to send SMS messatges (ie "texts") to a phone by using the phone service providers interface.  For example, Verizon's is phone_num@vtext.com
my $to = 'someone@somewhere.com';

#### from address to use
my $from = 'someone@somewhereelse.com';
