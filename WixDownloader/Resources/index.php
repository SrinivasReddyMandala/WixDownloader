
<?php
if(isset($_GET['_escaped_fragment_']))
{
        $htm = file_get_contents("./seo/". $_GET['_escaped_fragment_']. ".html");
        #$htm = str_replace('<meta name="robots" content="noindex"/>', '', $htm);
        echo ($htm);
}
else
{
    include ("./index.html");
}
?>