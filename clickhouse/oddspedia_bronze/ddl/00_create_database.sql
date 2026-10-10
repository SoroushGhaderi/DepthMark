CREATE DATABASE IF NOT EXISTS oddspedia_bronze;

-- Staging tables for scoped loads live here, never in warehouse databases (ADR 0029).
CREATE DATABASE IF NOT EXISTS warehouse_stage;
