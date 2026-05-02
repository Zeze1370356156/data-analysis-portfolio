1. 数据集来源与背景
这份数据集来源于巴西知名的电商平台 Olist Store（Olist Brazilian E-commerce）。数据集包含了该平台在巴西境内的交易记录，涵盖了从 2016 年到 2018 年 间的订单信息。
数据采集的背景是基于巴西电商市场的快速发展，旨在提供一个真实、多维度的商业数据集，用于分析消费者行为、物流表现以及市场趋势。该数据集目前托管在 Kaggle 平台上，是数据分析和机器学习领域常用的公开数据集之一。

当前环境信息：
文档生成时间：2026年5月2日 (星期六)
文档生成地点：中国上海市
数据源链接：[Olist Brazilian E-commerce Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
2. 客户数据集 (Customers Dataset) 介绍
Customers Dataset 是该数据集的核心组成部分之一，主要记录了客户的身份信息及其地理位置。
主要字段说明：

| 字段名 | 描述 | 备注 |
| :--- | :--- | :--- |
| customer_id | 订单客户ID | 与特定订单绑定的唯一ID |
| customer_unique_id | 唯一客户ID | 用于识别同一客户在不同订单中的重复购买行为 |
| customer_zip_code_prefix | 邮编前缀 | 客户所在地的邮政编码前5位 |
| customer_city | 城市 | 客户所在城市名称 |
| customer_state | 州 | 客户所在的州（行政区划） |