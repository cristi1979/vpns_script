#!/usr/bin/ruby

require 'rubygems'
require 'watir-webdriver'
require 'thread'
STDOUT.sync = true

$crtpass=""
$newpass=""
$user="mind3"

$filecrtpass="/usr/local/vpn/juniper_ruby_scripts/is_current.pass"
$fileprevpass="/usr/local/vpn/juniper_ruby_scripts/is_prev.pass"
$file1pass="/usr/local/vpn/juniper_ruby_scripts/is_1.pass"
$file2pass="/usr/local/vpn/juniper_ruby_scripts/is_2.pass"

def readpass(name)
 print "\t[RB] Reading password from file " + name + ".\n"
 begin
  file = File.new(name, "r")
  pass = file.gets.strip
  file.close
 rescue => err
  print "\t[RB] Exception: #{err}\n"
  err
  pass=""
 end
 return pass
end

def newconnection(q)
 if $newpass != "" then
  savepass
 end
 print "\t[RB] Entering credentials: "+$user+"/"+$crtpass+"\n"
 q.text_field(:name,"username").set($user)
 q.text_field(:name,"password").set($crtpass)
 q.button(:value,"Sign In").click
 return 0
end

def otherconnected(q)
 print "\t[RB] Somebody already connected... Continuing.\n"
 q.button(:value,"Continue the session").click
 return 0
end

def alreadyconnected(q)
 print "\t[RB] Connected. Start the tunell.\n"
 q.button(:value,"Start").click
 return 0
end

def passwordexpired(q)
  print "\t[RB] Password expires. Continuing...\n"
  q.link(:text,"Click here to continue.").click
  return 0
end

def getnewpass
  print "\t[RB] Get a new password.\n"
  $newpass = readpass($file1pass)
  if $crtpass == $newpass || $newpass == "" then
    $newpass = readpass($file2pass)
    if $crtpass == $newpass || $newpass == "" then
      chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
      $newpass=(0...8).collect { chars[Kernel.rand(chars.length)] }.join
    end
  end
end

def changepassword(q)
  getnewpass
  print "\t[RB] Changing password with: "+$newpass+"\n"
  q.text_field(:name,"oldPassword").set($crtpass)
  q.text_field(:name,"newPassword").set($newpass)
  q.text_field(:name,"confirmPassword").set($newpass)
  q.button(:value,"Change Password").click
  return 0
end

def savepass
  print "\t[RB] Saving current password and old password.\n"
  $crtpass=$newpass
  begin
    file = File.new($fileprevpass, "w")
    file.write($crtpass)
    file.close
    file = File.new($filecrtpass, "w")
    file.write($newpass)
    file.close
  rescue => err
    print "\t[RB] Exception: #{err}\n"
    err
  end
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
 elsif q.button(:value,"Start").exists? then
  print "\t[RB] Start.\n"
  ret=alreadyconnected(q)
 elsif q.button(:value,"Continue the session").exists? then
  print "\t[RB] Continue.\n"
  ret=otherconnected(q)
 elsif q.title.strip == "Instant Virtual Extranet" then
  print "\t[RB] Exipred.\n"
  ret=passwordexpired(q)
 elsif q.title.strip == "Secure Access SSL VPN - Home" then
  print "\t[RB] Connection done.\n"
  ret=0
 elsif q.title.strip == "Secure Access SSL VPN - Network Connect" then
  print "\t[RB] Starting java applet.\n"
  exit
  ret=0
 elsif q.button(:value,"Change Password").exists? then
  print "\t[RB] Change password.\n"
  ret=changepassword(q)
 else
  print "\t[RB] We are in unknow zone. We don't know what to do.\n"
  exit 100
  ret=0
 end
 return ret
end

$crtpass=readpass($filecrtpass)

print "\t[RB] Initialize driver.\n"
#ff=Firefox.new
Selenium::WebDriver::Firefox.path = "/home/vpnis/firefox/firefox"
default_profile = Selenium::WebDriver::Firefox::Profile.from_name "default" 
default_profile.native_events = true 
driver = Selenium::WebDriver.for(:firefox, :profile => default_profile)
print "\t[RB] Open new firefox window.\n"
#ff = Watir::Browser.new(driver) :firefox
ff = Watir::Browser.new(driver)

print "\t[RB] Open url to customers site.\n"
ff.goto("https://customer.site/mind")

15.times { 
 ret=gogogo(ff);
 sleep 3
 if ret==1 then
   print "\t[RB] We had an error. Exit.\n"
   ff.close
   exit
 end
}
