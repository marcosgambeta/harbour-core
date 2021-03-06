#require "hbfbird"

/* NOTE: If firebird server is not installed, you can run
         it as a standalone application using:
            fbserver -a
 */

PROCEDURE Main()

   LOCAL cServer := "localhost:"
   LOCAL cDatabase := hb_FNameExtSet( hb_ProgName(), ".fdb" )
   LOCAL cUser := "SYSDBA"
   LOCAL cPass := "masterkey"
   LOCAL nPageSize := 1024
   LOCAL cCharSet := "UTF8"
   LOCAL nDialect := 1

   LOCAL trans, qry

   LOCAL db, x, y
   LOCAL num_cols
   LOCAL columns
   LOCAL fetch_stat
   LOCAL tmp

   hb_vfErase( cDatabase )

   ? tmp := FBCreateDB( cServer + cDatabase, cUser, cPass, nPageSize, cCharSet, nDialect ), FBError( tmp )

   /* Connect RDBMS */
   IF HB_ISNUMERIC( db := FBConnect( cServer + cDatabase, cUser, cPass ) )
      ? "Error:", db, FBError( db )
      RETURN
   ENDIF

   ? "Testing invalid request"
   ? tmp := FBExecute( db, "sldjfs;ldjs;djf", nDialect ), FBError( tmp )

   IF HB_ISNUMERIC( trans := FBStartTransaction( db ) )
      ? "Error:", trans, FBError( trans )
   ELSE
      ? tmp := FBQuery( db, "create table teste (code smallint)", nDialect, trans ), FBError( tmp )
      ? tmp := FBCommit( trans ), FBError( tmp )
   ENDIF

   ? "==="
   IF HB_ISNUMERIC( trans := FBStartTransaction( db ) )
      ? "Error:", trans, FBError( trans )
   ELSE
      ? tmp := FBQuery( db, "CREATE TABLE customer( customer VARCHAR(20) )", nDialect, trans ), FBError( tmp )
      ? tmp := FBCommit( trans ), FBError( tmp )
   ENDIF
   ? "==="

   IF HB_ISNUMERIC( trans := FBStartTransaction( db ) )
      ? "Error:", trans, FBError( trans )
   ELSE
      ? "Status Execute:", tmp := FBExecute( db, 'insert into customer(customer) values ("test 1")', nDialect, trans ), FBError( tmp )
      ? "Status Rollback:", tmp := FBRollback( trans ), FBError( tmp )
   ENDIF

   IF HB_ISNUMERIC( trans := FBStartTransaction( db ) )
      ? "Error:", trans, FBError( trans )
   ELSE
      ? "Status Execute:", tmp := FBExecute( db, 'insert into customer(customer) values ("test 2")', nDialect, trans ), FBError( tmp )
      ? "Status Commit:", tmp := FBCommit( trans ), FBError( tmp )
   ENDIF

   ? "Status Execute:", tmp := FBExecute( db, 'insert into customer(customer) values ("test 3")', nDialect ), FBError( tmp )

   // FIXME: Windows GPF below

   IF HB_ISNUMERIC( qry := FBQuery( db, "SELECT * FROM customer", nDialect ) )
      ? "Error:", qry, FBError( qry )
   ELSE
      num_cols := qry[ 4 ]
      columns := qry[ 6 ]

      FOR x := 1 TO num_cols
         ? x, "> "
         FOR EACH y IN columns[ x ]
            ?? y, ""
         NEXT
      NEXT

      ? "---"

      DO WHILE ( fetch_stat := FBFetch( qry ) ) == 0
         ? fetch_stat
         FOR x := 1 TO num_cols
            ?? FBGetData( qry, x ), ", "
         NEXT
      ENDDO

      ? "Fetch code:", fetch_stat

      ? "Status Free Query:", FBFree( qry )
   ENDIF

   /* Close connection with RDBMS */
   ? "Status Close Database:", tmp := FBClose( db ), FBError( tmp )

   RETURN
