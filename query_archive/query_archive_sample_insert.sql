use query_archive;


--////////////////////////////////////////////////////////////////////////////////////////////////////////////
--sample #1
insert into query_archive.query (query) values ('select TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, DENSE_RANK() over (order by c.table_catalog, c.table_schema, c.table_name) as table_seq from INFORMATION_SCHEMA.COLUMNS c')

--////////////////////////////////////////////////////////////////////////////////////////////////////////////

insert into query_archive.query (query) values ('create table #some_result (
	ir_id int
	, patient_key varchar(20)
	, first_name varchar(50)
	, last_name varchar(50)
	, med_id int
	, med_name varchar(200)
	, med_dts datetime2(0)
)
insert into #some_result (ir_id, patient_key, first_name, last_name, med_id, med_name, med_dts) values (1, ''a'', ''Homer'', ''Simpson'', 1, ''insulin'', ''January 1, 1980'')
insert into #some_result (ir_id, patient_key, first_name, last_name, med_id, med_name, med_dts) values (1, ''a'', ''Homer'', ''Simpson'', 2, ''warfarin'', ''February 2, 1981'')
insert into #some_result (ir_id, patient_key, first_name, last_name, med_id, med_name, med_dts) values (2, ''b'', ''Monty'', ''Burns'', 3, ''balsam specific'', ''July 1, 1892'')
select * from #some_result
drop table #some_result
')


insert into query_archive.query (query) values ('exec sp_who2')

insert into query_archive.query (query) values ('select ''Dan'' as first_name')





