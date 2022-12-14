#!/bin/bash

set -ev
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd ${SCRIPT_DIR}/../../${UTPLSQL_DIR}/source

"$SQLCLI" sys/$ORACLE_PWD@//$CONNECTION_STR AS SYSDBA <<SQL
set serveroutput on
set linesize 200
set trimspool on
declare
  i integer := 0;
begin
  dbms_output.put_line('Dropping synonyms pointing to schema '||upper('${UT3_DEVELOP_SCHEMA}'));
  for syn in (
    select
      case when owner = 'PUBLIC'
        then 'public synonym '
        else 'synonym ' || owner || '.' end || synonym_name as syn_name,
      table_owner||'.'||table_name as for_object
    from all_synonyms s
    where table_owner = upper('${UT3_DEVELOP_SCHEMA}') and table_owner != owner
  )
  loop
    i := i + 1;
    begin
      execute immediate 'drop '||syn.syn_name;
      dbms_output.put_line('Dropped '||syn.syn_name||' for object '||syn.for_object);
    exception
      when others then
        dbms_output.put_line('FAILED to drop '||syn.syn_name||' for object '||syn.for_object||' with error '||sqlerrm);
    end;
  end loop;
  dbms_output.put_line(i||' synonyms dropped');
end;
/
SQL

INSTALL_FILE="install_headless_with_trigger.sql"
if [[ ! -f "${INSTALL_FILE}" ]]; then
 INSTALL_FILE="install_headless.sql"
fi

"$SQLCLI" sys/$ORACLE_PWD@//$CONNECTION_STR AS SYSDBA <<SQL
alter session set plsql_optimize_level=0;
alter session set plsql_ccflags = 'SELF_TESTING_INSTALL:TRUE';

@${INSTALL_FILE} ${UT3_RELEASE_VERSION_SCHEMA} ${UT3_RELEASE_VERSION_SCHEMA_PASSWORD}
exit
SQL

"$SQLCLI" sys/$ORACLE_PWD@//$CONNECTION_STR AS SYSDBA <<SQL
grant select any dictionary to ${UT3_RELEASE_VERSION_SCHEMA};
exit
SQL
