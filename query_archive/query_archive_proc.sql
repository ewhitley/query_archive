use query_archive;
GO

create or alter procedure query_archive.get_query_stored_result
	@query_id int		--the ID of the query where we already have stored results populated
	, @debug int = 0	--1/0
as

SET NOCOUNT ON

--this is our ultimate query we'll run to pull stored data and map it to our requested columns
declare @query_sql nvarchar(max)


--////////////////////////////////////////////////////////////////
-- FORMAT OUTPUT FOR SSRS (or other tools)
-- we want to pull a list of our selected columns (from our configuration)
-- and then strongly type them for SSRS to inspect. We'll then get metadata that describes our final
-- intended result structure
--////////////////////////////////////////////////////////////////

--query our column info and put it into a table variable for reuse
declare @column_list_table table
(
	query_id int,
	column_name varchar(255), 
	data_type varchar(255)
) 

--populate it with our query-specific list of column names and target data types
insert into @column_list_table (query_id, column_name, data_type)
select query_id, column_name, data_type from query_archive.query_stored_result_columns where query_id = @query_id

--once we have our column list, convert it into a SQL string with names and types
-- EX: col_1 int, col_2 varchar(10), col_3 datetime2(0)... etc.
declare @column_list nvarchar(max) = ''

set @column_list = (
	SELECT 
	top 1
	SUBSTRING(
		(
			SELECT ','+'cast(null as ' + src1.data_type + ') as ' + src1.column_name  AS [text()]
			FROM @column_list_table src1
			WHERE src1.query_id = src2.query_id
			and src1.query_id = @query_id
			ORDER BY src1.query_id
			FOR XML PATH ('')
		), 2, 1000) [column_list]
	FROM @column_list_table src2
)

if @debug = 1
BEGIN
	DECLARE @column_list_print nvarchar(max) = replace(@column_list, ',', char(10))
	RAISERROR ('', 10, 1) WITH NOWAIT
	RAISERROR ('Column list info:', 10, 1) WITH NOWAIT
	RAISERROR ('======================================', 10, 1) WITH NOWAIT
	RAISERROR (@column_list_print, 10, 1) WITH NOWAIT
END

set @query_sql = 'select ' + @column_list

IF @debug = 1
BEGIN
	RAISERROR ('', 10, 1) WITH NOWAIT
	RAISERROR ('Dynamic query SQL:', 10, 1) WITH NOWAIT
	RAISERROR ('======================================', 10, 1) WITH NOWAIT
	RAISERROR (@query_sql, 10, 1) WITH NOWAIT
END

--now, the part that outputs the FORMAT info
-- We want to emit the FORMATTING information when requested
-- the old way of doing this (pre-2012) was to run a select query against fake (typed) columns
--anything less than 11 (2012) should be handled differently
declare @sql_version int = (select @@MICROSOFTVERSION / POWER(2, 24))
if @sql_version < 11
	if 1=0
		EXEC sp_executesql @query_sql;
ELSE
	exec sp_describe_first_result_set @query_sql

--////////////////////////////////////////////////////////////////
-- VALIDATE
-- Let's tell people if there are no results or no column info
--////////////////////////////////////////////////////////////////
declare @has_results int = (select count(*) from query_archive.query_stored_result where query_id = @query_id)

if @has_results < 1
BEGIN
	RAISERROR ('', 10, 1) WITH NOWAIT
	RAISERROR ('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!', 10, 1) WITH NOWAIT
	RAISERROR ('WARNING! NO STORED RESULTS found for requested query', 10, 1) WITH NOWAIT
END

declare @has_columns int = (select count(*) from @column_list_table)

if @has_columns < 1
BEGIN
	RAISERROR ('', 10, 1) WITH NOWAIT
	RAISERROR ('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!', 10, 1) WITH NOWAIT
	RAISERROR ('WARNING! NO COLUMN INFORMATION found for requested query', 10, 1) WITH NOWAIT
END

--////////////////////////////////////////////////////////////////
-- CONVERT OUR DATA SET TO STRONGLY TYPED RESULTS
--////////////////////////////////////////////////////////////////


declare @result_format varchar(10)
set @result_format = (select top 1 result_format from query_archive.query_stored_result where query_id = @query_id)

IF @debug = 1
BEGIN
	RAISERROR ('', 10, 1) WITH NOWAIT
	RAISERROR ('Dynamic query formatting for:', 10, 1) WITH NOWAIT
	RAISERROR ('======================================', 10, 1) WITH NOWAIT
	RAISERROR (@result_format, 10, 1) WITH NOWAIT
END

declare @format_column_list varchar(max)

set @query_sql = ''

--/////////////////////////////////////////////////////////////////////////////////////////////////
--START OF JSON BLOCK
if @result_format = 'JSON'
BEGIN
			
	set @format_column_list = (
		SELECT 
		top 1
		SUBSTRING(
			(
				SELECT ','+ '[' + column_name + '] ' + data_type + '''$.' + column_name + ''''  AS [text()]
				FROM @column_list_table src1
				WHERE src1.query_id = src2.query_id
				and src1.query_id = @query_id
				ORDER BY src1.query_id
				FOR XML PATH ('')
			), 2, 1000) [column_list]
		FROM @column_list_table src2
	)

	IF @debug = 1
	BEGIN
		DECLARE @format_column_list_print_json nvarchar(max) = replace(@format_column_list, ',', char(10))
		RAISERROR ('', 10, 1) WITH NOWAIT
		RAISERROR ('JSON column list: ', 10, 1) WITH NOWAIT
		RAISERROR ('======================================', 10, 1) WITH NOWAIT
		RAISERROR (@format_column_list_print_json, 10, 1) WITH NOWAIT
	END

	set @query_sql = '
		select
			result_data.*
		from
			query_archive.query_stored_result sr
			CROSS APPLY OPENJSON(sr.result_data, ''$'')
				WITH (
					'+ @format_column_list +'
				) as result_data
		where
			sr.query_id =  ' + cast(@query_id as varchar(10)) + '
			and sr.result_format = ''JSON''
	'
			
END 
--END OF JSON BLOCK
--/////////////////////////////////////////////////////////////////////////////////////////////////


--/////////////////////////////////////////////////////////////////////////////////////////////////
--START OF XML BLOCK
if @result_format = 'XML'
BEGIN
			

	RAISERROR ('in XML block', 10, 1) WITH NOWAIT

	set @format_column_list = (
		SELECT 
		top 1
		SUBSTRING(
			(
				--x.c.value('@ir_id', 'INT') ir_id
				--SELECT ','+ 'x.c.value(''@' + column_name + ''',''' + data_type + ''') ' + '[' + column_name +']'  AS [text()]
				--					,x.c.query('./ir_id').value('.', 'int') AS 'ir_id'

				--SELECT ','+ 'x.c.query(''./' + column_name + ''').value(''.'',''' + data_type + ''') ' + '[' + column_name +']'  AS [text()] --insanely slow
				SELECT ','+ 'x.c.value(''(' + column_name + '/text())[1]'',''' + data_type + ''') ' + ' as [' + column_name +']'  AS [text()] --still slow
				--	x.c.value('(TABLE_CATALOG/text())[1]', 'varchar(255)') as TABLE_CATALOG
				FROM @column_list_table src1
				WHERE src1.query_id = src2.query_id
				and src1.query_id = @query_id
				ORDER BY src1.query_id
				FOR XML PATH ('')
			), 2, 1000) [column_list]
		FROM @column_list_table src2
	)

	IF @debug = 1
	BEGIN
		DECLARE @format_column_list_print_xml nvarchar(max) = replace(@format_column_list, ',', char(10))
		RAISERROR ('', 10, 1) WITH NOWAIT
		RAISERROR ('XML column list: ', 10, 1) WITH NOWAIT
		RAISERROR ('======================================', 10, 1) WITH NOWAIT
		RAISERROR (@format_column_list_print_xml, 10, 1) WITH NOWAIT
	END


	set @query_sql = '
		;with my_data as (
			select
				try_cast(sr.result_data as xml) as result_data
			from
				query_archive.query_stored_result sr
			where
				sr.query_id = ' + cast(@query_id as varchar(10)) + '
				and sr.result_format = ''XML''
		)
		select
			' + @format_column_list + '
		from
			my_data md
			CROSS APPLY md.result_data.nodes(''row'') x(c)
	'
			
END 
--END OF XML BLOCK
--/////////////////////////////////////////////////////////////////////////////////////////////////

IF @debug = 1
BEGIN
	RAISERROR ('', 10, 1) WITH NOWAIT
	RAISERROR ('Final query SQL:', 10, 1) WITH NOWAIT
	RAISERROR ('======================================', 10, 1) WITH NOWAIT
	RAISERROR (@query_sql, 10, 1) WITH NOWAIT	
END

if @query_sql <> ''
	EXEC sp_executesql @query_sql;



