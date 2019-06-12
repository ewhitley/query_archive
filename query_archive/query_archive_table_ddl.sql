

--use staging;
use query_archive;

--/////////////////////////////////////////////////////////////////////////////
IF NOT EXISTS (
SELECT  schema_name
FROM    information_schema.schemata
WHERE   schema_name = 'query_archive' ) 

BEGIN
EXEC sp_executesql N'CREATE SCHEMA query_archive'
END
--/////////////////////////////////////////////////////////////////////////////


--/////////////////////////////////////////////////////////////////////////////
--drop table query_archive.query
create table query_archive.query (
	query_id int IDENTITY(1,1) NOT NULL
	, query varchar(max) NOT NULL
	, result_format varchar(10) NOT NULL DEFAULT 'JSON'
	 CONSTRAINT [pk_qa_query_archive] PRIMARY KEY CLUSTERED 
	(
		query_id asc
	) WITH (DATA_COMPRESSION = PAGE)
)

create table query_archive.query_stored_result (
	query_id int NOT NULL
	, result_dts datetime2(0) NOT NULL DEFAULT GETDATE()
	, result_data varchar(max) --your json or whatever
	, result_format varchar(10) NOT NULL DEFAULT 'JSON'
	 CONSTRAINT [pk_qa_query_stored_result] PRIMARY KEY CLUSTERED 
	(
		query_id asc
	) WITH (DATA_COMPRESSION = PAGE)
)

create nonclustered index ix_qa_NULL_query_id on query_archive.query_stored_result (query_id) with(data_compression = page)

create table query_archive.query_stored_result_columns (
	stored_result_column_id int identity (1,1) NOT NULL
	, query_id int NOT NULL
	, column_name varchar(100) NOT NULL
	, data_type varchar(50) NOT NULL
	 CONSTRAINT [pk_qa_query_stored_result_columns] PRIMARY KEY CLUSTERED 
	(
		stored_result_column_id ASC
	) WITH (DATA_COMPRESSION = PAGE)
)

create nonclustered index ix_qa_query_stored_result_columns_query_id on query_archive.query_stored_result_columns (query_id) with(data_compression = page)



