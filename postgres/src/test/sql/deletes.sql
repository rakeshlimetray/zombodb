SET datestyle TO 'iso, mdy';

-- vacuum the so_posts table to make sure there are no dead rows in our ES index
VACUUM so_posts;

--
-- in a transaction, delete 3k records from so_posts and ensure that ES is correct when the xact is finished
--
BEGIN;

CREATE TABLE deltmp AS SELECT * FROM so_posts WHERE id IN (SELECT id FROM so_posts ORDER BY random() LIMIT 3000);
ALTER TABLE deltmp ADD PRIMARY KEY (id);

DELETE FROM so_posts WHERE id IN (SELECT id FROM deltmp);

SELECT assert(count(*), 162240, 'deleted 3k records from so_posts') FROM so_posts;
SELECT assert(count(*), 162240, 'deleted 3k records from so_posts (id:*)') FROM so_posts WHERE zdb('so_posts', ctid) ==> 'id:*';

SELECT assert(zdb_estimate_count('so_posts', 'id:*'), 162240, 'make sure ES does not still sees deleted rows');

-- the *actual* number of records elasticsearch has in the and 'data' type
-- should actually be 10k as well
SELECT assert (zdb_actual_index_record_count('so_posts', 'data'), 165240, 'actual data after delete');

COMMIT;

SELECT assert(count(*), 162240, 'actually deleted 3k records from so_posts') FROM so_posts;
SELECT assert(count(*), 162240, 'actually deleted 3k records from so_posts (id:*)') FROM so_posts WHERE zdb('so_posts', ctid) ==> 'id:*';

-- restore the 3k records we deleted
INSERT INTO so_posts SELECT * FROM deltmp;
DROP TABLE deltmp;

SELECT assert(count(*), 165240, 'restored deleted 3k records to so_posts') FROM so_posts;
SELECT assert(count(*), 165240, 'restored deleted 3k records to so_posts (id:*)') FROM so_posts WHERE zdb('so_posts', ctid) ==> 'id:*';

-- now the *actual* number of records elasticsearch has in the 'data' type
-- should be 13k:  the initial 10k plus the 3k we just added
SELECT assert (zdb_actual_index_record_count('so_posts', 'data'), 168240, 'actual data after inserting 3k');


-- vacuum the so_posts table to remove dead rows (3k of them)
VACUUM so_posts;

-- and now the *actual* number of records elasticsearch has should be 10k
SELECT assert (zdb_actual_index_record_count('so_posts', 'data'), 165240, 'actual data after vacuum');

--
-- again, delete 3k random records, but this time abort the transaction, which will keep us with 10k records everywhere
--

BEGIN;

DELETE FROM so_posts WHERE id IN (SELECT id FROM so_posts ORDER BY random() LIMIT 3000);

SELECT assert(count(*), 162240, 'deleted 3k records from so_posts') FROM so_posts;
SELECT assert(count(*), 162240, 'deleted 3k records from so_posts (id:*)') FROM so_posts WHERE zdb('so_posts', ctid) ==> 'id:*';

ABORT;

SELECT assert(count(*), 165240, 'aborted deleted 3k records to so_posts') FROM so_posts;
SELECT assert(count(*), 165240, 'aborted deleted 3k records to so_posts (id:*)') FROM so_posts WHERE zdb('so_posts', ctid) ==> 'id:*';

-- vacuum the so_posts table to remove dead rows (3k of them)
VACUUM so_posts;

-- and now the *actual* number of records elasticsearch has should still be 10k
SELECT assert (zdb_actual_index_record_count('so_posts', 'data'), 165240, 'actual data after aborting delete and vacuum');
