#!/bin/bash
readonly ACCESS_KEY=gCS_AUyK7LgfEa9aYEn-O2acLXrL8cGpashfOdBQ
readonly SECRET_KEY=knVH7CIYMV7T9TJZWEsYsTHFNoe3Sn15b1QQaFOq
version=1.0.0
readonly http_head_content_type='Content-Type:application/x-www-form-urlencoded'
readonly auth_common='Authorization:QBox'
readonly CONFIG_FILE_LOCATION="/tmp/.qiniu_helper.config"
readonly DOMAIN_BUCKET_MAP_FILE_LOCATION="/tmp/.domain_bucket_map_file"
readonly download_expires=30
readonly upload_expires=300

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
#需要安装的软件
readonly MUST_INSTALL_SOFTWARE=(openssl curl php)
#===================================common functions===================================



#测试环境
testing_enviroment(){    
       for value in "${MUST_INSTALL_SOFTWARE[@]}";do
	     	    which $value 1> /dev/null 2>&1;
                    if [ "$?" -eq 1 ];then
                            return 1;
                    fi
       done   
}

detect_enviroment_in_detail(){
      if [ ! -e "$CONFIG_FILE_LOCATION" ];then
               echo "Warning:config file does not exist";
      fi
      if [ ! -e "$DOMAIN_BUCKET_MAP_FILE_LOCATION" ];then
               echo "Warning:domain bucket map file does not exist";
      fi
      for value in "${MUST_INSTALL_SOFTWARE[@]}";do
            which $value 1> /dev/null 2>&1;
                 if [ "$?" -eq 1 ];then
			echo "Error:uninstall $value";
		 fi
     done
}

usage(){
  echo "Qiniu Helper v$version"
  echo "Dongjiaqiang - dongjiaqiang@outlook.com"
  echo "Usage: $0 COMMAND [ PARAMETERS ]..."
  echo "Commands:"
  echo "help"
  echo "config <accessKey> <secretKey> <operationLogFile>"
  echo "clear <clearInfo>"
  echo "move [sourceBucketName] [sourceFileName] [destBucketName] [destFileName]"
  echo "copy [sourceBucketName] [sourceFileName] [destBucketName] [destFileName]"
  
}

#保存或更改基本配置信息
#配置文件基本格式为key=value格式,每个键值对一行
save_config(){
	if [  ! -e "$CONFIG_FILE_LOCATION" ];then
		touch $CONFIG_FILE_LOCATION
		echo "ACCESS_KEY=$1" > $CONFIG_FILE_LOCATION
		echo "SECRET_KEY=$2" >> $CONFIG_FILE_LOCATION
		if [ ! -z "$3" ];then
			echo "OPERATION_LOG_FILE=$3" >> $CONFIG_FILE_LOCATION
		fi
       else
		tmp=$(cat $CONFIG_FILE_LOCATION | sed -e 's\^ACCESS_KEY=.*$\ACCESS_KEY='$1'\'  -e 's\^SECRET_KEY=.*$\SECRET_KEY='$2'\')
		echo "$tmp" > $CONFIG_FILE_LOCATION
		if [ ! -z "$3" ];then
 			if cat $CONFIG_FILE_LOCATION | grep '^OPERATION_LOG_FILE=.*$' > /dev/null;then
		     		tmp=$(cat $CONFIG_FILE_LOCATION | sed 's\^OPERATION_LOG_FILE=.*$\OPERATION_LOG_FILE='$3'\')
                     		echo "$tmp" > $CONFIG_FILE_LOCATION
			else
		     		echo "OPERATION_LOG_FILE=$3" >> $CONFIG_FILE_LOCATION
			fi
		fi
	fi
}

#显示配置信息
show_config(){
	if [  -e "$CONFIG_FILE_LOCATION" ];then
		echo -e "ACCESS_KEY\tSECRET_KEY\tOPERATION_LOG_FILE_LOCATION"
		while IFS=\= read key value
		do
			echo -ne "$value\t\t"
		done<$CONFIG_FILE_LOCATION
	fi
	echo
}

#配置空间域名映射文件,该文件在下载时需要使用
#配置空间域名映射文件基本格式为key=value格式,每个键值对一行
manage_domain_bucket_map(){
	if [ $# -eq 1 ] && grep "^$1=.*$" $DOMAIN_BUCKET_MAP_FILE_LOCATION > /dev/null;then
                tmp=$(sed 's\^'$1'=.*$\\' $DOMAIN_BUCKET_MAP_FILE_LOCATION)
                echo "$tmp" > $DOMAIN_BUCKET_MAP_FILE_LOCATION
	elif [ $# -eq 1 ];then
		return 0
	fi	 
	is_public=${3:-yes}
	if [ ! -e "$DOMAIN_BUCKET_MAP_FILE_LOCATION" ];then
		touch $DOMAIN_BUCKET_MAP_FILE_LOCATION
		echo "$1=$2=$is_public" > $DOMAIN_BUCKET_MAP_FILE_LOCATION
	else
		if grep "^$1=.*$" $DOMAIN_BUCKET_MAP_FILE_LOCATION > /dev/null;then
			tmp=$(sed 's\^'$1'=.*$\'$1'='$2'='$is_public'\' $DOMAIN_BUCKET_MAP_FILE_LOCATION)
			echo "$tmp" > $DOMAIN_BUCKET_MAP_FILE_LOCATION
		else 
			echo "$1=$2=$is_public" >> $DOMAIN_BUCKET_MAP_FILE_LOCATION
		fi
	fi	
}

#查询某个空间的信息
find_bucket_info(){
	if [ -e "$DOMAIN_BUCKET_MAP_FILE_LOCATION" ];then
		while IFS=\= read bucket domain is_public
		do
			if [ "$bucket" = "$1" ];then
				echo -n "$domain,$is_public"
				return 0
			fi
		done< $DOMAIN_BUCKET_MAP_FILE_LOCATION
	fi
	return 1	

}

#显示所有已经保存的空间域名映射关系
show_remain_bucket_domain_map(){

	if [ -e "$DOMAIN_BUCKET_MAP_FILE_LOCATION" ];then
		echo -e "空间名字\t域名\t\t\t\t\t是否公开"
		while IFS=\= read bucket domain is_public
		do
			if [ ! -z "$1" ] && [ "$bucket" = "$1" ];then
				echo -e "$bucket\t\t$domain\t\t$is_public"
				break;
			elif [ -z "$1" ];then
				echo -e "$bucket\t\t$domain\t\t$is_public"
			fi
		done < $DOMAIN_BUCKET_MAP_FILE_LOCATION
	else
		echo "未发现空间域名映射关系文件"
	fi
}

#删除所有配置信息
clear_all_save(){
	if [ "$1" = "我确定删除所有保存的信息" ];then
		rm $DOMAIN_BUCKET_MAP_FILE_LOCATION $CONFIG_FILE_LOCATION
		echo "已经删除所有配置信息"
	else
		echo "未操作成功"
	fi
}

get_unixtime(){
	if [ "$#" -eq 0 ];then
		echo -n $(date +%s)
		return 0
	fi
	meta1="[[:alnum:]]\{1,4\}";meta2="[[:alnum:]]\{1,2\}";pattern1="$meta1-$meta2-$meta2";pattern2="$pattern1 $meta2";pattern3="$pattern2:$meta2"
	pattern4="$pattern3:$meta2"
	if echo -n $1 | grep -e "$pattern1" -e "$pattern2" -e "$pattern3" -e "$pattern4" > /dev/null;then
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
	data=$(echo -n $1 | sed -e 's\[{}]\\g' -e "s/:\ *\"/:\"/g" -e "s/\"\ *:/\":/g")
	op=1
	kv=$(echo -n $data | cut -d, -f$op)
	while [ ! -z "$kv" ];do
		k=$(echo -n $kv | cut -d: -f1 | sed -e "s/^\ *\"//g" -e "s/\"\ *$//g")
		v=$(echo -n $kv | cut -d: -f2 | sed -e "s/^\ *\"//g" -e "s/\"\ *$//g")
		op=$((op+1))
		kv=$(echo -n $data | cut -d, -f$op)
		if [ -n "$kvs" ];then
			kvs="$k=$v,$kvs"
		else
			kvs="$k=$v"
		fi
		if echo -n $data | grep -v "," >/dev/null;then
			break;
		fi
	done
	echo -n $kvs
}

delete_resource(){
	safe_base64_url=$(safe_base64_encode_url "$1:$2")
	access_token=$(generate_access_token "/delete/$safe_base64_url\n")
	curl -s -H $http_head_content_type -H "$auth_common $access_token" -X POST "${API_DELETE_RESOURCE__URL}${safe_base64_url}"
	return $?
}

move_resource(){
	src_safe_base64_url=$(safe_base64_encode_url "$1:$2")
	dest_safe_base64_url=$(safe_base64_encode_url "$3:$4")
	access_token=$(generate_access_token "/move/$src_safe_base64_url/$dest_safe_base64_url\n")
	curl -s -H $http_head_content_type -H "$auth_common $access_token" -X POST "${API_MOVE_RESOURCE_URL}${src_safe_base64_url}/${dest_safe_base64_url}"
	return $?
}

copy_resource(){
	src_safe_base64_url=$(safe_base64_encode_url "$1:$2")
        dest_safe_base64_url=$(safe_base64_encode_url "$3:$4")
	access_token=$(generate_access_token "/copy/$src_safe_base64_url/$dest_safe_base64_url\n")
	curl -s -H $http_head_content_type -H "$auth_common $access_token" -X POST "${API_COPY_RESOURCE_URL}${src_safe_base64_url}/${dest_safe_base64_url}"
	return $?
}

#下载资源
download_resource(){
	download_location=${3:-/tmp}
	bucket_info=$(find_bucket_info $1)
	if [ "$?" -eq 1  ];then
		return 1
	fi
	domain=$(echo $bucket_info | cut -d,  -f1)
	is_public=$(echo $bucket_info | cut -d, -f2)
	downloadurl="http://$domain/$2"
	if [ "$is_public" = "no" ];then
	        deadline_time=$(($(get_unixtime)+$time_limit_seconds))
		downloadurl="$downloadurl?e=$deadline_time"
		access_token=$(generate_access_token $downloadurl)
		downloadurl="$downloadurl&token=$access_token"
	fi
	curl -# -s -o "$download_location/$2" $downloadurl
	return $? 
}

upload_resource(){
exit 1	
}

get_resource_info(){
	if [ "$#" -eq 1 ];then
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

#move_resource "mytest" "r.txt" "mytest" "s.txt"
#copy_resource "mytest" "s.txt" "mytest" "b.txt"

#save_config 1 23 dsdff 

#manage_domain_bucket_map '1mytest' '7xl8na.com1.z0.glb.clouddn.cm' 
#show_remain_bucket_domain_map
#save_config gCS_AUyK7LgfEa9aYEn-O2acLXrL8cGpashfOdBQ knVH7CIYMV7T9TJZWEsYsTHFNoe3Sn15b1QQaFOq
#manage_domain_bucket_map mytest 7xl8na.com1.z0.glb.clouddn.com
#manage_domain_bucket_map test2 7xl9xf.com1.z0.glb.clouddn.com no
#show_remain_bucket_domain_map

#download_resource mytest s.txt ~/download
#download_resource test2 readme.txt ~/download
#get_resource_info mytest s.txt
#show_remain_bucket_domain_map
#show_remain_bucket_domain_map mytest
#show_remain_bucket_domain_map test2
testing_enviroment
usage
res=$(get_json_value '{"error":"errro","df ff":"dsd"')
echo $res
testing_enviroment
echo $?
detect_enviroment_in_detail

