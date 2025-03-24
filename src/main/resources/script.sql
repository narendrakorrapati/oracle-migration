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

CREATE OR REPLACE PROCEDURE process_dynamic_query(
    p_select_query  IN VARCHAR2,  -- Query to populate the map
    p_insert_query  IN VARCHAR2   -- INSERT statement with placeholders
) IS
    -- Hashmap to store column values
    TYPE col_map_type IS TABLE OF VARCHAR2(4000) INDEX BY VARCHAR2(100);
    v_col_map col_map_type;

    -- Variables for DBMS_SQL
    l_cursor        INTEGER;
    l_execute_res   NUMBER;
    l_col_val_tab   col_val_table;
BEGIN
    -- Step 1: Populate v_col_map using your existing function
    l_col_val_tab := execute_query_to_columns_dbms_sql(p_select_query);
    FOR i IN 1..l_col_val_tab.COUNT LOOP
        v_col_map(l_col_val_tab(i).col_name) := l_col_val_tab(i).col_value;
    END LOOP;

    -- Step 2: Process the INSERT statement
    l_cursor := DBMS_SQL.OPEN_CURSOR;
    
    -- Parse the INSERT statement
    DBMS_SQL.PARSE(l_cursor, p_insert_query, DBMS_SQL.NATIVE);
    
    -- Bind all placeholders dynamically
    FOR r IN (
        -- Extract placeholder names (e.g., "ID" from ":ID")
        SELECT DISTINCT UPPER(REGEXP_SUBSTR(p_insert_query, ':(\w+)', 1, LEVEL, NULL, 1)) AS placeholder
        FROM DUAL
        CONNECT BY REGEXP_SUBSTR(p_insert_query, ':(\w+)', 1, LEVEL) IS NOT NULL
    ) LOOP
        IF v_col_map.EXISTS(r.placeholder) THEN
            -- Bind value to placeholder (supports implicit type conversion)
            DBMS_SQL.BIND_VARIABLE(l_cursor, r.placeholder, v_col_map(r.placeholder));
        ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Placeholder "' || r.placeholder || '" not found in map');
        END IF;
    END LOOP;

    -- Execute the INSERT
    l_execute_res := DBMS_SQL.EXECUTE(l_cursor);
    DBMS_SQL.CLOSE_CURSOR(l_cursor);

    DBMS_OUTPUT.PUT_LINE('Inserted ' || l_execute_res || ' row(s)');
EXCEPTION
    WHEN OTHERS THEN
        IF DBMS_SQL.IS_OPEN(l_cursor) THEN
            DBMS_SQL.CLOSE_CURSOR(l_cursor);
        END IF;
        RAISE;
END process_dynamic_query;
/

--Get Place holder using DBMS_SQL instead of regex.
CREATE OR REPLACE PROCEDURE process_dynamic_query(
  p_select_query IN VARCHAR2,
  p_insert_query IN VARCHAR2
) IS
  TYPE col_map_type IS TABLE OF VARCHAR2(4000) INDEX BY VARCHAR2(100);
  v_col_map col_map_type;

  l_cursor        INTEGER;
  l_execute_res   NUMBER;
  l_col_val_tab   col_val_table;
  l_placeholder   VARCHAR2(100);
  l_pos           NUMBER;
BEGIN
  -- Populate v_col_map
  l_col_val_tab := execute_query_to_columns_dbms_sql(p_select_query);
  FOR i IN 1..l_col_val_tab.COUNT LOOP
    v_col_map(l_col_val_tab(i).col_name) := l_col_val_tab(i).col_value;
  END LOOP;

  -- Parse the SQL to identify valid placeholders
  l_cursor := DBMS_SQL.OPEN_CURSOR;
  DBMS_SQL.PARSE(l_cursor, p_insert_query, DBMS_SQL.NATIVE);

  -- Loop through all valid bind variables in the SQL
  l_pos := 1;
  WHILE TRUE LOOP
    BEGIN
      -- Get the name of the placeholder at position l_pos
      DBMS_SQL.VARIABLE_NAME(l_cursor, l_pos, l_placeholder);
      l_placeholder := UPPER(TRIM(l_placeholder)); -- Case-insensitive

      -- Check if the placeholder exists in v_col_map
      IF v_col_map.EXISTS(l_placeholder) THEN
        DBMS_SQL.BIND_VARIABLE(l_cursor, l_placeholder, v_col_map(l_placeholder));
      ELSE
        RAISE_APPLICATION_ERROR(-20001, 'Placeholder "' || l_placeholder || '" not found in map');
      END IF;

      l_pos := l_pos + 1;
    EXCEPTION
      WHEN OTHERS THEN
        EXIT; -- Exit loop when no more placeholders
    END;
  END LOOP;

  -- Execute and close
  l_execute_res := DBMS_SQL.EXECUTE(l_cursor);
  DBMS_SQL.CLOSE_CURSOR(l_cursor);

EXCEPTION
  WHEN OTHERS THEN
    IF DBMS_SQL.IS_OPEN(l_cursor) THEN
      DBMS_SQL.CLOSE_CURSOR(l_cursor);
    END IF;
    RAISE;
END process_dynamic_query;
/
