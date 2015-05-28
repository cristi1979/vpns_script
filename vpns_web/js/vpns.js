"use strict";

function post_data_home( JSONstring, ctrl_funct_success, ctrl_funct_error) {
    var request = $.ajax({
	type: "POST",
	url: "index.php",
	data: { json: JSON.stringify(JSONstring) },
	timeout: 60000, // miliseconds
	success: ctrl_funct_success, // request, status, err
	error: function(request, status, err) {
            if(status == "timeout") {
                alert("timeout: \n"+JSON.stringify(request));
            } else if (status == "error") {
		var err = eval("(" + request.responseText + ")");
                alert(err.Message) ;
		ctrl_funct_error(err.Message, status, err);
	    } else {
		var err = eval("(" + request.responseText + ")");
                alert("Error status is "+status+" and "+err.Message) ;
		ctrl_funct_error(err.Message, status, err);
	    }
        },
	failure: function(errMsg) {alert(errMsg);},
    });
}

function update_vpn_log(response) {
    var text = JSON.parse(response);
    text = text.replace(/\r?\n\r?/g, "\r\n"); 
    $("textarea").text(text);
    $("textarea").scrollTop($("textarea")[0].scrollHeight);
}

function updateVpns(response, textStatus, XMLHttpRequest) {
  var arr = JSON.parse(response);
  var crt_vpn_check = arr[0];
  $.each( arr[1], function(index, item) {
    var vpn_name = item[0];
    var vpn_fail_max = item[1];
    var vpn_fail_crt = item[2];
    var vpn_extra_info = item[3];
    vpn_extra_info=vpn_extra_info.replace(/"/g, '');

    if(typeof vpn_extra_info != 'undefined' && vpn_extra_info != ''){
      $("td#"+vpn_name).attr('vpn_extra_info', vpn_extra_info);
    }
    $("td#"+vpn_name).removeClass("vpn_active");
    $("td#"+vpn_name).removeClass("vpn_disabled");
    $("td#"+vpn_name).removeClass("vpn_failed");

    if ( parseInt(vpn_fail_crt) >= parseInt(vpn_fail_max)) {
      $("td#"+vpn_name).addClass("vpn_disabled");
    } else if (parseInt(vpn_fail_crt) > 0 ) {
      $("td#"+vpn_name).addClass("vpn_failed");
    } else {
      $("td#"+vpn_name).addClass("vpn_active");
    }
  });

  if ( $(".selected").attr('id') != 'current' && $(".selected").attr('id') == crt_vpn_check && $("button.test").attr("btn_type") == "enable"){
    add_send_extra(crt_vpn_check);
  } 
//   if ($(".selected").attr('id') != 'current' && $(".selected").attr('id') == crt_vpn_check && $("td#"+crt_vpn_check).hasClass("vpn_failed")) {
//     add_send_extra();
//   }

  $(".ui-icon-gear").remove();
  $("td#"+crt_vpn_check).children("button").first().button({icons: {secondary: 'ui-icon-gear'}});

  var vpn_name = crt_vpn_check;
  if ($(".selected").attr('id') != 'current') {
      vpn_name = $(".selected").attr('id');
  }
  var JSONstring = { function:"get_vpn_log", args:{vpn:vpn_name} };
  post_data_home(JSONstring, update_vpn_log, update_vpn_log_error);
}

function update_vpn_log_error(response, textStatus, XMLHttpRequest) {
  console.log(response+"\n"+textStatus+"\n"+XMLHttpRequest);
}

function updates() {
    var JSONstring = { function:"get_vpns_statuses" };
    post_data_home(JSONstring, updateVpns);
}

function enable_vpn_success(response, textStatus, XMLHttpRequest) {
  console.log(JSON.parse(response));
}

function add_send_extra(vpn_name) {
    var extra = $(".selected").attr('vpn_extra_info');
    if (typeof extra != 'undefined') {
      $("button.test").text("Send "+extra+":");
      $("button.test").attr('btn_type', "send_extra");
      $(".test").show();
    }
}

function add_enable_vpn() {
    $(".test").hide();
    $("button.test").text("Enable");
    $("button.test").attr('btn_type', "enable");
    $("button.test").show();
}

$(function() {
  $( ".vpn_btn" )
    .button()
    .click(function() {
      var vpn_name = $(this).parent().attr('id');
      $(".selected").removeClass("selected");
      $(this).parent().addClass("selected");
      $(".test").hide();
      if ($("td#"+vpn_name).hasClass("vpn_disabled")) {
	add_enable_vpn();
      }
      if ($("td#"+vpn_name).hasClass("vpn_failed")) {
	add_send_extra();
      }
    });
  $( "button.test" )
    .button()
    .click(function() {
      var vpn_name = $(".selected").attr('id');
      var extra = $(".selected").attr('vpn_extra_info');
      var btn_type = $("button.test").attr('btn_type');
      var text = $("input.test").val();
      console.log(vpn_name+" __ "+extra+" __ "+btn_type+" __ "+text);
      var JSONstring = { function:"enable_vpn", args:{vpn:vpn_name, extra:extra, type:btn_type, input_text:text} };
      post_data_home(JSONstring, enable_vpn_success);
      // reset:
      if ($("button.test").attr('btn_type') == "send_extra") {
	  $("button.test").attr('btn_type', "");
      }
      $("input.test").val('');
      $(".test").hide();
    });
  updates();
  var t1=setInterval('updates()', 300); 
});
