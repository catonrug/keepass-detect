#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/winrar-detect.git && cd winrar-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

if [ -f ~/uploader_credentials.txt ]; then
sed "s/folder = test/folder = `echo $appname`/" ../uploader.cfg > ../gd/$appname.cfg
else
echo google upload will not be used cause ~/uploader_credentials.txt do not exist
fi

#set url
name=$(echo "KeePass")
download=$(echo "http://keepass.info/download.html")

wget -S --spider -o $tmp/output.log "$download"

grep -A99 "^Resolving" $tmp/output.log | grep "HTTP.*200 OK"
if [ $? -eq 0 ]; then
#if file request retrieve http code 200 this means OK

#get all exe english installers
filelist=$(wget -qO- "$download" | sed "s/\d034/\n/g" | grep "http.*download$" | sed '$alast line')

#count how many links are in download page. substarct one fake last line from array
links=$(echo "$filelist" | head -n -1 | wc -l)
if [ $links -gt 1 ]; then
echo $links download links found
echo

printf %s "$filelist" | while IFS= read -r url
do {

#calculate filename
filename=$(echo $url | sed "s/\//\n/g" | grep "KeePass-")

#check if this checksum is in database
grep "$filename" $db > /dev/null
if [ $? -ne 0 ]; then
echo

#download file
echo Downloading $filename
wget $url -O $tmp/$filename -q

#check downloded file size if it is fair enought
size=$(du -b $tmp/$filename | sed "s/\s.*$//g")
if [ $size -gt 512000 ]; then
echo

echo extracting installer..
unrar-nonfree x $tmp/$filename -y $tmp > /dev/null
echo

#detect version
version=$(echo "$filename")

#check if version matchs version pattern
echo $version | grep "^[0-9]\+[\., ]\+[0-9]\+"
if [ $? -eq 0 ]; then
echo

#detect change log
grep -A99 "   Version $version" $tmp/WhatsNew.txt | grep -B99 -m2 "   Version" | grep -v "   Version" | grep "\w" > $tmp/change.log

#check if even something has been created
if [ -f $tmp/change.log ]; then

#calculate how many lines log file contains
lines=$(cat $tmp/change.log | wc -l)
if [ $lines -gt 0 ]; then

echo change log found:
echo
cat $tmp/change.log
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

echo "$filename">> $db
echo "$version">> $db
echo "$md5">> $db
echo "$sha1">> $db
echo >> $db

#if google drive config exists then upload and delete file:
if [ -f "../gd/$appname.cfg" ]
then
echo Uploading $filename to Google Drive..
echo Make sure you have created \"$appname\" direcotry inside it!
../uploader.py "../gd/$appname.cfg" "$tmp/$filename"
echo
fi

#addititonal words in email subject. sequence is important
case "$filename" in
*x64*exe)
bit=$(echo "(64-bit)")
;;
*exe)
bit=$(echo "(32-bit)")
;;
esac

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name $version $bit" "$url 
$md5
$sha1

`cat $tmp/change.log`"
} done
echo

else
#changes.log file has created but changes is mission
echo changes.log file has created but changes is mission
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
echo $onemail
#python ../send-email.py "$onemail" "$name" "changes.log file has created but changes is mission: $version $changes"
} done
fi

else
#changes.log has not been created
echo changes.log has not been created
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name" "changes.log has not been created: 
$version 
$changes "
} done
fi

else
#version do not match version pattern
echo version do not match version pattern
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name" "Version do not match version pattern: 
$url "
} done
fi



else
#downloaded file size is to small
echo downloaded file size is to small
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name" "Downloaded file size is to small: 
$url 
$size"
} done
fi

else
#$filename is already in database
echo $filename is already in database
fi

rm -rf $tmp/*

} done

else
#only $links download links found
echo only $links download links found
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name" "only $links download links found: 
$download "
} done
fi

else
#if http statis code is not 200 ok
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name" "the following link do not retrieve good http status code: 
$url"
} done
echo 
echo
fi

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
