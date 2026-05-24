# Sales Data Warehouse & Analytics — Medallion Architecture

A production-style data warehouse built from scratch using **PostgreSQL**, integrating CRM and ERP source systems into a unified Star Schema analytical platform. Covers full data engineering: raw ingestion → cleaning & transformation → business-ready analytics.

---

## Architecture

The warehouse follows **Medallion Architecture** — three progressive layers, each serving a distinct purpose:
!(Docs/architecture.png)
```
CRM CSVs  ──┐
             ├──▶  Bronze (raw)  ──▶  Silver (clean)  ──▶  Gold (analytics)  ──▶  BI / Reports
ERP CSVs  ──┘
```

| Layer | Purpose | Tables |
|---|---|---|
| **Bronze** | Immutable raw storage, loaded directly from CSV | `crm_cust_info`, `crm_prd_info`, `crm_sales_details`, `erp_cust_az12`, `erp_loc_a101`, `erp_px_cat_g1v2` |
| **Silver** | Cleansed, normalised, deduplicated analytical tables | Same 6 tables, transformed |
| **Gold** | Star Schema views — business-ready for reporting | `dim_customers`, `dim_products`, `fact_sales` |

---

## Data Model — Star Schema

```
                    ┌─────────────────────┐
                    │   dim_customers      │
                    │─────────────────────│
                    │ customer_key (PK)    │
                    │ customer_id          │
                    │ first_name           │
                    │ last_name            │
                    │ country              │
                    │ gender               │
                    │ marital_status       │
                    │ birthdate            │
                    └──────────┬──────────┘
                               │
                               │ customer_key
                               ▼
┌─────────────────────┐   ┌──────────────────────┐
│   dim_products       │   │     fact_sales        │
│─────────────────────│   │──────────────────────│
│ product_key (PK)    │──▶│ product_key (FK)      │
│ product_id          │   │ customer_key (FK)     │
│ product_name        │   │ order_number          │
│ category            │   │ order_date            │
│ subcategory         │   │ shipping_date         │
│ product_line        │   │ due_date              │
│ cost                │   │ sales_amount          │
│ maintenance         │   │ quantity              │
└─────────────────────┘   │ price                 │
                           └──────────────────────┘
```

---

## ETL Transformations — Silver Layer

Key data quality operations applied in `silver.load_silver()`:

| Table | Transformation |
|---|---|
| `crm_cust_info` | Deduplication via `ROW_NUMBER()`, gender/marital status normalisation (`'M'` → `'Married'`) |
| `crm_prd_info` | Category ID extraction from product key, end date derived via `LEAD()` window function |
| `crm_sales_details` | Integer date → `DATE` conversion via `TO_DATE()`, sales recalculation when `sales ≠ qty × price` |
| `erp_cust_az12` | `NAS` prefix removal from CID, future birthdates set to `NULL` |
| `erp_loc_a101` | Hyphen removal from CID, country code normalisation (`'DE'` → `'Germany'`) |

---

## Analytics Queries

`Scripts/analytics/analytics_queries.sql` contains **23 production-grade queries** across 4 domains:

- **Sales Performance** — KPIs, monthly trends, YoY growth, fulfilment speed
- **Product Analytics** — Top/bottom performers, revenue by category, margin analysis
- **Customer Analytics** — CLV segmentation, country/gender/age breakdown, Customer 360
- **Advanced** — Running totals, MoM growth, best product per country, retention analysis

---

## Repository Structure

```
DATAWAREHOUSE-SQL-PROJECT/
│
├── Datasets/
│   ├── source_crm/          # cust_info.csv, prd_info.csv, sales_details.csv
│   └── source_erp/          # cust_az12.csv, loc_a101.csv, px_cat_g1v2.csv
│
├── Docs/
│   └── architecture.png     # Architecture diagram
│
├── Scripts/
│   ├── bronze/
│   │   ├── ddl_bronze.sql           # Bronze schema + table definitions
│   │   └── proc_load_bronze.sql     # COPY from CSV into bronze tables
│   ├── silver/
│   │   ├── ddl_silver.sql           # Silver schema + table definitions
│   │   └── proc_load_silver.sql     # ETL procedure: bronze → silver
│   ├── gold/
│   │   └── ddl_gold.sql             # Star Schema views (dim + fact)
│   └── analytics/
│       └── analytics_queries.sql    # 23 analytical SQL queries
│
└── Tests/
    └── quality_checks_silver.sql    # Data quality validation queries
```

---

## How to Run

### Prerequisites
- PostgreSQL 14+
- A PostgreSQL client (psql, DBeaver, pgAdmin)
- CSV datasets in `Datasets/`

### Step-by-step

**1. Create the database**
```sql
CREATE DATABASE datawarehouse;
```

**2. Create Bronze layer and load raw data**
```sql
\i Scripts/bronze/ddl_bronze.sql
\i Scripts/bronze/proc_load_bronze.sql
CALL bronze.load_bronze();
```

**3. Create Silver layer and run ETL**
```sql
\i Scripts/silver/ddl_silver.sql
\i Scripts/silver/proc_load_silver.sql
CALL silver.load_silver();
```

**4. Create Gold layer (Star Schema views)**
```sql
\i Scripts/gold/ddl_gold.sql
```

**5. Run analytics queries**
```sql
\i Scripts/analytics/analytics_queries.sql
```

> **Note:** Before running `proc_load_bronze.sql`, update the CSV file paths inside the procedure to match your local `Datasets/` folder location.

---

## Tech Stack

| Tool | Purpose |
|---|---|
| PostgreSQL | Data warehouse engine |
| SQL (DDL + DML) | Schema design, ETL procedures, analytics |
| Star Schema | Gold layer data modelling |
| Medallion Architecture | Layered warehouse design pattern |

---

## License

MIT
