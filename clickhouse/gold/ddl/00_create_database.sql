-- Create Gold schema (database) for analytics-ready aggregates
CREATE DATABASE IF NOT EXISTS gold;
CREATE DATABASE IF NOT EXISTS gold_scenarios;
CREATE DATABASE IF NOT EXISTS gold_signals;

-- Staging tables for scoped loads live here, never in warehouse databases (ADR 0029).
CREATE DATABASE IF NOT EXISTS warehouse_stage;
