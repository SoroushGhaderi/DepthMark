-- Create Silver schema (database) for curated scenario tables
CREATE DATABASE IF NOT EXISTS silver;

-- Staging tables for scoped loads live here, never in warehouse databases (ADR 0029).
CREATE DATABASE IF NOT EXISTS warehouse_stage;
