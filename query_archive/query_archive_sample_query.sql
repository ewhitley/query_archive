SET NOCOUNT ON

--get a query that has results
declare @query_id int = (select top 1 query_id from query_archive.query_archive.query_stored_result order by query_id)

--look at our queries
select q.*
from query_archive.query_archive.query q
where q.query_id = @query_id
order by q.query_id

--message out our sample query
DECLARE @content nvarchar(max)
SET @content = (select top 1 query from query_archive.query_archive.query where query_id = @query_id)
RAISERROR ('', 10, 1) WITH NOWAIT
RAISERROR ('Query:', 10, 1) WITH NOWAIT
RAISERROR ('======================================', 10, 1) WITH NOWAIT
RAISERROR (@content, 10, 1) WITH NOWAIT

--look at our results
select qsr.*
from query_archive.query_archive.query_stored_result qsr
where qsr.query_id = @query_id
order by qsr.query_id

--message out our sample result
SET @content = (select top 1 result_data from query_archive.query_archive.query_stored_result where query_id = @query_id)
SET @content = replace(@content, '{', char(10) + '{ ')
RAISERROR ('', 10, 1) WITH NOWAIT
RAISERROR ('Result:', 10, 1) WITH NOWAIT
RAISERROR ('======================================', 10, 1) WITH NOWAIT
RAISERROR (@content, 10, 1) WITH NOWAIT

--look at our column list
select qsrc.*
from query_archive.query_archive.query_stored_result_columns qsrc
where qsrc.query_id = @query_id
order by qsrc.query_id, qsrc.stored_result_column_id

--get our query result
exec query_archive.query_archive.get_query_stored_result @query_id = @query_id, @debug = 1


--////////////////////////////////////////////////////
-- now let's try one query with multiple result sets
--////////////////////////////////////////////////////
declare @query_with_multiple int
declare @max_result_id int = 1
;with has_multiple_results as (
	select
		top 1
		query_id
		, count(*) as num_results
	from
		query_archive.query_archive.query_stored_result sr
	group by
		query_id
	having
		count(*) > 1
	order by
		num_results desc
)
SELECT 
	@query_with_multiple = query_id
	, @max_result_id = num_results 
FROM 
	has_multiple_results 

if @query_with_multiple is not null and @max_result_id > 1
BEGIN
	exec query_archive.query_archive.get_query_stored_result @query_id = @query_with_multiple
	exec query_archive.query_archive.get_query_stored_result @query_id = @query_with_multiple, @resultset_id = @max_result_id
END
ELSE
	RAISERROR ('None of your queries have multiple results. Try writing a statement that returns multiple data sets.', 10, 1) WITH NOWAIT



