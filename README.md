# TAuraODBC

Clase wrapper ODBC para Harbour — multiplataforma Windows/Linux.

Conecta a SQL Server desde Harbour sin depender de `hbwin`.
Basada en `libhbodbc`, el contrib oficial de Harbour.

---

## ¿Por qué existe esto?

En todos mis proyectos Harbour la conexión a SQL Server siempre ha sido
mediante ADO — `win_OleCreateObject("ADODB.Connection")` de `hbwin`. Funciona
bien pero es exclusivo de Windows.

Con el objetivo de migrar el servidor de aplicaciones a Linux necesitaba
una forma sencilla de conectarme a SQL Server desde Harbour sin reescribir
todo. `libhbodbc.a`, el contrib oficial de Harbour, ya expone todo lo
necesario a nivel C. Solo faltaba una clase con una API cómoda encima.
Eso es TAuraODBC.

---

## Características

- API orientada a objetos similar a ADO
- Parámetros seguros contra inyección SQL con parser de strings
- Transacciones: `BeginTransaction` / `Commit` / `Rollback`
- Múltiples resultsets con `MoreResults`
- Logging de errores configurable
- Compilación de una sola línea

---

## Compilación
```bash
hbmk2 mi_programa.prg auraodbc.prg -lhbodbc -lodbc
```

---

## Uso básico
```harbour
#include "trycatch.ch"

LOCAL oDb

oDb := TAuraODBC():New( ;
   "Driver={ODBC Driver 17 for SQL Server};" + ;
   "Server=TU_SERVIDOR\INSTANCIA;"           + ;
   "Database=MiBase;"                        + ;
   "Uid=TU_USUARIO;"                         + ;
   "Pwd=TU_PASSWORD;" )

IF ! oDb:Connect()
   ? "Error:", oDb:Error()
   RETURN
ENDIF

IF oDb:Execute( "SELECT sku, nombre, precio FROM productos WHERE categoria = ?", ;
                { "Filtros" } )
   DO WHILE oDb:Fetch()
      ? oDb:FieldByName( "sku" ), oDb:FieldByName( "nombre" ), oDb:FieldByName( "precio" )
   ENDDO
   oDb:Close()
ENDIF

oDb:Disconnect()
```

---

## API

### Conexión
```harbour
oDb := TAuraODBC():New( cConnStr )               // log en aura_odbc.log
oDb := TAuraODBC():New( cConnStr, cRutaLog )     // log en ruta personalizada

oDb:Connect()      // .T. si conectó
oDb:Disconnect()   // cierra conexión y libera handles
oDb:Error()        // mensaje del último error
```

### Consultas
```harbour
oDb:Execute( cSQL )                  // sin parámetros
oDb:Execute( cSQL, { p1, p2, ... } ) // con parámetros seguros
oDb:Fetch()                          // .T. mientras haya filas
oDb:Close()                          // libera el cursor — llamar siempre
```

### Lectura de campos
```harbour
oDb:FieldByName( "nombre" )   // por nombre de columna
oDb:FieldGet( 1 )             // por número (base 1)
oDb:FieldName( 1 )            // nombre de la columna n
oDb:FCount()                  // número de columnas
oDb:Eof()                     // .T. si no hay más filas
```

### Transacciones
```harbour
oDb:BeginTransaction()
oDb:Execute( "INSERT ...", { ... } ) : oDb:Close()
oDb:Execute( "UPDATE ...", { ... } ) : oDb:Close()
oDb:Commit()      // confirmar
oDb:Rollback()    // revertir
```

### Múltiples resultsets
```harbour
IF oDb:Execute( "EXEC miSP @param = ?", { cVal } )
   DO WHILE .T.
      DO WHILE oDb:Fetch()
         ? oDb:FieldByName( "columna" )
      ENDDO
      IF ! oDb:MoreResults()
         EXIT
      ENDIF
   ENDDO
ENDIF
oDb:Close()
```

---

## Tipos de parámetros

| Tipo Harbour | SQL generado |
|---|---|
| `NIL` | `NULL` |
| `"texto"` | `'texto'` (comillas internas escapadas) |
| `123` / `45.67` | `123` / `45.67` |
| `Date()` | `'YYYY-MM-DD'` |
| `.T.` / `.F.` | `1` / `0` |

---

## Limitación conocida — NULL en VARCHAR

`libhbodbc` no distingue entre `NULL` y cadena vacía en campos string.
Ambos llegan como `""`. Mismo comportamiento que la clase `TODBC` oficial.
```harbour
// Incorrecto
IF oDb:FieldByName( "categoria" ) == NIL ...

// Correcto
IF Empty( oDb:FieldByName( "categoria" ) ) ...
```

---

## Migración desde ADO

| ADO (solo Windows) | TAuraODBC (Windows + Linux) |
|---|---|
| `win_OleCreateObject("ADODB.Connection")` | `TAuraODBC():New( cConnStr )` |
| `oConn:Open()` | `oDb:Connect()` |
| `oConn:Close()` | `oDb:Disconnect()` |
| `ADODB.Command` + `Parameters:Append` | `oDb:Execute( cSQL, { params } )` |
| `oRs:Fields("campo"):Value` | `oDb:FieldByName("campo")` |
| `oRs:MoveNext()` | `oDb:Fetch()` |
| `oRs:EOF` | `oDb:Eof()` |
| `oRs:Close()` | `oDb:Close()` |
| `oConn:BeginTrans()` | `oDb:BeginTransaction()` |
| `oConn:CommitTrans()` | `oDb:Commit()` |
| `oConn:RollbackTrans()` | `oDb:Rollback()` |

---

## Revisión de código

La clase fue revisada independientemente por Claude (Anthropic) y Gemini Pro
(Google). Las mejoras incorporadas incluyen corrección de fuga de handles con
`SQLFreeStmt`, parser de strings en `Execute` para manejo correcto de `?` en
literales SQL, simplificación de `_Escape` y sistema de logging configurable.

---

## Estructura del repositorio
```
harbour-auraodbc/
├── auraodbc.prg       # La clase
├── trycatch.ch        # Macros TRY/CATCH
├── test_completo.prg  # Suite de pruebas
├── setup.sql          # Base de datos demo + SPs
├── README.md
└── INSTALL.md         # Instalación del driver ODBC en Ubuntu 24.04
```