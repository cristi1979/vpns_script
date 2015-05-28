#!/usr/bin/ruby
#$DEBUG = true
require 'rubygems'
require 'watir-webdriver'
require 'thread'
STDOUT.sync = true

$firefox_path = "/home/wiki/firefox/firefox"
$site=ARGV[0]
$user=ARGV[1]
$pass_crt=ARGV[2]
$pass_next=ARGV[3]
$realm=ARGV[4]

$new_pass = 0
$page_realm = ''
$page_url = ''

RET_OK=10
RET_NEW=20
RET_UNKN=30
RET_ERR=40
RET_EXC=50
RET_END=60

def newconnection(q)
 $page_realm = q.input(:name => 'realm').value
 print "\t[RB] Found this realm before login: "+$page_realm+"\n"
 print "\t[RB] Entering credentials: "+$user+"/"+$pass_crt+"\n"
 q.text_field(:name,"username").set($user)
 q.text_field(:name,"password").set($pass_crt)
 if q.text_field(:name,"realm").exists? && defined? $realm then
   q.text_field(:name,"realm").set($realm)
 end
 q.button(:value,"Sign In").click
 return 0
end

def changepassword(q)
  print "\t[RB] Changing password with: "+$pass_next+"\n"
  q.text_field(:name,"oldPassword").set($pass_crt)
  q.text_field(:name,"newPassword").set($pass_next)
  q.text_field(:name,"confirmPassword").set($pass_next)
  q.button(:value,"Change Password").click
  $pass_crt=$pass_next
  return 0
end

def closeconnection(q,ret)
  $stderr.puts "XXX_QQQ_WWW REALM="+$page_realm+"!URL="+$page_url
  q.close
  if $new_pass == 1 then
    ret = RET_NEW
  end
  exit ret
end

def gogogo(q)
 ret=0
 if q.button(:value,"Sign In").exists? then
  if q.table(:text,"Invalid username or password. Please re-enter your user information.").exists? then
    print "\t[RB] Invalid username or password. We CAN'T get wrong.\n"
    ret=1
  else
    print "\t[RB] Sign in.\n"
    ret=newconnection(q)
  end
 elsif q.button(:value,"Start").exists? || q.title.strip == "Secure Access SSL VPN - Network Connect" || q.title.strip == "Junos Pulse Secure Access Service - Network Connect" then
  print "\t[RB] We reached start vpn. All good\n"
  closeconnection(q,RET_OK)
 elsif q.button(:value,"Continue the session").exists? then
  print "\t[RB] Continue.\n"
  q.button(:value,"Continue the session").click
  ret=0
 elsif q.title.strip == "Instant Virtual Extranet" && q.text.include?("Your password will expire in") then
  print "\t[RB] Password will expire.\n"
  q.link(:text,"Click here to continue.").click
  ret=0
 elsif (q.title.strip == "Maximum User Sessions Warning" || q.title.strip == "Vendor/Guest Secure Remote Access - Confirmation Open Sessions" ) && q.text.include?("You have reached the maximum number of open user sessions allowed") then
  print "\t[RB] Too many users.\n"
  q.checkbox(:name => 'postfixSID').set
  sleep 1
  q.button(:name,"btnContinue").click
  ret=0
 elsif q.title.strip == "Secure Access SSL VPN - Home" then
  print "\t[RB] Connection done.\n"
  ret=0
 elsif q.button(:value,"Change Password").exists? then
  print "\t[RB] Change password.\n"
  ret=changepassword(q)
  if ret == 0 then
    $new_pass = 1;
  end
 else
  print "\t[RB] We are in unknow zone. We don't know what to do.\n\t"<<q.title<<"\n"
  ret=RET_UNKN
 end
 return ret
end

begin
 print "\t[RB] Initialize driver.\n"
 Selenium::WebDriver::Firefox.path = $firefox_path
 default_profile = Selenium::WebDriver::Firefox::Profile.from_name "default" 
 default_profile.native_events = true 
 default_profile.assume_untrusted_certificate_issuer = false
 driver = Selenium::WebDriver.for(:firefox, :profile => default_profile)
 driver.manage.timeouts.implicit_wait = 3
 print "\t[RB] Open new firefox window.\n"
 ff = Watir::Browser.new(driver)

 print "\t[RB] Open url to customer site "+$site+".\n"
 ff.goto($site)
 $page_url = driver.execute_script("return document.URL")
 15.times { 
  sleep 1
  ret=gogogo(ff); 
  if ret>0 then
    print "\t[RB] We had an error. Exit.\n"
    ff.close
    exit RET_ERR
  end
 }

rescue => err
  print "\t[RB] Exception: #{err}\n"
  err
  ff.close
  exit RET_EXC
end
exit RET_END
