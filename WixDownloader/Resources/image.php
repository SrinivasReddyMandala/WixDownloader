<?php
    require_once('DynamicImageResizer.php');
    $parameters = 'file=[imagefile]&ext=[imagetype]&size=800x600';
    $resizer = new DynamicImageResizer('./media/', $parameters);
    $resizer->output();
 ?>