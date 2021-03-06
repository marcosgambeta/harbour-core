/*
 * Demonstration/test code for alternative RDD IO API, RPC and
 * asynchronous data streams in NETIO
 *
 * Copyright 2010 Przemyslaw Czerpak <druzus / at / priv.onet.pl>
 */

#require "hbnetio"

/* net:localhost:2941:topsecret:data/_tst_ */

#define DBSERVER  "localhost"
#define DBPORT    2941
#define DBPASSWD  "topsecret"
#define DBDIR     "data"
#define DBFILE    "_tst_"

#define DBNAME    "net:" + DBSERVER + ":" + hb_ntos( DBPORT ) + ":" + ;
      DBPASSWD + ":" + DBDIR + "/" + DBFILE

REQUEST DBFCDX

REQUEST hb_DirExists
REQUEST hb_DirCreate
REQUEST hb_DateTime

PROCEDURE Main()

   LOCAL pSockSrv, lExists, nStream1, nStream2, nSec, xData

   Set( _SET_EXCLUSIVE, .F. )
   rddSetDefault( "DBFCDX" )

   IF Empty( pSockSrv := netio_MTServer( DBPORT,,, /* RPC */ .T., DBPASSWD ) )
      ? "Cannot start NETIO server !!!"
      WAIT "Press any key to exit..."
      RETURN
   ENDIF

   ? "NETIO server activated."
   hb_idleSleep( 0.1 )
   WAIT

   ?
   ? "netio_Connect():", netio_Connect( DBSERVER, DBPORT, , DBPASSWD )
   ?

   netio_ProcExec( "QOut", "PROCEXEC", "P2", "P3", "P4" )
   netio_FuncExec( "QOut", "FUNCEXEC", "P2", "P3", "P4" )
   ? "SERVER TIME:", netio_FuncExec( "hb_dateTime" )
   ?
   WAIT

   nStream1 := netio_OpenItemStream( "reg_stream" )
   ? "netio_OpenItemStream():", nStream1
   nStream2 := netio_OpenDataStream( "reg_charstream" )
   ? "netio_OpenDataStream():", nStream2

   hb_idleSleep( 3 )
   ? "netio_GetData() 1:", hb_ValToExp( netio_GetData( nStream1 ) )
   ? "netio_GetData() 2:", hb_ValToExp( netio_GetData( nStream2 ) )
   nSec := Seconds() + 3
   DO WHILE Seconds() < nSec
      xData := netio_GetData( nStream1 )
      IF ! Empty( xData )
         ? hb_ValToExp( xData )
      ENDIF
      xData := netio_GetData( nStream2 )
      IF ! Empty( xData )
         ?? "", hb_ValToExp( xData )
      ENDIF
   ENDDO
   WAIT
   ? "netio_GetData() 1:", hb_ValToExp( netio_GetData( nStream1 ) )
   ? "netio_GetData() 2:", hb_ValToExp( netio_GetData( nStream2 ) )
   WAIT

   lExists := netio_FuncExec( "hb_DirExists", "./data" )
   ? "Directory './data'", iif( lExists, "exists", "not exists" )
   IF ! lExists
      ? "Creating directory './data' ->", ;
         iif( netio_FuncExec( "hb_DirCreate", "./data" ) == -1, "error", "OK" )
   ENDIF

   createdb( DBNAME )
   testdb( DBNAME )
   WAIT

   ?
   ? "table exists:", dbExists( DBNAME )
   WAIT

   ?
   ? "delete table with indexes:", dbDrop( DBNAME )
   ? "table exists:", dbExists( DBNAME )
   WAIT

   ? "netio_GetData() 1:", hb_ValToExp( netio_GetData( nStream1 ) )
   ? "netio_GetData() 2:", hb_ValToExp( netio_GetData( nStream2 ) )
   ? "netio_Disconnect():", netio_Disconnect( DBSERVER, DBPORT )
   ? "netio_CloseStream() 1:", netio_CloseStream( nStream1 )
   ? "netio_CloseStream() 2:", netio_CloseStream( nStream2 )
   hb_idleSleep( 2 )
   ?
   ? "stopping the server..."
   netio_ServerStop( pSockSrv, .T. )

   RETURN

PROCEDURE createdb( cName )  /* must be a public function */

   LOCAL n

   dbCreate( cName, { ;
      { "F1", "C", 20, 0 }, ;
      { "F2", "M",  4, 0 }, ;
      { "F3", "N", 10, 2 }, ;
      { "F4", "T",  8, 0 } } )
   ? "create NetErr():", NetErr(), hb_osError()
   USE ( cName )
   ? "use NetErr():", NetErr(), hb_osError()
   DO WHILE LastRec() < 100
      dbAppend()
      n := RecNo() - 1
      field->F1 := Chr( n % 26 + Asc( "A" ) ) + " " + Time()
      field->F2 := field->F1
      field->F3 := n / 100
      field->F4 := hb_DateTime()
   ENDDO
   INDEX ON field->F1 TAG T1
   INDEX ON field->F3 TAG T3
   INDEX ON field->F4 TAG T4
   dbCloseArea()
   ?

   RETURN

PROCEDURE testdb( cName )  /* must be a public function */

   LOCAL i, j

   USE ( cName )
   ? "Used():", Used()
   ? "NetErr():", NetErr()
   ? "Alias():", Alias()
   ? "LastRec():", LastRec()
   ? "ordCount():", ordCount()
   FOR i := 1 TO ordCount()
      ordSetFocus( i )
      ? i, "name:", ordName(), "key:", ordKey(), "keycount:", ordKeyCount()
   NEXT
   ordSetFocus( 1 )
   dbGoTop()
   DO WHILE ! Eof()
      IF ! field->F1 == field->F2
         ? "error at record:", RecNo()
         ? "  ! '" + field->F1 + "' == '" + field->F2 + "'"
      ENDIF
      dbSkip()
   ENDDO
   WAIT
   i := Row()
   j := Col()
   dbGoTop()
   Browse()
   SetPos( i, j )
   dbCloseArea()

   RETURN

FUNCTION reg_stream( pConnSock, nStream )  /* must be a public function */

   ? ProcName(), nStream
   hb_threadDetach( hb_threadStart( @rpc_timer(), pConnSock, nStream ) )

   RETURN nStream

FUNCTION reg_charstream( pConnSock, nStream )  /* must be a public function */

   ? ProcName(), nStream
   hb_threadDetach( hb_threadStart( @rpc_charstream(), pConnSock, nStream ) )

   RETURN nStream

STATIC FUNCTION rpc_timer( pConnSock, nStream )

   DO WHILE .T.
      IF ! netio_SrvSendItem( pConnSock, nStream, Time() )
         ? "CLOSED STREAM:", nStream
         EXIT
      ENDIF
      hb_idleSleep( 1 )
   ENDDO

   RETURN NIL

STATIC FUNCTION rpc_charstream( pConnSock, nStream )

   LOCAL n := 0

   DO WHILE .T.
      IF ! netio_SrvSendData( pConnSock, nStream, Chr( Asc( "A" ) + n ) )
         ? "CLOSED STREAM:", nStream
         EXIT
      ENDIF
      n := Int( ( n + 1 ) % 26 )
      hb_idleSleep( 0.1 )
   ENDDO

   RETURN NIL
