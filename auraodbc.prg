/*
 * TAuraODBC.prg
 * Clase wrapper ODBC para Harbour - multiplataforma Windows/Linux
 * Basada en libhbodbc (contrib oficial de Harbour)
 *
 * LIMITACION CONOCIDA:
 * Los campos VARCHAR/CHAR con valor NULL llegan como "" (cadena vacia)
 * debido a una limitacion de libhbodbc. Este es el mismo comportamiento
 * de la clase TODBC oficial de Harbour. Para verificar ausencia de valor
 * en campos string usar Empty() en lugar de == NIL.
 */

#include "hbclass.ch"

// Constantes ODBC
#define SQL_SUCCESS           0
#define SQL_SUCCESS_WITH_INFO 1
#define SQL_NO_DATA           100
#define SQL_ERROR            -2

// Tipos de datos ODBC
#define SQL_CHAR             1
#define SQL_NUMERIC          2
#define SQL_DECIMAL          3
#define SQL_INTEGER          4
#define SQL_SMALLINT         5
#define SQL_FLOAT            6
#define SQL_REAL             7
#define SQL_DOUBLE           8
#define SQL_DATE             9
#define SQL_TIME             10
#define SQL_TIMESTAMP        11
#define SQL_VARCHAR          12
#define SQL_BIGINT          -5
#define SQL_TINYINT         -6
#define SQL_BIT             -7
#define SQL_WCHAR           -8
#define SQL_WVARCHAR        -9
#define SQL_WLONGVARCHAR    -10
#define SQL_BINARY          -2
#define SQL_VARBINARY       -3
#define SQL_LONGVARBINARY   -4
#define SQL_LONGVARCHAR     -1
#define SQL_TYPE_DATE       91
#define SQL_TYPE_TIME       92
#define SQL_TYPE_TIMESTAMP  93
#define SQL_HANDLE_STMT      3

CREATE CLASS TAuraODBC

   VAR hEnv        INIT NIL
   VAR hDbc        INIT NIL
   VAR hStmt       INIT NIL
   VAR aFields     INIT {}
   VAR nFields     INIT 0
   VAR lConnected  INIT .F.
   VAR lEof        INIT .T.
   VAR cError      INIT ""
   VAR cConnStr    INIT ""
   VAR aRow        INIT {}
   VAR cLogFile    INIT "aura_odbc.log"

   METHOD New( cConnectionString )
   METHOD Destroy()
   METHOD Connect()
   METHOD Disconnect()
   METHOD Execute( cSQL, aParams )
   METHOD Fetch()
   METHOD Close()
   METHOD MoreResults()
   METHOD FieldByName( cName )
   METHOD FieldGet( nCol )
   METHOD FieldName( nCol )
   METHOD Eof()             INLINE ::lEof
   METHOD Error()           INLINE ::cError
   METHOD FCount()          INLINE ::nFields
   METHOD BeginTransaction()
   METHOD Commit()
   METHOD Rollback()
   METHOD _LoadMetadata()
   METHOD _GetFieldValue( nCol )
   METHOD _SqlError()
   METHOD _Escape( xVal )
   METHOD _Log( cText )

END CLASS

METHOD New( cConnectionString, cLogPath ) CLASS TAuraODBC
   ::cConnStr := cConnectionString
   IF HB_ISSTRING( cLogPath ) .AND. ! Empty( cLogPath )
      ::cLogFile := cLogPath
   ENDIF
RETURN Self

METHOD Connect() CLASS TAuraODBC

   LOCAL nRet

   nRet := SQLAllocEnv( @::hEnv )
   IF ! _OdbcOk( nRet )
      ::cError := "No se pudo crear el environment ODBC"
      ::_Log( "CONNECT_ERROR: " + ::cError )
      RETURN .F.
   ENDIF

   nRet := SQLAllocConnect( ::hEnv, @::hDbc )
   IF ! _OdbcOk( nRet )
      ::cError := "No se pudo crear el handle de conexion"
      ::_Log( "CONNECT_ERROR: " + ::cError )
      RETURN .F.
   ENDIF

   nRet := SQLDriverConnect( ::hDbc, ::cConnStr, @::cConnStr )
   IF ! _OdbcOk( nRet )
      ::cError := "Error al conectar con el servidor"
      // No se loguea la ConnStr para evitar exponer credenciales
      ::_Log( "CONNECT_ERROR: " + ::cError )
      RETURN .F.
   ENDIF

   ::lConnected := .T.

RETURN .T.

METHOD Disconnect() CLASS TAuraODBC
   ::Close()
   IF ::lConnected
      SQLDisconnect( ::hDbc )
      ::lConnected := .F.
   ENDIF
   ::hDbc := NIL
   ::hEnv := NIL
RETURN NIL

METHOD Destroy() CLASS TAuraODBC
   ::Disconnect()
RETURN NIL

METHOD Execute( cSQL, aParams ) CLASS TAuraODBC

   LOCAL nRet, i, cSQLFinal, nParamIdx, lInString, cChar, cNext

   ::Close()

   nRet := SQLAllocStmt( ::hDbc, @::hStmt )
   IF ! _OdbcOk( nRet )
      ::cError := "No se pudo allocar statement"
      ::_Log( "EXECUTE_ERROR: " + ::cError )
      RETURN .F.
   ENDIF

   cSQLFinal := ""
   nParamIdx := 1
   lInString := .F.
   i         := 1

   IF HB_ISARRAY( aParams ) .AND. Len( aParams ) > 0
      DO WHILE i <= Len( cSQL )
         cChar := SubStr( cSQL, i, 1 )
         cNext := SubStr( cSQL, i + 1, 1 )
         IF cChar == "'"
            IF lInString .AND. cNext == "'"
               cSQLFinal += "''"
               i += 2
               LOOP
            ELSE
               lInString := ! lInString
               cSQLFinal += cChar
            ENDIF
         ELSEIF cChar == "?" .AND. ! lInString
            IF nParamIdx <= Len( aParams )
               cSQLFinal += ::_Escape( aParams[ nParamIdx ] )
               nParamIdx++
            ELSE
               cSQLFinal += "?"
            ENDIF
         ELSE
            cSQLFinal += cChar
         ENDIF
         i++
      ENDDO
   ELSE
      cSQLFinal := cSQL
   ENDIF

   nRet := SQLPrepare( ::hStmt, cSQLFinal )
   IF ! _OdbcOk( nRet )
      ::cError := ::_SqlError()
      ::_Log( "SQL_PREPARE_ERROR: " + ::cError + " | SQL: " + cSQLFinal )
      RETURN .F.
   ENDIF

   nRet := SQLExecute( ::hStmt )
   IF ! _OdbcOk( nRet )
      ::cError := ::_SqlError()
      ::_Log( "SQL_EXECUTE_ERROR: " + ::cError + " | SQL: " + cSQLFinal )
      RETURN .F.
   ENDIF

   ::_LoadMetadata()
   ::lEof := ( ::nFields == 0 )

RETURN .T.

METHOD Fetch() CLASS TAuraODBC

   LOCAL nRet, i, xVal

   IF ::hStmt == NIL
      RETURN .F.
   ENDIF

   nRet := SQLFetch( ::hStmt )

   IF nRet == SQL_NO_DATA .OR. ! _OdbcOk( nRet )
      ::lEof := .T.
      RETURN .F.
   ENDIF

   ::aRow := {}
   FOR i := 1 TO ::nFields
      xVal := NIL
      SQLGetData( ::hStmt, i, ::aFields[ i ][ 2 ], NIL, @xVal )
      IF ::aFields[ i ][ 2 ] == 2 .OR. ::aFields[ i ][ 2 ] == 3 .OR. ;
         ::aFields[ i ][ 2 ] == 6 .OR. ::aFields[ i ][ 2 ] == 7 .OR. ;
         ::aFields[ i ][ 2 ] == 8 .OR. ::aFields[ i ][ 2 ] == 5 .OR. ;
         ::aFields[ i ][ 2 ] == 4 .OR. ::aFields[ i ][ 2 ] == -5 .OR. ;
         ::aFields[ i ][ 2 ] == -6
         xVal := hb_odbcNumSetLen( xVal, ::aFields[ i ][ 3 ], ::aFields[ i ][ 4 ] )
      ENDIF
      AAdd( ::aRow, xVal )
   NEXT

   ::lEof := .F.

RETURN .T.

METHOD Close() CLASS TAuraODBC
   IF ::hStmt != NIL
      SQLFreeStmt( ::hStmt, 1 )
   ENDIF
   ::lEof    := .T.
   ::aFields := {}
   ::nFields := 0
   ::hStmt   := NIL
RETURN NIL

METHOD MoreResults() CLASS TAuraODBC

   LOCAL nRet

   IF ::hStmt == NIL
      RETURN .F.
   ENDIF

   nRet := SQLMoreResults( ::hStmt )

   IF nRet == SQL_NO_DATA .OR. ! _OdbcOk( nRet )
      RETURN .F.
   ENDIF

   ::_LoadMetadata()
   ::lEof := .F.

RETURN .T.

METHOD FieldByName( cName ) CLASS TAuraODBC

   LOCAL i
   cName := Upper( cName )
   FOR i := 1 TO ::nFields
      IF Upper( ::aFields[ i ][ 1 ] ) == cName
         RETURN ::_GetFieldValue( i )
      ENDIF
   NEXT

RETURN NIL

METHOD FieldGet( nCol ) CLASS TAuraODBC
   IF nCol >= 1 .AND. nCol <= ::nFields
      RETURN ::_GetFieldValue( nCol )
   ENDIF
RETURN NIL

METHOD FieldName( nCol ) CLASS TAuraODBC
   IF nCol >= 1 .AND. nCol <= ::nFields
      RETURN ::aFields[ nCol ][ 1 ]
   ENDIF
RETURN ""

METHOD _LoadMetadata() CLASS TAuraODBC

   LOCAL nCols := 0, i
   LOCAL cName := "", nType := 0, nSize := 0, nDec := 0

   ::aFields := {}
   ::nFields  := 0

   SQLNumResultCols( ::hStmt, @nCols )

   FOR i := 1 TO nCols
      SQLDescribeCol( ::hStmt, i, @cName, 128, NIL, @nType, @nSize, @nDec, NIL )
      AAdd( ::aFields, { cName, nType, nSize, nDec } )
   NEXT

   ::nFields := nCols

RETURN NIL

METHOD _GetFieldValue( nCol ) CLASS TAuraODBC
   IF nCol >= 1 .AND. nCol <= Len( ::aRow )
      RETURN ::aRow[ nCol ]
   ENDIF
RETURN NIL

METHOD _SqlError() CLASS TAuraODBC

   LOCAL cState := "", nErr := 0, cMsg := ""
   SQLGetDiagRec( SQL_HANDLE_STMT, ::hStmt, 1, @cState, @nErr, @cMsg )

RETURN "[" + cState + "] " + cMsg

METHOD _Escape( xVal ) CLASS TAuraODBC

   LOCAL cStrVal

   DO CASE
   CASE xVal == NIL
      RETURN "NULL"
   CASE HB_ISSTRING( xVal )
      cStrVal := StrTran( xVal, "'", "''" )
      RETURN "'" + cStrVal + "'"
   CASE HB_ISNUMERIC( xVal )
      RETURN hb_ntos( xVal )
   CASE HB_ISDATE( xVal )
      RETURN "'" + hb_DToC( xVal, "YYYY-MM-DD" ) + "'"
   CASE HB_ISLOGICAL( xVal )
      RETURN iif( xVal, "1", "0" )
   ENDCASE

RETURN "NULL"

METHOD BeginTransaction() CLASS TAuraODBC
   SQLSetConnectAttr( ::hDbc, 102, 0 )
RETURN NIL

METHOD Commit() CLASS TAuraODBC
   SQLCommit( ::hEnv, ::hDbc )
   SQLSetConnectAttr( ::hDbc, 102, 1 )
RETURN NIL

METHOD Rollback() CLASS TAuraODBC
   SQLRollback( ::hEnv, ::hDbc )
   SQLSetConnectAttr( ::hDbc, 102, 1 )
RETURN NIL

METHOD _Log( cText ) CLASS TAuraODBC

   LOCAL nHandle
   LOCAL cMsg := "[" + hb_DToC( Date(), "YYYY-MM-DD" ) + " " + Time() + "] " + cText + hb_eol()

   nHandle := FOpen( ::cLogFile, 17 )
   IF nHandle == -1
      nHandle := FCreate( ::cLogFile )
   ENDIF

   IF nHandle != -1
      FSeek( nHandle, 0, 2 )
      FWrite( nHandle, cMsg )
      FClose( nHandle )
   ENDIF

RETURN NIL

STATIC FUNCTION _OdbcOk( nRet )
RETURN ( nRet == SQL_SUCCESS .OR. nRet == SQL_SUCCESS_WITH_INFO )