#!/bin/bash


mysql -uroot -p -e "create table project1.sales(custid integer(10) primary key not null,username varchar(30),quote_count varchar(30),ip varchar(30),entry_time varchar(30),prp_1 varchar(30),prp_2 varchar(30),prp_3 varchar(30),ms varchar(30),http_type varchar(30),purchase_category varchar(30),total_count varchar(30),purchase_sub_category varchar(30),http_info text,status_code integer(10),curr_time bigint);"

echo "sql table got created"

mysql --local-infile=1 -uroot -pWelcome@123 -e "set global local_infile=1;
load data local infile '/home/saif/cohort10/datasets/Day_1.csv' into table project1.sales fields terminated by ',';
update project1.sales set curr_time = CURRENT_TIMESTAMP() + 1 where curr_time IS NULL;
"
mysql -uroot -p -e "select * from sales limit 5;"


sqoop import --connect jdbc:mysql://localhost:3306/project1?useSSL=False --username root --password Welcome@123 --query 'select custid,username,quote_count,ip,entry_time,prp_1,prp_2,prp_3,ms,http_type,purchase_category,total_count,purchase_sub_category,http_info,status_code,curr_time from sales where $CONDITIONS' --split-by custid --target-dir /user/saif/HFS/Output/sales_1;

hive -e "
create table project1.hvsales(
custid int,
username string,
quote_count string,
ip string,
entry_time string,
prp_1 string,
prp_2 string,
prp_3 string,
ms string,
http_type string,
purchase_category string,
total_count string,
purchase_sub_category string,
http_info string,
status_code int,
curr_time BIGINT
)
row format delimited fields terminated by ',';"


hive -e "load data inpath '/user/saif/HFS/Output/sales_1' into table project1.hvsales";


hive -e "create external table project1.hv_ext_sales(
custid int,
username string,
quote_count string,
ip string,
prp_1 string,
prp_2 string,
prp_3 string,
ms string,
http_type string,
purchase_category string,
total_count string,
purchase_sub_category string,
http_info string,
status_code int,
curr_time BIGINT
)
partitioned by(year string,month string)
row format delimited fields terminated by ',';"


hive -e "set hive.exec.dynamic.partition=true;
set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table project1.hv_ext_sales partition (year, month) select custid,username,quote_count,ip,prp_1,prp_2,prp_3,ms,http_type,
purchase_category,total_count,purchase_sub_category,http_info,status_code,curr_time,
cast(year(from_unixtime(unix_timestamp(entry_time , 'dd/MMM/yyyy'))) as string) as year, 
cast(month(from_unixtime(unix_timestamp(entry_time , 'dd/MMM/yyyy'))) as string) as month from project1.hvsales;
create table project1.inter_tab(
custid int,
username string,
quote_count string,
ip string,
entry_time string,
prp_1 string,
prp_2 string,
prp_3 string,
ms string,
http_type string,
purchase_category string,
total_count string,
purchase_sub_category string,
http_info string,
status_code int,
year string,
month string,
curr_time BIGINT
)
row format delimited fields terminated by ',';"


hive -e "insert into table project1.inter_tab select *
from project1.hv_ext_sales t1 join
     (select max(curr_time) as max_date_time
      from project1.hv_ext_sales
     ) tt1
     on tt1.max_date_time = t1.curr_time; "


hive -e "select * from project1.inter_tab limit 5;"

mysql -uroot -p -e "create table project1.sql_exp (custid integer(10),username varchar(30),quote_count varchar(30),ip varchar(30),entry_time varchar(30),prp_1 varchar(30),prp_2 varchar(30),prp_3 varchar(30),ms varchar(30),http_type varchar(30),purchase_category text,total_count varchar(30),purchase_sub_category text,http_info text,status_code integer(10),year varchar(100),month varchar(100),curr_time bigint);"


sqoop export --connect jdbc:mysql://localhost:3306/project1?useSSL=False --table sql_exp --username root --password Welcome@123 --export-dir "/user/hive/warehouse/project1.db/inter_tab" --input-fields-terminated-by ','

























