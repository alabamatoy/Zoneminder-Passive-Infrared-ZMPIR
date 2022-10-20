<?php
session_start();
?>

<!DOCTYPE html>
<html>
  <head>
  <Title>Numato / Guardline / ZMTrigger Motion Detection Interface Status</title>
<style>

input[type="submit"] {
    -ms-transform: scale(1.5); /* IE 9 */
    -webkit-transform: scale(1.5); /* Chrome, Safari, Opera */
    transform: scale(1.5);
	border: 20px;
	background-color: black;
	color: white;
}

input[type="radio"] {
    -ms-transform: scale(2.0); /* IE 9 */
    -webkit-transform: scale(2.0); /* Chrome, Safari, Opera */
    transform: scale(2.0);

}


html, body {
	margin: 2%;
    font-size: 150%;
}

</style>
</head> 

<body>
Numato / Guardline / Zoneminder Motion Detection Interface Status

 <hr style="height:10px;border-width:0;color:gray;background-color:gray"> 

<div id="wrapper">

<B>Current Motion Detection Status:</B><BR>
<form action="/numato.php" method="get">
<?php

#  setup command to determine if the semaphore is set.
#  $statuscommandstring = "cat /tmp/numatolog.dat";

$semaphorefilename = "/etc/numato_zmtrigger/numatoMDdisable";

 
  if(file_exists($semaphorefilename)) {
    echo "Motion detection is currently <B>suppressed</B> or in an actual alarm.<BR>";
    echo '<input type="radio" name="motion" value="disable"  checked> SUPPRESS Motion Detection<br>';
    echo '<input type="radio" name="motion" value="enable" > ENABLE Motion Detection<br>';

  }
  else {
    echo "Motion detection is currently <B>enabled</b>.<BR>";
    echo '<input type="radio" name="motion" value="disable" > SUPPRESS Motion Detection<br>';
    echo '<input type="radio" name="motion" value="enable"  checked> ENABLE Motion Detection<br>';
  
  }
echo '<input type="submit" value="Submit"></form>';

?>

</div>

</body>
</html>
