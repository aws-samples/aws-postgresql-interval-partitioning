
CREATE SCHEMA partman;
CREATE EXTENSION pg_partman WITH SCHEMA partman;

CREATE SCHEMA data_mart;

CREATE TABLE data_mart.organization 
( 
	org_id BIGSERIAL,
	org_name TEXT,
	CONSTRAINT pk_organization PRIMARY KEY (org_id)
);

/* In below example, created_at column is used as partition key for the table and is also included as part of the primary key, to enforce uniqueness across partitions */

CREATE TABLE data_mart.events_daily(
    event_id        INT,
    operation       VARCHAR(1),
    value           FLOAT(24),
    parent_event_id BIGINT,
    event_type      VARCHAR(25),
    org_id          BIGSERIAL,
    created_at      TIMESTAMPTZ,
    CONSTRAINT pk_data_mart_events_daily PRIMARY KEY (event_id, created_at),
    CONSTRAINT ck_valid_operation CHECK (operation = 'C' OR operation = 'D'),
    CONSTRAINT fk_orga_membership_events_daily FOREIGN KEY(org_id)
    REFERENCES data_mart.organization (org_id),
    CONSTRAINT fk_parent_event_id_events_daily FOREIGN KEY(parent_event_id, created_at)
    REFERENCES data_mart.events_daily (event_id,created_at)
) PARTITION BY RANGE (created_at);

CREATE INDEX idx_org_id_events_daily     ON data_mart.events_daily(org_id);
CREATE INDEX idx_event_type_events_daily ON data_mart.events_daily(event_type);

CREATE TABLE data_mart.events_monthly(
	event_id        INT,
	value           FLOAT(24),
	parent_event_id BIGINT,
	org_id          VARCHAR(30),
	created_at      TIMESTAMPTZ,
	CONSTRAINT pk_data_mart_events_monthly PRIMARY KEY (event_id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE data_mart.events_quarterly(
	event_id        INT,
	value           FLOAT(24),
	parent_event_id BIGINT,
	org_id          VARCHAR(30),
	created_at      TIMESTAMPTZ,
	CONSTRAINT pk_data_mart_events_quarterly PRIMARY KEY (event_id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE data_mart.events_yearly(
	event_id        INT,
	value           FLOAT(24),
	parent_event_id BIGINT,
	org_id          VARCHAR(30),
	created_at      TIMESTAMPTZ,
	CONSTRAINT pk_data_mart_events_yearly PRIMARY KEY (event_id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE data_mart.events_range(
	event_id        INT,
	value           FLOAT(24),
	parent_event_id BIGINT,
	org_id          VARCHAR(30),
	created_at      TIMESTAMPTZ,
	CONSTRAINT pk_data_mart_events_range PRIMARY KEY (event_id)
) PARTITION BY RANGE (event_id);


SELECT partman.create_parent( p_parent_table => 'data_mart.events_daily',
p_control => 'created_at',
p_type => 'native',
p_interval=> 'daily',
p_start_partition := '2022-01-01 00:00:00'::text,
p_premake => 35);

SELECT partman.create_parent( p_parent_table => 'data_mart.events_monthly',
p_control => 'created_at',
p_type => 'native',
p_interval=> 'monthly',
p_start_partition := '2022-01-01 00:00:00'::text,
p_premake => 13);

SELECT partman.create_parent( p_parent_table => 'data_mart.events_quarterly',
p_control => 'created_at',
p_type => 'native',
p_interval=> '3 months',
p_start_partition := '2022-01-01 00:00:00'::text,
p_premake => 5);

SELECT partman.create_parent( p_parent_table => 'data_mart.events_yearly',
p_control => 'created_at',
p_type => 'native',
p_interval=> 'yearly',
p_start_partition := '2022-01-01 00:00:00'::text,
p_premake => 2);

SELECT partman.create_parent( p_parent_table => 'data_mart.events_range',
p_control => 'event_id',
p_type => 'native',
p_interval=> '10000',
p_start_partition := '1',
p_premake => 3);



update partman.part_config
set infinite_time_partitions=true
where parent_table in ('data_mart.events_daily', 'data_mart.events_monthly', 'data_mart.events_quarterly', 'data_mart.events_yearly');


