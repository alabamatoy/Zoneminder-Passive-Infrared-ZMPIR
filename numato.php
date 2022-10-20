<?php
session_start();
?>

<!DOCTYPE html>
<html>
  <head>
  <Title>Numato / Guardline / ZMTrigger Motion Detection Interface Toggle</title>
    <meta http-equiv="refresh" content="3;url=/numatostat.php">
  </head> 
<body>

<?php

#  setup command to determine if the semaphore is set.
  $semaphorefilename = "/etc/numato_zmtrigger/numatoMDdisable";
  $touchcommandstring = "touch ".$semaphorefilename;
  $rmcommandstring = "rm ".$semaphorefilename;
  $motionstate = $_GET["motion"];

echo "command is: ".$motionstate."<BR>";

  if(file_exists($semaphorefilename) && ('enable' == $motionstate)) {
    echo "<BR><BR>Motion detection is currently suppressed or in an actual alarm.";
    echo "<BR><BR>Attempting motion detection re-enable.";
    $result = shell_exec($rmcommandstring);
    if($result==NULL) {
    	echo "<B>...Re-set of semaphore was successful.</B>"; 
    }else {
    	echo "<B>...Re-enable failed, motion detection still disabled.</B>";
    	echo "<BR><BR>Result of command is: '".$result."'";
    	# Execute ls
    	$commandstring = "ls -al " . $semaphorefilename;
    	$result = shell_exec($commandstring);
    	echo "<BR><BR>File results are: ".$result;
    }
  
  echo "================<br>";
        $date=date_create();
        $minutes=date_format($date,"i");

   # calculate minutes remaining to top of hour when cron will restart
        if($minutes>30) {
            $runtime=60-$minutes-1; # deduct 1 minute from runtime to avoid overlap of this script and one fired off by cron
            echo "Runtime: " . $runtime . "<br>";
        }else{
           # calculate minutes remaining to bottom of hour when cron will restart
            $runtime=30-$minutes-1; # deduct 1 minute from runtime to avoid overlap of this script and one fired off by cron
            echo "Runtime: " . $runtime . "<br>";
        }
        echo "================<br>";
        # NOTE - the perlcommandstring must point to wherever the numato.pl is located!
        $perlcommandstring="perl /home/scripts/numato.pl " . $runtime ."  2>/dev/null >/dev/null &";
        shell_exec($perlcommandstring);
        if($result==NULL) {
    	    echo "<B>...Spawn of Numato script was successful.</B>"; 
        }else{
    	    echo "<B>...Re-enable failed, motion detection still disabled.</B>";
    	    echo "<BR><BR>Result of command is: '".$result."'";        
        }  
  }
  elseif (!file_exists($semaphorefilename) && ('disable' == $motionstate)) {
    	echo "<BR><BR>Motion detection is currently enabled.";
    	echo "<BR><BR>Attempting to suppress motion detection.";
    	$result = shell_exec($touchcommandstring);
    		if($result==NULL) {
    			echo "<B>...Suppression of motion detection was successful.</B>"; 
			}
    		else {
    			echo "<B>...Suppression failed, motion detection still enabled.</B>";
    			echo "<BR><BR>Result of command is: '".$result."'";}
     }
else echo "Nothing done...";
echo "<HR>";
?>

</body>
</html>
