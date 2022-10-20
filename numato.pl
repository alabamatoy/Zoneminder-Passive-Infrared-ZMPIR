#ZMPIR - Zoneminder Passive InfraRed, for more info see 
# https://github.com/alabamatoy/Zoneminder-Guardline-Numato

use Device::SerialPort;
#use strict;
use bytes;
use IO::Socket::UNIX;

use ZoneMinder;
use ZoneMinder::Trigger::Channel::Unix;

# various variable values
#This is the USB device where the Numato is connected 
my $portName = "/dev/ttyACM0";

#Name of the file that acts as a semaphore for operation of the motion detection
my $MDSemaphore = "/etc/numato_zmtrigger/numatoMDdisable";

#seconds to wait after sending query to device
my $sleepvalue = 1;

#seconds to wait between checks of alarm status
my $sleepvalue2 = 2;

#number of seconds to wait before checking for motion again AFTER motion was detected
#This needs to be a wee bit longer than the cameras are set to record ($alarmtime)
my $sleepvalue3 = 605;

#number of seconds to wait between calls to zmtrigger socket, 1 seems to work well, too fast and zmtrigger ignores the call
my $sleepvalue4 = 1;

# number of seconds to allow the script to run, should be slightly longer than sleepvalue2*looplength
# if this script is run on a cron schdule, the actual runtime may be 1-3 seconds longer than this value,
# so set it slightly less than how often cron is going to fire off the script.
# getting minutes desired to run from input to script, first arg value is number of minutes
my $timelimitminutes = $ARGV[0];
#calculate timelimit in seconds, deduct 10 for end of script and cleanup
my $timelimit = $timelimitminutes*60 - 10;

#number of times the alarm status will be checked, looplength * sleepvalue2 approx accumulated time this script runs
my $looplength = 900;

# NOTE - degenerate situation can occur where a wait state happens near end of script run, causing script to overrun
# its allotted time.  Perhaps each sleep call should check remaining time on script run?  

#number of seconds the alarm (recording) should last. Sleepvalue3 and alarmtime should be about the same.
my $alarmtime = 600;

# where to write the log data
my $logfilename = "/var/log/numatotrigger.log";

#location of the zmtrigger socket, this requires OPT_TRIGGERS to be on in ZM config.  See zmtrigger
#documentation in Zoneminder documentation or the wiki
my $SOCK_PATH = "/var/run/zm/zmtrigger.sock";

# Which camera ID(s) to turn on to alarm (recording).  Note that sleepvalue4 is the delay between calls to zmtrigger
# socket, so consider total time for turning on recording, ie 3 cameras will take 3X sleepvalue4 to turn on recording.
my @monitorId = ("9","21","17","22","5");  

#How many cameras to alarm, max is limited by how long each socket call requires
my $numcameras = @monitorId;

#Value to use to set alarm on, "on" turn on alarm, and "on+X" turns alarm on for X seconds
my $recordState = "on+".$alarmtime;

#Set to any value to turn on verbose logging for troubleshooting.  This produces a lot fo log data!
my $verboselog = "";

# entity to receive emails, can be multiple addresses separated by comma
my $to = '2565095919@vtext.com';

#from address to use
my $from = 'signalsecurity@epbfi.com';

#end of constants

#Check semaphore for MD enable/disable, exit if found, OW ignore
if ( -e $MDSemaphore ) {
   #do nothing
   if ($verboselog){ logger("Detected semaphore, turning off...")};
   exit 0;
}

#set starting time of script
my $starttime = time();
my $endtime = $starttime + $timelimit;

my $serPort = new Device::SerialPort($portName, quiet) || die "Could not open the port specified, stopped";

sub email{

if ($verboselog){ logger("mail to be sent")};

my $subject = $_[0];
my $message = $_[1];

if ($verboselog){ logger($to)};
if ($verboselog){ logger($from)};
if ($verboselog){ logger($subject)};
if ($verboselog){ logger($message)};

open(MAIL, "|/usr/sbin/sendmail -t");

# Email Header
print MAIL "To: $to\n";
print MAIL "From: $from\n";
print MAIL "Subject: $subject\n\n";
# Email Body
print MAIL $message;

$result = close(MAIL);

if($result) { 
   logger("eMail sent to $to");
   } else { 
   logger("eMail failed to be sent");
   if ($verboselog){ logger("Error: ". $result). "\n"};
   }

}

sub initialize {

my $mode = (stat($portName))[2];
if ($mode != 8630) {
   logger("File $portName has unworkable permissions or does not exist, should be 0666");
   return "";
   }

#Send "ver" command to the device
   $serPort->write("ver\r"); 
   sleep(1);

#Read response from device
   (my $count,my $data) = $serPort->read(25); 

#Parse and print
   my $substring = substr $data,0,$count - 2;
   if ($verboselog){ logger("String/$substring/")};
   if ($verboselog){ logger("Length is: $count")};
   my $cutsubstring = substr $substring,6,8;
   if ($verboselog){ logger("ncutsubString/$cutsubstring/")};
   
   if ($cutsubstring == "00000008") {
      return "Success";
   }else{
      return "";
   }
}

sub logger {
my $logentry = $_[0];
my $timestring = localtime();
open(my $log, '>>', $logfilename) or die "Could not open file '$logfilename' $!, stopped"; #This opens the log file for entry append
print $log "\n$timestring  $logentry";
close($log) or die "Could not close file '$logfilename' $!, stopped";
}

sub zmtrigger{
my $sock = IO::Socket::UNIX->new(
    Type => SOCK_STREAM(),
    Peer => $SOCK_PATH,
) or die "\nCannot create socket - $IO::Socket::errstr";

    unless ($sock) {

        logger('Error connecting to socket');
        return "";
    }
    else {

        logger("Success connecting to ZM_TRIGGER socket");
        #should check status of monitor and see if it already in alarm, and if so, skip, future!
        for( my $b = 1; $b <= $numcameras; $b++){
           if ($verboselog){ logger("Loop#: $b, number of cameras: $numcameras, monitorID: @monitorId[($b-1)]")};
           my $string_to_write =
               @monitorId[($b-1)] . "|"
               . $recordState
               . "|200|PIR External Motion Detection|External Motion";
           $sock->send($string_to_write);
           sleep($sleepvalue4);
           if ($verboselog){ logger("Sent /$string_to_write/ to socket")};
           }
        logger("Sent alarm signal to $numcameras cameras");   
        #Probably should check for confirmation
        return "Success";
    }

}

#End of subroutines

#----------Begin main routine-------------

logger("---------Starting Numato and zmtrigger processing, run is " . $timelimit . " seconds----------");
my $timestring = localtime();

# Configure the port	   
$serPort->baudrate(9600);
$serPort->parity("none");
$serPort->databits(8);
$serPort->stopbits(1);
$serPort->handshake("none"); #Most important
$serPort->buffers(4096, 4096); 
$serPort->lookclear();
$serPort->purge_all;

if (initialize()){
# initialize is true so it worked, proceed to reading data
   logger("Successfully initialized serial device");

#start loop

   logger("Starting to check for alarms");
   my $skipcount = 0;
   my $a = 0;

   while ( $a <= $looplength ) {
      $a = $a +1;
      
#Send "gpio read" command to the device
      $serPort->write("gpio read 0\r");
      sleep($sleepvalue);

#Read response from device
      (my $count, my $data) = $serPort->read(25);

#Parse and print
      my $substring = substr $data,0,$count - 2; 
      if ($verboselog){ logger("Pass# $a")};
      if ($verboselog){ logger("Length received = $count")};
      if ($verboselog){ logger("Value received /$substring/")}; 
     
      my $cutsubstring = substr $substring,$count-4,1;
      if ($verboselog){ logger("Value final /$cutsubstring/")}; 
      if ($count != 17) {
         $skipcount = $skipcount + 1;
         if ($verbose){ logger("Degenerate response from device, skipping, skipcount= $skipcount")};
         }
      elsif ($cutsubstring != "1"){
         $timestring = localtime();
         logger("Got an alarm, calling zmtrigger");
         #call ZMtrigger to turn on recording
         if (zmtrigger()){
            #call to zmtrigger was successful
            logger("call to zmtrigger successful, alerting creator");

            #fire message to SO that alert has happened
            email("Numato motion alarm","Numato/Guardline system detected motion at " . $timestring . " Check the Zoneminder system for details.");
            
            #set timer to wait until near end of recording to check for motion again??
            my $newsleep = $endtime - $timestring - 5;
            if ( $sleepvalue3 > $newsleep ) {
               # Sleepvalue3 would put us past the end of the time limit
               logger("Sleepvalue3 would put us over end of timelimit, reducing sleep");
               logger("Sleeping $newsleep while recording...");
               if ($newsleep >= 5) { sleep($newsleep) };
                  # ignore the 5 seconds, the timer will catch it.
            }else{
               logger("Sleeping $sleepvalue3 before restarting alarm checks");
               sleep($sleepvalue3);
               logger("Restarting after sleep");
            }
            
         }else{
            #ZMtrigger failed to turn on recording
            logger("zmtrigger failed to initiate alarm status");
            #send alert?
            #try again?
            }
      }else{
         #no alarm...
      sleep($sleepvalue2);
      my $checktime = time();   
      $runtime = $checktime - $starttime;
      if ($runtime >= $timelimit) {
         logger("Time limit exceeded, $a checks, $skipcount skipped, total runtime (sec): $runtime, exiting...");  
         exit 0;
         }
      if ( -e $MDSemaphore ) {
         #check for newly placed semaphore
         logger("Found new semaphore, $a checks, $skipcount skipped, total runtime (sec): $runtime, exiting...");  
         exit 0;
      }

   }
   my $finishtime = time();
   my $runtime = $finishtime - $starttime;
   if ($verbose){ logger("$a checks, $skipcount skipped, total runtime (sec): $runtime, exiting inner loop...")};     
   }
   logger("Finished run, $a checks, $skipcount skipped, total runtime (sec): $runtime, exiting...");
   exit 0;
}else{
   logger("Failed to initialize, exiting...");
      #something went wrong, let creator know
      email("Numato motion alarm","Error occurred at " . $timestring . " See logfile.");
   exit 1;
   }
