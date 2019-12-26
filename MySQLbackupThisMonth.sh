mysql_user="root" #MySQL备份用户
mysql_password="123456" #MySQL备份用户的密码
mysql_host="192.168.16.194" #数据库服务器
mysql_port="3306"
mysql_charset="utf8" #MySQL编码
backup_db_arr=("zhgd_his") #要备份的数据库名称，多个用空格分开隔开 如("db1" "db2" "db3")
backup_location=/home/backup/zhgd/ycsshis  #备份数据存放位置，末尾不带"/"

backup_select=\'t_iot_actual_date_his_`date +%Y%m`%\' #检索需要备份的文件用 (备份当前月)
backup_year=`date +%Y` #年份
backup_time=`date +%Y%m%d%H%M`  #定义备份详细时间
backup_Ymd=`date +%Y-%m-%d` #定义备份目录中的年月日时间
backup_dir=$backup_location/$backup_year/$backup_Ymd  #备份文件夹全路径
backup_log_path=$backup_location/log/$backup_year # 备份文件目录
backup_log=$backup_log_path/$dbname-$backup_time.log #备份文件
welcome_msg="MySQL backup start!"

#创建log目录
mkdir -p $backup_log_path


# 判断MYSQL是否启动,mysql没有启动则备份退出
mysql_ps=`ps -ef |grep mysql |wc -l`
mysql_listen=`netstat -an |grep LISTEN |grep $mysql_port|wc -l`
if [ [$mysql_ps == 0] -o [$mysql_listen == 0] ]; then
        echo "ERROR:MySQL is not running! backup stop!" >> $backup_log 
        exit
else
        echo $welcome_msg >> $backup_log
fi

# 连接到mysql数据库，无法连接则备份退出
mysql  -u$mysql_user -p$mysql_password -h$mysql_host -P$mysql_port <<end
use mysql;
select host,user from user where user='root' and host='localhost';
exit
end

flag=`echo $?`
if [ $flag != "0" ]; then
        echo "ERROR:Can't connect mysql server! backup stop!" >> $backup_log
#        exit
else
        echo "MySQL connect ok! Start backup......" >> $backup_log
        # 判断有没有定义备份的数据库，如果定义则开始备份，否则退出备份
        if [ "$backup_db_arr" != "" ];then
                # 连接到mysql数据库，无法连接则备份退出
                #dbnames=$(cut -d ',' -f1-5 $backup_database)
                #echo "arr is (${backup_db_arr[@]})"
                for dbname in ${backup_db_arr[@]}
                do
                        echo "database $dbname backup start..." >> $backup_log
                        `mkdir -p $backup_dir`
                        #检索数据库,取得需要备份的月份,完成备份
                        tables=`mysql -u$mysql_user -p$mysql_password -h$mysql_host -D $dbname -N -e "show tables like $backup_select;"`
			table_count=0
                        for table in $tables
                        do
                                `mysqldump --single-transaction --skip-opt -h$mysql_host -P$mysql_port -u$mysql_user -p$mysql_password $dbname --default-character-set=$mysql_charset  $table  | gzip > $backup_dir/$dbname-$table-$backup_time.sql.gz`
                                flag=`echo $?`
                                if [ $flag == "0" ];then
					table_count=`expr $table_count + 1`
                                        echo "database $dbname success backup to $backup_dir/$dbname-$table-$backup_time.sql.gz" >> $backup_log
				 else
                                 echo "database $dbname backup fail!" >> $backup_log
                                fi
                        done
			echo "count : $table_count" >> $backup_log
                done
        else
                echo "ERROR:No database to backup! backup stop" >> $backup_log
#                exit
        fi
        echo "All database backup success!" >> $backup_log
#        exit
fi

