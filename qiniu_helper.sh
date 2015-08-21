#!/bin/bash

readonly ACCESS_KEY=gCS_AUyK7LgfEa9aYEn-O2acLXrL8cGpashfOdBQ

readonly SECRET_KEY=knVH7CIYMV7T9TJZWEsYsTHFNoe3Sn15b1QQaFOq









#===================================common functions===================================

get_unixtime(){
	if [ "$#" -eq 0 ]
	then
		echo -n $(date +%s)
		return 0
	fi

	meta1="[[:alnum:]]\{1,4\}"
	meta2="[[:alnum:]]\{1,2\}"
	pattern1="$meta1-$meta2-$meta2"
	pattern2="$pattern1 $meta2"
	pattern3="$pattern2:$meta2"
	pattern4="$pattern3:$meta2"
		
	if echo -n $1 | grep -e "$pattern1" -e "$pattern2" -e "$pattern3" -e "$pattern4" > /dev/null
	then
		echo -n $(date -d $1 +%s)
	else
		echo -n $(date +%s)
	fi
}


safe_base64_encode_url(){
	base64_url=$(echo -n $1 | base64)
	safe_base64_url=$(echo -n $base64_url | sed -e 's\+\-\g' -e 's\/\_\g') 
   	echo -n $safe_base64_url
}

safe_base64_decode_url(){
	base64_url=$(echo -n $1 | sed -e 's\-\+\g' -e 's\_\/\g')
	echo -n $(echo -n $base64_url | base64 -d)
}

url_encode(){
	
exit 1
}


generate_access_token(){
	sign=$(printf $1 | openssl dgst -sha1 -binary -hmac $SECRET_KEY)
	safe_base64_sign=$(safe_base64_encode_url $sign)
	echo -n $ACCESS_KEY:$safe_base64_sign
}

get_json_value(){
	data=$(echo -n $2 | sed -e 's\[{}]\\g')
	if echo -n $data | grep "\"$1\"" > /dev/null
	then
		echo -n ok	
	else
		echo -n no
	fi
}

delete_resource(){
	bucket=$1
	key=$2
	safe_base64_url=$(safe_base64_encode_url "$bucket:$key")
	access_token=$(generate_access_token "/delete/$safe_base64_url\n")
	curl -s -H 'Content-Type: application/x-www-form-urlencoded' -H "Authorization:QBox $access_token" -X POST "http://rs.qiniu.com/delete/$safe_base64_url"
}

move_resource(){
	src_bucket=$1
	src_key=$2
	dest_bucket=$3
	dest_key=$4
	src_safe_base64_url=$(safe_base64_encode_url "$src_bucket:$src_key")
	dest_safe_base64_url=$(safe_base64_encode_url "$dest_bucket:$dest_key")
	access_token=$(generate_access_token "/move/$src_safe_base64_url/$dest_safe_base64_url\n")
	curl -s -H 'Content-Type: application/x-www-form-urlencoded' -H "Authorization:QBox $access_token" -X POST "http://rs.qiniu.com/move/$src_safe_base64_url/$dest_safe_base64_url"

}



get_resource_info(){

	if [ "$#" -eq 1 ]
	then
		bucket="$1"
		safe_base64_url=$(php /home/geek/classic_shell_scripting/qiniu_helper/helper.php $bucket)
		echo $safe_base64_url
		access_token=$(generate_access_token "/list?bucket=$safe_base64_url\n")
		result=$(curl -s -H "Host:rsf.qbox.me" -H "Content-Type:application/x-www-form-urlencoded" -H "Authorization:QBox $access_token" -X POST "http://rsf.qbox.me/list?bucket=$safe_base64_url")
		echo -n $result
		return 1
	fi
	bucket=$1
	key=$2
	safe_base64_url=$(safe_base64_encode_url "$bucket:$key")
	access_token=$(generate_access_token "/stat/$safe_base64_url\n")
	result=$(curl -s -H "Authorization:QBox $access_token" "http://rs.qiniu.com/stat/$safe_base64_url")
	echo -n $result
}


list_resource(){

exit 1
}
#==================main()===========================


get_resource_info "mytest" "config.txt"
echo
get_resource_info "mytest" "1.mp3"
echo
get_resource_info "mytest" 
echo
delete_resource "mytest" "config.txt"

move_resource "mytest" "readme.txt" "mytest" "r.txt"
