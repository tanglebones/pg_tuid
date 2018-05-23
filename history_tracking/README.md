This is an example of using tuids to track modifications of data over time across multiple tables (using tuid ids and transaction ids to collate changes in a transaction).

I'm using `table_id` as the id column here and building the trigger dynamically becase we need a way to track changes in xref tables (this assumes one sided tracking, a version of the `add_history_to_table` function could be build to track both sides of the xref by taking two id column names in).

I hope to clean this up into something more than a proof of concept soon.
