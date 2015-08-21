#!/bin/bash

readonly ACddCESS_KEY=gCS_AUyK7LgfEa9aYEn-O2acLXrL8cGpashfOdBQ
readonly SECRET_KEY=knVH7CIYMV7T9TJZWEsYsTHFNoe3Sn15b1QQaFOq

version=1.0.0


readonly http_head_content_type='Content-Type:application/x-www-form-urlencoded'
readonly auth_common='Authorization:QBox'
readonly CONFIG_FILE_LOCATION="./qiniu_helper.config"

#====================================url==========================================

#删除资源url
readonly API_DELETE_RESOURCE__URL="http://rs.qiniu.com/delete/"

#移动资源url
readonly API_MOVE_RESOURCE_URL="http://rs.qiniu.com/move/"

#复制资源url
readonly API_COPY_RESOURCE_URL="http://rs.qiniu.com/copy/"

#获取资源信息url
readonly API_STAT_RESOURCE_URL="http://rs.qiniu.com/stat/"

#抓取资源信息url
readonly API_FETCH_RESOURCE_URL="http://iovip.qbox.me/fetch/"



#===================================common functions===================================

#保存或更改基本配置信息
save_config(){
	if [  ! -e "$CONFIG_FILE_LOCATION" ]
	then
		touch $CONFIG_FILE_LOCATION
		echo "ACCESS_KEY=$1" > $CONFIG_FILE_LOCATION
		echo "SECRET_KEY=$2" >> $CONFIG_FILE_LOCATION
		if [ ! -z "$3" ]
		then
			echo "OPERATION_LOG_FILE=$3" >> $CONFIG_FILE_LOCATION
		fi
       else
		tmp=$(cat $CONFIG_FILE_LOCATION | sed -e 's\^ACCESS_KEY=.*$\ACCESS_KEY='$1'\'  -e 's\^SECRET_KEY=.*$\SECRET_KEY='$2'\')
		echo "$tmp" > $CONFIG_FILE_LOCATION
		if [ ! -z "$3" ]
		then
 			if cat $CONFIG_FILE_LOCATION | grep '^OPERATION_LOG_FILE=.*$' > /dev/null
			then
		     		tmp=$(cat $CONFIG_FILE_LOCATION | sed -e 's\^OPERATION_LOG_FILE=.*$\OPERATION_LOG_FILE='$3'\')
                     		echo "$tmp" > $CONFIG_FILE_LOCATION
			else
		     		echo "OPERATION_LOG_FILE=$3" >> $CONFIG_FILE_LOCATION
			fi
		fi
	fi
}



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
	safe_base64_url=$(safe_base64_encode_url "$1:$2")
	access_token=$(generate_access_token "/delete/$safe_base64_url\n")
	curl -s -H $http_head_content_type -H "$auth_common $access_token" -X POST "${API_DELETE_RESOURCE__URL}${safe_base64_url}"
}

move_resource(){
	src_safe_base64_url=$(safe_base64_encode_url "$1:$2")
	dest_safe_base64_url=$(safe_base64_encode_url "$3:$4")
	access_token=$(generate_access_token "/move/$src_safe_base64_url/$dest_safe_base64_url\n")
	curl -s -H $http_head_content_type -H "$auth_common $access_token" -X POST "${API_MOVE_RESOURCE_URL}${src_safe_base64_url}/${dest_safe_base64_url}"
}

copy_resource(){
	src_safe_base64_url=$(safe_base64_encode_url "$1:$2")
        dest_safe_base64_url=$(safe_base64_encode_url "$3:$4")
	access_token=$(generate_access_token "/copy/$src_safe_base64_url/$dest_safe_base64_url\n")
	curl -s -H $http_head_content_type -H "$auth_common $access_token" -X POST "${API_COPY_RESOURCE_URL}${src_safe_base64_url}/${dest_safe_base64_url}"
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

move_resource "mytest" "r.txt" "mytest" "s.txt"
#copy_resource "mytest" "r.txt" "mytest" "b.txt"

save_config 1 23 dsdff 
