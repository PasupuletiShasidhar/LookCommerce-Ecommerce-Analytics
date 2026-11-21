# LookCommerce: End-to-End E-Commerce Sales, Retention & Logistics Analytics

An end-to-end business intelligence portfolio project analyzing e-commerce revenue, customer retention (RFM segmentation), product return leakage, and fulfillment operations using **SQL Server (SSMS)** and **Microsoft Power BI**.

---

## Executive Summary & Key Business Findings

* **Revenue & Margin Performance:** Generated **$2.67M** in Net Completed Revenue and **$1.39M** in Net Gross Profit (**51.82%** Gross Margin) across **31K** completed orders, led by Search acquisition and top international markets (China, United States, Brasil).
* **Customer Retention & RFM Segmentation:** Out of **27,337** active buyers (**$97.82** average LTV), **87.83%** are one-time buyers. **6,561 Champions** generate **$1.09M** (**$166.05** LTV, 1.33 avg orders), whereas **15,471** customers sit in *Hibernating / Lost* (9,422) or *At Risk* (6,048) segments—representing the largest lifecycle recovery opportunity.
* **Product Return Leakage:** **$1.09M** in Gross Order Value was lost to returned items (**10.05%** overall return rate), with **Outerwear & Coats** (~$138K) and **Jeans** (~$126K) driving the highest dollar leakage, and **Clothing Sets** (**11.89%**) showing the highest return rate.
* **Logistics & Fulfillment SLAs:** Maintained consistent warehouse execution across all 10 distribution centers—averaging **12.78 hours** from order creation to shipment and **2.95 days** to delivery—even as monthly order volume scaled sharply between 2019 and 2022.

---

## Repository Structure

```text
LookCommerce-Ecommerce-Analytics/
├── PowerBI/
│   └── Look_Commerce_Executive_Dashboard.pbix
├── Reports/
│   └── Look_Commerce_Executive_Dashboard.pdf
├── SQL Scripts/
│   ├── 01_Database_Setup.sql
│   ├── 02_Data_Cleaning.sql
│   ├── 03_Exploratory_Data_Analysis.sql
│   └── 04_Business_Analysis_and_Views.sql
├── screenshots/
│   ├── 01_executive_overview.png
│   ├── 02_customer_retention_rfm.png
│   ├── 03_product_return_leakage.png
│   └── 04_logistics_fulfillment.png
├── .gitignore
└── README.md
