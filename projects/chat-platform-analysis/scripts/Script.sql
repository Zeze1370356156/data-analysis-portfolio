--创建数据库
create database db_msg ;
--切换数据库
use db_msg ;

--如果表已存在就删除
drop table if exists db_msg.tb_msg_source ;
--建表
create table db_msg.tb_msg_source(
msg_time string comment "消息发送时间",
sender_name string comment "发送人昵称",
sender_account string comment "发送人账号",
sender_sex string comment "发送人性别",
sender_ip string comment "发送人ip地址",
sender_os string comment "发送人操作系统",
sender_phonetype string comment "发送人手机型号",
sender_network string comment "发送人网络类型",
sender_gps string comment "发送人的GPS定位",
receiver_name string comment "接收人昵称",
receiver_ip string comment "接收人IP",
receiver_account string comment "接收人账号",
receiver_os string comment "接收人操作系统",
receiver_phonetype string comment "接收人手机型号",
receiver_network string comment "接收人网络类型",
receiver_gps string comment "接收人的GPS定位",
receiver_sex string comment "接收人性别",
msg_type string comment "消息类型",
distance string comment "双方距离",
message string comment "消息内容"
);

-- 加载数据到表中
load data local inpath '/home/hadoop/chat_data-30W.csv' into table tb_msg_source;

-- 验证数据加载
SELECT *
FROM tb_msg_source
tablesample(100 rows);

-- 验证表的数量
SELECT COUNT(*)
FROM tb_msg_source;

-- 查看空数据
select msg_time,sender_name,sender_gps
from db_msg.tb_msg_source
where length(sender_gps) = 0
limit 10;

-- 过滤空数据，构建天和小时，提取经度维度
INSERT OVERWRITE TABLE db_msg.tb_msg_etl
SELECT 
       *,
	   DATE(msg_time) AS msg_day,
	   HOUR(msg_time) AS msg_hour,
	   SPLIT(sender_gps,',')[0] AS sender_lng,
	   SPLIT(sender_gps,',')[1] AS sender_lat
FROM db_msg.tb_msg_source
WHERE LENGTH(sender_gps) > 0;

-- 构建表
create table db_msg.tb_msg_etl(
msg_time string comment "消息发送时间",
sender_name string comment "发送人昵称",
sender_account string comment "发送人账号",
sender_sex string comment "发送人性别",
sender_ip string comment "发送人ip地址",
sender_os string comment "发送人操作系统",
sender_phonetype string comment "发送人手机型号",
sender_network string comment "发送人网络类型",
sender_gps string comment "发送人的GPS定位",
receiver_name string comment "接收人昵称",
receiver_ip string comment "接收人IP",
receiver_account string comment "接收人账号",
receiver_os string comment "接收人操作系统",
receiver_phonetype string comment "接收人手机型号",
receiver_network string comment "接收人网络类型",
receiver_gps string comment "接收人的GPS定位",
receiver_sex string comment "接收人性别",
msg_type string comment "消息类型",
distance string comment "双方距离",
message string comment "消息内容",
msg_day string comment "消息日",
msg_hour string comment "消息小时",
sender_lng double comment "经度",
sender_lat double comment "纬度"
);

-- 问题1：统计今日消息总量
CREATE TABLE db_msg.tb_rs_total_msg_cnt COMMENT '每日消息总量' AS
SELECT 
    msg_day, 
    COUNT(*) AS total_msg_cnt 
FROM db_msg.tb_msg_etl 
GROUP BY msg_day;

-- 问题2：统计每小时的消息量、发送和接受的用户数
CREATE TABLE db_msg.tb_rs_hour_msg_cnt 
COMMENT "每小时消息量趋势" AS  
SELECT  
    msg_hour, 
    COUNT(*) AS total_msg_cnt, 
    COUNT(DISTINCT sender_account) AS sender_usr_cnt, 
    COUNT(DISTINCT receiver_account) AS receiver_usr_cnt
FROM db_msg.tb_msg_etl GROUP BY msg_hour;

-- 问题3：统计今日各地区发送消息总量
CREATE TABLE IF NOT EXISTS db_msg.tb_rs_loc_cnt(
msg_day string COMMENT '消息日期',
sender_lng double COMMENT '发送人经度',
sender_lat double COMMENT '发送人纬度',
total_msg_cnt bigint COMMENT '消息总量'
)
COMMENT '今日各地区发送消息总量';

INSERT OVERWRITE TABLE db_msg.tb_rs_loc_cnt
SELECT 
    msg_day,  
    sender_lng, 
    sender_lat,
    COUNT(*) AS total_msg_cnt 
FROM db_msg.tb_msg_etl
GROUP BY msg_day, sender_lng, sender_lat;

-- 问题4：统计今日发送和接受用户人数
CREATE TABLE IF NOT EXISTS db_msg.tb_rs_usr_cnt
COMMENT "今日发送消息人数、接受消息人数" AS
SELECT 
msg_day, 
COUNT(DISTINCT sender_account) AS sender_usr_cnt, 
COUNT(DISTINCT receiver_account) AS receiver_usr_cnt
FROM db_msg.tb_msg_etl
GROUP BY msg_day;

-- 问题5：统计发送消息条数量最多的Top10用户
CREATE TABLE IF NOT EXISTS db_msg.tb_rs_s_user_top10
COMMENT "发送消息条数最多的Top10用户" AS
SELECT 
    sender_name AS username, 
    COUNT(*) AS sender_msg_cnt 
FROM db_msg.tb_msg_etl 
GROUP BY sender_name 
ORDER BY sender_msg_cnt DESC 
LIMIT 10;

-- 问题6：统计接受消息条数最多的Top10用户
CREATE TABLE IF NOT EXISTS db_msg.tb_rs_r_user_top10
COMMENT "接收消息条数最多的Top10用户" AS
SELECT 
receiver_name AS username, 
COUNT(*) AS receiver_msg_cnt 
FROM db_msg.tb_msg_etl 
GROUP BY receiver_name 
ORDER BY receiver_msg_cnt DESC 
LIMIT 10;

-- 问题7：统计发送人的手机型号分布情况
CREATE TABLE IF NOT EXISTS db_msg.tb_rs_sender_phone
COMMENT "发送人的手机型号分布" AS
SELECT 
    sender_phonetype, 
    COUNT(sender_account) AS cnt 
FROM db_msg.tb_msg_etl 
GROUP BY sender_phonetype;

-- 问题8：统计发送人的手机操作系统分布
CREATE TABLE IF NOT EXISTS db_msg.tb_rs_sender_os
COMMENT "发送人的OS分布" AS
SELECT
    sender_os, 
    COUNT(sender_account) AS cnt 
FROM db_msg.tb_msg_etl 
GROUP BY sender_os;

-- 删表
DROP TABLE IF EXISTS tb_msg_etl;
DROP TABLE IF EXISTS tb_msg_source;
DROP TABLE IF EXISTS tb_rs_hour_msg_cnt;
DROP TABLE IF EXISTS tb_rs_loc_cnt;
DROP TABLE IF EXISTS tb_rs_r_user_top10;
DROP TABLE IF EXISTS tb_rs_s_user_top10;
DROP TABLE IF EXISTS tb_rs_sender_os;
DROP TABLE IF EXISTS tb_rs_sender_phone;
DROP TABLE IF EXISTS tb_rs_total_msg_cnt;
DROP TABLE IF EXISTS tb_rs_usr_cnt;
