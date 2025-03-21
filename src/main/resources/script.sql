create or replace TYPE col_val AS OBJECT (
    col_name VARCHAR2(100),
    col_value VARCHAR2(4000)
);
/
create or replace TYPE col_val_table AS TABLE OF col_val;
/
create or replace FUNCTION execute_query_to_columns(p_query VARCHAR2)
RETURN col_val_table
IS
    ctx         DBMS_XMLGEN.ctxHandle;
    xml_data    CLOB;
    result_list col_val_table := col_val_table();
BEGIN
    ctx := DBMS_XMLGEN.newContext(p_query);
    DBMS_XMLGEN.setMaxRows(ctx, 1);
    xml_data := DBMS_XMLGEN.getXML(ctx);
    DBMS_XMLGEN.closeContext(ctx);

    FOR rec IN (
        SELECT xt.col_name, xt.col_value
        FROM XMLTABLE('/ROWSET/ROW/*' 
                     PASSING XMLTYPE(xml_data)
                     COLUMNS
                         col_name  VARCHAR2(100) PATH 'name()',  -- Changed to col_name
                         col_value VARCHAR2(4000) PATH 'text()'  -- Changed to col_value
                     ) xt
    ) LOOP
        result_list.EXTEND;
        result_list(result_list.LAST) := col_val(rec.col_name, rec.col_value);
    END LOOP;

    RETURN result_list;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_XMLGEN.closeContext(ctx);
        RAISE;
END execute_query_to_columns;
/
create or replace FUNCTION execute_query_to_columns_dbms_sql(p_query VARCHAR2)
RETURN col_val_table
IS
    l_cursor      INTEGER;
    l_columns     NUMBER;
    l_desc_tab    DBMS_SQL.DESC_TAB;
    l_value       VARCHAR2(4000);
    result_list   col_val_table := col_val_table();
BEGIN
    -- Open cursor and parse query
    l_cursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(l_cursor, p_query, DBMS_SQL.NATIVE);
    DBMS_SQL.DESCRIBE_COLUMNS(l_cursor, l_columns, l_desc_tab);

    -- Define columns for VARCHAR2 output
    FOR i IN 1..l_columns LOOP
        DBMS_SQL.DEFINE_COLUMN(l_cursor, i, l_value, 4000);
    END LOOP;

    -- Execute and fetch row
    IF DBMS_SQL.EXECUTE_AND_FETCH(l_cursor) = 1 THEN
        -- Process columns
        FOR i IN 1..l_columns LOOP
            DBMS_SQL.COLUMN_VALUE(l_cursor, i, l_value);
            result_list.EXTEND;
            result_list(result_list.LAST) := 
                col_val(
                    col_name  => l_desc_tab(i).col_name,
                    col_value => l_value
                );
        END LOOP;
    ELSE
        RAISE_APPLICATION_ERROR(-20001, 'Query must return exactly 1 row');
    END IF;

    DBMS_SQL.CLOSE_CURSOR(l_cursor);
    RETURN result_list;

EXCEPTION
    WHEN OTHERS THEN
        IF DBMS_SQL.IS_OPEN(l_cursor) THEN
            DBMS_SQL.CLOSE_CURSOR(l_cursor);
        END IF;
        RAISE;
END execute_query_to_columns_dbms_sql;
/

/*
  select COL_VALUE from table(execute_query_to_columns('SELECT sysdate AS col1, 42 AS col2 FROM DUAL')) WHERE COL_NAME = 'COL1';
  select COL_VALUE from table(EXECUTE_QUERY_TO_COLUMNS_DBMS_SQL('SELECT sysdate AS col1, 42 AS col2 FROM DUAL')) WHERE COL_NAME = 'COL1';
*/

create or replace PROCEDURE process_dynamic_query(p_query VARCHAR2) IS
  -- Declare an associative array (hashmap) to store column values
  TYPE col_map_type IS TABLE OF VARCHAR2(4000) INDEX BY VARCHAR2(100);
  v_col_map col_map_type;

  -- Call your existing function to get column-value pairs
  l_result col_val_table;
BEGIN
  -- Get the result from the function
  l_result := execute_query_to_columns_dbms_sql(p_query);

  -- Populate the hashmap
  FOR i IN 1..l_result.COUNT LOOP
    v_col_map(l_result(i).col_name) := l_result(i).col_value;
  END LOOP;

  -- Example: Retrieve values from the hashmap
  DBMS_OUTPUT.PUT_LINE('Today: ' || v_col_map('TODAY'));
  DBMS_OUTPUT.PUT_LINE('Price: ' || v_col_map('PRICE'));

  -- Add your custom logic here using v_col_map
  -- Example: Convert to DATE/NUMBER
  -- l_date DATE := TO_DATE(v_col_map('TODAY'), 'YYYY-MM-DD');
  -- l_price NUMBER := TO_NUMBER(v_col_map('PRICE'));

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20001, 'Query returned no rows');
  WHEN TOO_MANY_ROWS THEN
    RAISE_APPLICATION_ERROR(-20002, 'Query returned multiple rows');
  WHEN OTHERS THEN
    RAISE;
END process_dynamic_query;
/

