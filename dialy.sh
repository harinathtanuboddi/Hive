#!/bin/bash

mysql -uroot -p -e "
truncate table project1.sales;
truncate table project1.sql_exp;"

hive -e "truncate table project1.hvsales;"
hive -e "truncate table project1.inter_tab;"


hdfs dfs -rm -r /user/saif/HFS/Output/sales_1

mysql --local-infile=1 -uroot -p -e "set global local_infile=1;
load data local infile '/home/saif/cohort10/datasets/Day_$1.csv' into table project1.sales fields terminated by ',';
update project1.sales set curr_time = CURRENT_TIMESTAMP() + 1 where curr_time IS NULL;"

sqoop import --connect jdbc:mysql://localhost:3306/project1?useSSL=False --username root --password Welcome@123 --query 'select custid,username,quote_count,ip,entry_time,prp_1,prp_2,prp_3,ms,http_type,purchase_category,total_count,purchase_sub_category,http_info,status_code,curr_time from sales where $CONDITIONS' --split-by custid --target-dir /user/saif/HFS/Output/sales_1;


hive -e "load data inpath '/user/saif/HFS/Output/sales_1' into table project1.hvsales";

hive -e "set hive.exec.dynamic.partition=true;
set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table project1.hv_ext_sales partition (year, month) select a.custid,a.username,a.quote_count,a.ip,a.prp_1,a.prp_2,a.prp_3,a.ms,a.http_type,a.purchase_category,a.total_count,a.purchase_sub_category,a.http_info,a.status_code,a.curr_time,cast(year(from_unixtime(unix_timestamp(entry_time , 'dd/MMM/yyyy'))) as string) as year, cast(month(from_unixtime(unix_timestamp(entry_time , 'dd/MMM/yyyy'))) as string) as month from project1.hvsales a join project1.hv_ext_sales b on a.custid=b.custid
union
select a.custid,a.username,a.quote_count,a.ip,a.prp_1,a.prp_2,a.prp_3,a.ms,a.http_type,a.purchase_category,a.total_count,a.purchase_sub_category,a.http_info,a.status_code,a.curr_time,cast(year(from_unixtime(unix_timestamp(entry_time , 'dd/MMM/yyyy'))) as string) as year, cast(month(from_unixtime(unix_timestamp(entry_time , 'dd/MMM/yyyy'))) as string) as month from project1.hvsales a
left join project1.hv_ext_sales b on a.custid=b.custid
where b.custid is null
union
select b.custid,b.username,b.quote_count,b.ip,b.prp_1,b.prp_2,b.prp_3,b.ms,b.http_type,b.purchase_category,b.total_count,b.purchase_sub_category,b.http_info,b.status_code,b.curr_time,cast(year(from_unixtime(unix_timestamp(entry_time , 'dd/MMM/yyyy'))) as string) as year, cast(month(from_unixtime(unix_timestamp(entry_time , 'dd/MMM/yyyy'))) as string) as month
from project1.hvsales a right join project1.hv_ext_sales  b on a.custid=b.custid
where a.custid is null
;"

hive -e "insert into table project1.inter_tab select *
from project1.hv_ext_sales t1 join
     (select max(curr_time) as max_date_time
      from project1.hv_ext_sales
     ) tt1
     on tt1.max_date_time = t1.curr_time; "

sqoop export --connect jdbc:mysql://localhost:3306/project1?useSSL=False --table sql_exp --username root --password Welcome@123 --export-dir "/user/hive/warehouse/project1.db/inter_tab" --input-fields-terminated-by ','





