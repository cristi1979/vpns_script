<?php
//   print_r($_GET);
  // inotifywait -m -r --format '%w%f' -e close_write /var/www/html/coco/scripts/uploads/
  // error_reporting(E_STRICT);
  //  phpinfo();
$customers_dir = '/var/log/mind/vpn/customers/';
$customers_defaults = $customers_dir.'/null';
$failed_file = $customers_dir.'/failed_retries';
$logs_dir = "/var/log/mind/vpn/logs/";
$now_testing = $logs_dir."/output_vpn_now_testing";
$log_prefix = "output_vpn_";
$exclude_list = array(".", "..", "failed_retries", "null");
// $extra_info_dir = "/media/share/Documentation/cfalcas/q/vpns_script/vpns_web/extra/";
$extra_info_dir = "/var/log/mind/vpn/extra/";

function get_vpns_statuses() {
  global $customers_dir, $exclude_list, $customers_defaults, $failed_file, $logs_dir, $now_testing;

  $default_fail = 0;
  foreach(explode("\n",file_get_contents($customers_defaults)) as $line) {
    if (preg_match('/^\s*RETRIES\s*=\s*/', $line)) {
      $default_fail = preg_replace('/^\s*RETRIES\s*=\s*/', '', $line);
    }
  }

  $arr = array();
  $last_file="";
  $files = array_diff(scandir($customers_dir), $exclude_list);
  foreach($files as $vpn) {
    if(is_file($customers_dir.$vpn) && ! preg_match('/^sed[a-zA-Z0-9]+$/', $vpn) ) {
      $vpn_fail = $default_fail;
      $extra_shit = "";
      foreach(explode("\n",file_get_contents($customers_dir.$vpn)) as $line) {
	if (preg_match('/^\s*RETRIES\s*=\s*/', $line)) {
	  $vpn_fail = preg_replace('/^\s*RETRIES\s*=\s*/', '', $line);
	}
	if (preg_match('/^\s*EXTRA_WEB_INFO\s*=\s*/', $line)) {
	  $extra_shit = preg_replace('/^\s*EXTRA_WEB_INFO\s*=\s*/', '', $line);
	}
      }

      $vpn_fail_crt = 0;
      foreach(explode("\n",file_get_contents($failed_file)) as $line) {
	if (preg_match("/^\s*$vpn\s*=/", $line)) {
	  $vpn_fail_crt = preg_replace("/^\s*$vpn\s*=\s*/", '', $line);
	}
      }
      $arr[] = array($vpn, $vpn_fail, $vpn_fail_crt, $extra_shit);
    }
  }
  print json_encode( array(chop(file_get_contents($now_testing)), $arr) ); 
}

function get_vpns() {
  global $customers_dir, $exclude_list;
  $html = "";
  $files = array_diff(scandir($customers_dir), $exclude_list);
  foreach($files as $vpn) {
    if(is_file($customers_dir.$vpn)) {
      $html .= "
	      <tr>
		<td id=\"$vpn\">
		  <button class=\"vpn_btn\">$vpn</button> 
		</td>
	      </tr>";
    }
  }
  return $html;
}

function enable_vpn($args){
  global $failed_file, $extra_info_dir;
  $vpn = "";
  $txt = "";
  if (! isset($args->vpn) || preg_match('/^\s*$/', $args->vpn)){
    print json_encode("no vpn name received");
    return;
  }
  $vpn = $args->vpn;

  if (! isset($args->type)){
    print json_encode("no type for button");
    return;
  }
  ## enable vpn
  if ($args->type == "enable"){
      $new_text_failed = "";
      foreach (file($failed_file) as $line) {
	  if (preg_match("/^\s*$vpn\s*=/", $line)) {
	      $new_text_failed .= "$vpn=0\n";
	  } else {
	      $new_text_failed .= "$line";
	  }
      }
      file_put_contents($failed_file, $new_text_failed);
      $txt = "vpn $vpn was enabled.";
  } else if ($args->type == "send_extra"){
      if (isset($args->extra)){
	$text = $args->input_text;
	if ($args->extra == "pass" && ! preg_match('/^\s*$/', $args->input_text)) {
	    ## set pass for vpn
	    $txt = "set pass ".$args->input_text." for vpn $vpn";
	    file_put_contents("$extra_info_dir/pass_$vpn", $args->input_text);
	}
      }
  }
  print json_encode($txt);
}

function get_vpn_log($args) {
  global $logs_dir, $log_prefix;
  if (! isset($args->vpn)){
    print json_encode( "" );
    return;
  }
  $vpn_name = $args->vpn;
  $file = "$logs_dir/$log_prefix$vpn_name";
  if (! file_exists($file)){
    error_log($file);
    print json_encode( "" );
    return;
  }
  $fp = fopen($file, 'r');
  fseek($fp, -1, SEEK_END); 
  $pos = ftell($fp);
  $LastLine = "";
  $log = "";
  $not_done = 1;
  $count=1;
  while(($pos > 0) && $not_done) {
    $C = fgetc($fp);
    if ($C!="\n"){
      $LastLine = $C.$LastLine;
    } else {
	$log = $LastLine."\n".$log;
	$LastLine = "";
    }
    fseek($fp, $pos--);
    $count++;
    if ($count>50000 || $LastLine == "========================= START ========================="){
      $not_done = 0;
      $log = $LastLine."\n".$log;
    }
  }
  print json_encode( $log );
}

function default_page() {
    echo '<!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8" />
        <title>VPNs</title>
	<link rel="stylesheet" href="css/jquery-ui-1.10.0.css" /> 
	<link rel="stylesheet" href="css/vpns.css">

	<!--  ####################### Java scripts ####################### -->
	<script src="js/jquery-1.9.0.js"></script>
	<script src="js/jquery-ui-1.10.0.js"></script>
        <script src="js/vpns.js"></script>

    </head>
    <body>';
    echo '
<table class="ui-widget ui-widget-content">
  <tbody>
    <tr>
      <td>
	  <table class="ui-widget ui-widget-content">
	      <tr>
		<td id="current" class="selected">
		  <button class="vpn_btn">Currently testing</button> 
		</td>
	      </tr>
	      '.get_vpns().'
	    </tbody>
	  </table> 
      </td>

      <td>
	<div class="log_area">
	  <textarea readonly></textarea> 
	  <div class="extra_stuff">
	    <button class="test" style="display:none"></button> 
	    <input class="test ui-corner-all" type="text" style="display:none"></input>
	  </div>
	</div>
      </td>
    </tr>
  </tbody>
</table> 
';
    echo '</body>
</html>';
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $post_data = json_decode($_POST['json']);
    $function = $post_data->function;
    $args = '';
    if (isset($post_data->args)) {
      $args = $post_data->args;
    }
    if (function_exists($function) ) {
	call_user_func($function, $args);
    } else {
	error_log("function name '$function' doesn't exist.");
    }
} else {
    default_page();
}
?>
