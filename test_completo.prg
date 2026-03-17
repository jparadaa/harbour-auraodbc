/*
 * test_completo.prg
 * Suite de pruebas para TAuraODBC
 *
 * Compilacion:
 *   hbmk2 test_completo.prg auraodbc.prg -lhbodbc -lodbc
 *
 * Ejecucion:
 *   ./test_completo
 */

#include "trycatch.ch"

#define CONN_STR "Driver={ODBC Driver 17 for SQL Server};" + ;
                 "Server=TU_SERVIDOR\INSTANCIA;"           + ;
                 "Database=TAuraODBCDemo;"                 + ;
                 "Uid=TU_USUARIO;"                         + ;
                 "Pwd=TU_PASSWORD;"

REQUEST HB_CODEPAGE_UTF8
REQUEST HB_LANG_ES

// ============================================================
PROCEDURE Main()
// ============================================================

   LOCAL oDb
   LOCAL nOk := 0, nFail := 0
   hb_cdpSelect("UTF8")
   hb_LangSelect('ES')

   ? ""
   ? "============================================"
   ? " TAuraODBC — Suite de pruebas completa"
   ? "============================================"
   ? ""

   oDb := TAuraODBC():New( CONN_STR, "test_odbc.log" )

   IF ! oDb:Connect()
      ? "FATAL: No se pudo conectar —", oDb:Error()
      RETURN
   ENDIF

   ? "Conexion establecida OK"
   ? ""

   // --- Ejecutar pruebas ---
   T01_SelectSinParams(     oDb, @nOk, @nFail )
   T02_SelectConParams(     oDb, @nOk, @nFail )
   T03_Insert(              oDb, @nOk, @nFail )
   T04_Update(              oDb, @nOk, @nFail )
   T05_Delete(              oDb, @nOk, @nFail )
   T06_TransaccionCommit(   oDb, @nOk, @nFail )
   T07_TransaccionRollback( oDb, @nOk, @nFail )
   T08_SPSimple(            oDb, @nOk, @nFail )
   T09_SPMultiResultset(    oDb, @nOk, @nFail )
   T10_EstresSelect(        oDb, @nOk, @nFail )
   T11_EstresInsert(        oDb, @nOk, @nFail )
   T12_InyeccionSQL(        oDb, @nOk, @nFail )

   // --- Resumen ---
   ? ""
   ? "============================================"
   ? " RESULTADO FINAL"
   ? "  OK  :", nOk
   ? "  FAIL:", nFail
   ? "============================================"
   ? ""

   oDb:Disconnect()

RETURN

// ============================================================
STATIC PROCEDURE Resultado( cNombre, lOk, nOk, nFail, cDetalle )
// ============================================================
   LOCAL cEstado := iif( lOk, "  [OK]  ", " [FAIL] " )
   LOCAL cExtra  := iif( HB_ISSTRING( cDetalle ) .AND. ! Empty( cDetalle ), " — " + cDetalle, "" )
   ? cEstado + cNombre + cExtra
   IF lOk
      nOk++
   ELSE
      nFail++
   ENDIF
RETURN

// ============================================================
STATIC PROCEDURE T01_SelectSinParams( oDb, nOk, nFail )
// ============================================================
   LOCAL nCount := 0

   ? ""
   ? "[ T01 ] SELECT sin parametros"

   IF oDb:Execute( "SELECT id, sku, nombre, precio FROM dbo.productos ORDER BY id" )
      DO WHILE oDb:Fetch()
         nCount++
      ENDDO
      oDb:Close()
      Resultado( "SELECT devuelve filas", nCount > 0, @nOk, @nFail, hb_ntos( nCount ) + " filas" )
   ELSE
      Resultado( "SELECT sin parametros", .F., @nOk, @nFail, oDb:Error() )
   ENDIF

RETURN

// ============================================================
STATIC PROCEDURE T02_SelectConParams( oDb, nOk, nFail )
// ============================================================
   LOCAL cSku := "", nPrecio := 0, lEncontrado := .F.

   ? ""
   ? "[ T02 ] SELECT con parametros"

   IF oDb:Execute( "SELECT sku, nombre, precio FROM dbo.productos WHERE categoria = ? AND activo = ?", ;
                   { "Filtros", 1 } )
      DO WHILE oDb:Fetch()
         cSku        := AllTrim( oDb:FieldByName( "sku" ) )
         nPrecio     := oDb:FieldByName( "precio" )
         lEncontrado := .T.
      ENDDO
      oDb:Close()
      Resultado( "SELECT categoria='Filtros'", lEncontrado, @nOk, @nFail, "ultimo sku: " + cSku )
   ELSE
      Resultado( "SELECT con parametros", .F., @nOk, @nFail, oDb:Error() )
   ENDIF

   IF oDb:Execute( "SELECT COUNT(*) AS total FROM dbo.productos WHERE fecha_alta >= ?", ;
                   { CToD( "01/01/2025" ) } )
      oDb:Fetch()
      Resultado( "SELECT con parametro DATE", .T., @nOk, @nFail, ;
                 "total desde 2025: " + hb_ntos( oDb:FieldByName( "total" ) ) )
      oDb:Close()
   ELSE
      Resultado( "SELECT con parametro DATE", .F., @nOk, @nFail, oDb:Error() )
   ENDIF

RETURN

// ============================================================
STATIC PROCEDURE T03_Insert( oDb, nOk, nFail )
// ============================================================
   LOCAL lOk

   ? ""
   ? "[ T03 ] INSERT con parametros"

   lOk := oDb:Execute( ;
      "INSERT INTO dbo.productos (sku, nombre, categoria, precio, existencia, activo, fecha_alta, notas) " + ;
      "VALUES (?, ?, ?, ?, ?, ?, ?, ?)", ;
      { "TEST-INS-001", "Producto Test INSERT", "Test", 99.99, 10, 1, Date(), "Insertado por test_completo" } )

   oDb:Close()
   Resultado( "INSERT registro de prueba", lOk, @nOk, @nFail, iif( ! lOk, oDb:Error(), "" ) )

RETURN

// ============================================================
STATIC PROCEDURE T04_Update( oDb, nOk, nFail )
// ============================================================
   LOCAL lOk

   ? ""
   ? "[ T04 ] UPDATE con parametros"

   lOk := oDb:Execute( ;
      "UPDATE dbo.productos SET precio = ?, notas = ? WHERE sku = ?", ;
      { 111.11, "Precio actualizado por test_completo", "TEST-INS-001" } )

   oDb:Close()
   Resultado( "UPDATE por sku", lOk, @nOk, @nFail, iif( ! lOk, oDb:Error(), "" ) )

   IF oDb:Execute( "SELECT precio FROM dbo.productos WHERE sku = ?", { "TEST-INS-001" } )
      IF oDb:Fetch()
         Resultado( "Verificacion UPDATE precio", oDb:FieldByName( "precio" ) == 111.11, ;
                    @nOk, @nFail, "precio=" + hb_ntos( oDb:FieldByName( "precio" ) ) )
      ENDIF
      oDb:Close()
   ENDIF

RETURN

// ============================================================
STATIC PROCEDURE T05_Delete( oDb, nOk, nFail )
// ============================================================
   LOCAL lOk

   ? ""
   ? "[ T05 ] DELETE con parametros"

   lOk := oDb:Execute( ;
      "DELETE FROM dbo.productos WHERE sku = ?", ;
      { "TEST-INS-001" } )

   oDb:Close()
   Resultado( "DELETE por sku", lOk, @nOk, @nFail, iif( ! lOk, oDb:Error(), "" ) )

RETURN

// ============================================================
STATIC PROCEDURE T06_TransaccionCommit( oDb, nOk, nFail )
// ============================================================
   LOCAL lOk := .T., nTotal := 0

   ? ""
   ? "[ T06 ] Transaccion COMMIT"

   oDb:BeginTransaction()

   IF ! oDb:Execute( ;
      "INSERT INTO dbo.productos (sku, nombre, categoria, precio, existencia, activo, fecha_alta) " + ;
      "VALUES (?, ?, ?, ?, ?, ?, ?)", ;
      { "TEST-TXC-001", "Producto TX Commit A", "Test", 10.00, 1, 1, Date() } )
      lOk := .F.
   ENDIF
   oDb:Close()

   IF ! oDb:Execute( ;
      "INSERT INTO dbo.productos (sku, nombre, categoria, precio, existencia, activo, fecha_alta) " + ;
      "VALUES (?, ?, ?, ?, ?, ?, ?)", ;
      { "TEST-TXC-002", "Producto TX Commit B", "Test", 20.00, 2, 1, Date() } )
      lOk := .F.
   ENDIF
   oDb:Close()

   IF lOk
      oDb:Commit()
   ELSE
      oDb:Rollback()
   ENDIF

   Resultado( "INSERT x2 + COMMIT", lOk, @nOk, @nFail )

   IF oDb:Execute( "SELECT COUNT(*) AS total FROM dbo.productos WHERE sku IN (?,?)", ;
                   { "TEST-TXC-001", "TEST-TXC-002" } )
      oDb:Fetch()
      nTotal := oDb:FieldByName( "total" )
      oDb:Close()
      Resultado( "Verificacion COMMIT persistio", nTotal == 2, @nOk, @nFail, ;
                 hb_ntos( nTotal ) + "/2 registros encontrados" )
   ENDIF

   oDb:Execute( "DELETE FROM dbo.productos WHERE sku IN (?,?)", { "TEST-TXC-001", "TEST-TXC-002" } )
   oDb:Close()

RETURN

// ============================================================
STATIC PROCEDURE T07_TransaccionRollback( oDb, nOk, nFail )
// ============================================================
   LOCAL nTotal := 0

   ? ""
   ? "[ T07 ] Transaccion ROLLBACK"

   oDb:BeginTransaction()

   oDb:Execute( ;
      "INSERT INTO dbo.productos (sku, nombre, categoria, precio, existencia, activo, fecha_alta) " + ;
      "VALUES (?, ?, ?, ?, ?, ?, ?)", ;
      { "TEST-TXR-001", "Producto TX Rollback", "Test", 50.00, 5, 1, Date() } )
   oDb:Close()

   oDb:Rollback()

   IF oDb:Execute( "SELECT COUNT(*) AS total FROM dbo.productos WHERE sku = ?", { "TEST-TXR-001" } )
      oDb:Fetch()
      nTotal := oDb:FieldByName( "total" )
      oDb:Close()
      Resultado( "ROLLBACK deshizo el INSERT", nTotal == 0, @nOk, @nFail, ;
                 hb_ntos( nTotal ) + " registros (esperado 0)" )
   ENDIF

RETURN

// ============================================================
STATIC PROCEDURE T08_SPSimple( oDb, nOk, nFail )
// ============================================================
   LOCAL nCount := 0

   ? ""
   ? "[ T08 ] Stored Procedure simple"

   IF oDb:Execute( "EXEC dbo.sp_ProductosPorCategoria @Categoria = ?, @SoloActivos = ?", ;
                   { "Aceites Motor", 1 } )
      DO WHILE oDb:Fetch()
         nCount++
      ENDDO
      oDb:Close()
      Resultado( "SP sp_ProductosPorCategoria", nCount > 0, @nOk, @nFail, ;
                 hb_ntos( nCount ) + " productos devueltos" )
   ELSE
      Resultado( "SP sp_ProductosPorCategoria", .F., @nOk, @nFail, oDb:Error() )
   ENDIF

   nCount := 0
   IF oDb:Execute( "EXEC dbo.sp_ProductosPorCategoria @Categoria = ?, @SoloActivos = ?", ;
                   { NIL, 1 } )
      DO WHILE oDb:Fetch()
         nCount++
      ENDDO
      oDb:Close()
      Resultado( "SP con parametro NULL (todas categorias)", nCount > 0, @nOk, @nFail, ;
                 hb_ntos( nCount ) + " productos" )
   ELSE
      Resultado( "SP parametro NULL", .F., @nOk, @nFail, oDb:Error() )
   ENDIF

RETURN

// ============================================================
STATIC PROCEDURE T09_SPMultiResultset( oDb, nOk, nFail )
// ============================================================
   LOCAL nRS := 0, nFilas := 0, aConteos := {}

   ? ""
   ? "[ T09 ] SP con multiples resultsets (MoreResults)"

   IF oDb:Execute( "EXEC dbo.sp_ResumenEjecutivo @SoloActivos = ?", { 1 } )

      DO WHILE .T.
         nRS++
         nFilas := 0
         DO WHILE oDb:Fetch()
            nFilas++
         ENDDO
         AAdd( aConteos, nFilas )
         IF ! oDb:MoreResults()
            EXIT
         ENDIF
      ENDDO

      oDb:Close()

      Resultado( "sp_ResumenEjecutivo devuelve 3 resultsets", nRS == 3, @nOk, @nFail, ;
                 hb_ntos( nRS ) + " resultsets" )
      Resultado( "RS1 — categorias (filas > 0)", aConteos[ 1 ] > 0, @nOk, @nFail, ;
                 hb_ntos( aConteos[ 1 ] ) + " categorias" )
      Resultado( "RS2 — top 5 precios (5 filas)", aConteos[ 2 ] == 5, @nOk, @nFail, ;
                 hb_ntos( aConteos[ 2 ] ) + " filas" )
      Resultado( "RS3 — sin categoria (filas >= 0)", aConteos[ 3 ] >= 0, @nOk, @nFail, ;
                 hb_ntos( aConteos[ 3 ] ) + " filas" )
   ELSE
      Resultado( "sp_ResumenEjecutivo", .F., @nOk, @nFail, oDb:Error() )
   ENDIF

RETURN

// ============================================================
STATIC PROCEDURE T10_EstresSelect( oDb, nOk, nFail )
// ============================================================
   LOCAL i, nInicio, nFin, nMs, lOk := .T.

   ? ""
   ? "[ T10 ] Estres: 1000 SELECTs consecutivos"

   nInicio := hb_MilliSeconds()

   FOR i := 1 TO 1000
      IF ! oDb:Execute( "SELECT id, sku, precio FROM dbo.productos WHERE id = ?", { ( i % 15 ) + 1 } )
         lOk := .F.
         EXIT
      ENDIF
      oDb:Fetch()
      oDb:Close()
   NEXT

   nFin := hb_MilliSeconds()
   nMs  := nFin - nInicio

   Resultado( "1000 SELECTs sin error", lOk, @nOk, @nFail, ;
              hb_ntos( nMs ) + "ms totales / " + ;
              hb_ntos( Int( nMs / 1000 * 10 ) / 10 ) + "ms promedio" )

RETURN

// ============================================================
STATIC PROCEDURE T11_EstresInsert( oDb, nOk, nFail )
// ============================================================
   LOCAL i, nInicio, nFin, nMs, lOk := .T.

   ? ""
   ? "[ T11 ] Estres: 500 INSERTs en transaccion"

   nInicio := hb_MilliSeconds()
   oDb:BeginTransaction()

   FOR i := 1 TO 500
      IF ! oDb:Execute( ;
         "INSERT INTO dbo.productos (sku, nombre, categoria, precio, existencia, activo, fecha_alta) " + ;
         "VALUES (?, ?, ?, ?, ?, ?, ?)", ;
         { "STRESS-" + hb_ntos( i ), "Producto Estres " + hb_ntos( i ), ;
           "Test", i * 1.5, i, 1, Date() } )
         lOk := .F.
         EXIT
      ENDIF
      oDb:Close()
   NEXT

   IF lOk
      oDb:Commit()
   ELSE
      oDb:Rollback()
   ENDIF

   nFin := hb_MilliSeconds()
   nMs  := nFin - nInicio

   Resultado( "500 INSERTs en TX sin error", lOk, @nOk, @nFail, ;
              hb_ntos( nMs ) + "ms totales / " + ;
              hb_ntos( Int( nMs / 500 * 10 ) / 10 ) + "ms por INSERT" )

   oDb:Execute( "DELETE FROM dbo.productos WHERE categoria = 'Test'" )
   oDb:Close()

RETURN

// ============================================================
STATIC PROCEDURE T12_InyeccionSQL( oDb, nOk, nFail )
// ============================================================
   LOCAL aAtaques, aLegitimos, i, lOk, nCount

   ? ""
   ? "[ T12 ] Proteccion contra inyeccion SQL"

   aAtaques := { ;
      "' OR '1'='1",                                                      ;
      "'; DROP TABLE productos; --",                                       ;
      "' UNION SELECT * FROM productos",                                   ;
      "'; EXEC xp_cmdshell('dir') --",                                     ;
      "' OR 1=1 --",                                                       ;
      "admin'--",                                                          ;
      "' OR 'x'='x",                                                       ;
      "'; INSERT INTO productos VALUES ('X','X','X',0,0,0,GETDATE()) --"  ;
   }

   FOR i := 1 TO Len( aAtaques )
      lOk := .F.
      IF oDb:Execute( "SELECT COUNT(*) AS total FROM dbo.productos WHERE nombre = ?", ;
                      { aAtaques[ i ] } )
         IF oDb:Fetch()
            nCount := oDb:FieldByName( "total" )
            lOk    := ( nCount == 0 )
         ENDIF
         oDb:Close()
      ELSE
         lOk := .T.
      ENDIF
      Resultado( "Ataque " + hb_ntos( i ) + " neutralizado", lOk, @nOk, @nFail, ;
                 Left( aAtaques[ i ], 35 ) )
   NEXT

   aLegitimos := { ;
      "TICKET UPDATE PENDIENTE", ;
      "DROP COLA DE IMPRESION",  ;
      "CREATE EVENTO ESPECIAL"   ;
   }

   FOR i := 1 TO Len( aLegitimos )
      lOk := oDb:Execute( "SELECT COUNT(*) AS total FROM dbo.productos WHERE nombre = ?", ;
                          { aLegitimos[ i ] } )
      IF lOk
         oDb:Fetch()
         oDb:Close()
      ENDIF
      Resultado( "Texto legitimo con keyword SQL pasa OK", lOk, @nOk, @nFail, aLegitimos[ i ] )
   NEXT

RETURN