<?php 

#phpinfo();

#$result = shell_exec('ls -altp /private/var/tmp');
#$result2 = shell_exec('touch /private/var/tmp/science');
#$result = shell_exec('whoami');

#echo "<pre>$result</pre>";
#echo "<pre>$result2</pre>";
$type =  $_GET["type"];

echo $type;

 $target = "uploads/"; 
 $target = $target . basename( $_FILES['file']['name']) ; 
 $ok=1; 
 
 //This is our size condition 
 if ($uploaded_size > 350000) 
 { 
 echo "Your file is too large.<br>"; 
 $ok=0; 
 } 
 
 //This is our limit file type condition 
 if ($uploaded_type =="text/php") 
 { 
 echo "No PHP files<br>"; 
 $ok=0; 
 } 
 
 //Here we check that $ok was not set to 0 by an error 
 if ($ok==0) 
 { 
 Echo "Sorry your file was not uploaded"; 
 } 
 
 //If everything is ok we try to upload it 
 else 
 { 
#echo "the file upload: ". $_FILES['file']['tmp_name'];
#echo "";
 if(move_uploaded_file($_FILES['file']['tmp_name'], $target)) 
 { 
 echo "The file ". basename( $_FILES['file']['name']). " has been uploaded"; 

$result = shell_exec("./xcpullreqd $target $type 2>&1");
echo "<pre>$result</pre>";
 } 
 else 
 { 
 echo "Sorry, there was a problem uploading your file."; 
 } 
 } 
 ?>