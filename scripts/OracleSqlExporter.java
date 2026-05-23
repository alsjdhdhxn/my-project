import java.io.BufferedWriter;
import java.io.IOException;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Clob;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

public class OracleSqlExporter {
    private record DbObject(String type, String name) {}
    private record TableExport(String name, long rows) {}

    public static void main(String[] args) throws Exception {
        if (args.length != 4) {
            System.err.println("Usage: java OracleSqlExporter <jdbcUrl> <username> <password> <outputDir>");
            System.exit(2);
        }

        String jdbcUrl = args[0];
        String username = args[1];
        String password = args[2];
        Path outputDir = Path.of(args[3]);
        Files.createDirectories(outputDir);

        try (Connection connection = DriverManager.getConnection(jdbcUrl, username, password)) {
            connection.setAutoCommit(false);
            configureMetadata(connection);

            List<TableExport> exportedTables = new ArrayList<>();
            writeObjects(connection, outputDir.resolve("00_schema_tables.sql"), "TABLE", listObjects(connection, "TABLE"));
            writeObjects(connection, outputDir.resolve("01_sequences.sql"), "SEQUENCE", listObjects(connection, "SEQUENCE"));
            writeObjects(connection, outputDir.resolve("02_views.sql"), "VIEW", listObjects(connection, "VIEW"));
            writeObjects(connection, outputDir.resolve("03_program_units.sql"), null, listProgramObjects(connection));
            writeObjects(connection, outputDir.resolve("04_triggers.sql"), "TRIGGER", listObjects(connection, "TRIGGER"));
            writeObjects(connection, outputDir.resolve("05_indexes.sql"), "INDEX", listIndexes(connection));
            writeData(connection, outputDir.resolve("10_data.sql"), exportedTables);
            writeManifest(connection, outputDir.resolve("manifest.md"), jdbcUrl, username, exportedTables);
        }
    }

    private static void configureMetadata(Connection connection) {
        try (Statement statement = connection.createStatement()) {
            statement.execute("BEGIN DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE',FALSE); END;");
            statement.execute("BEGIN DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SEGMENT_ATTRIBUTES',FALSE); END;");
            statement.execute("BEGIN DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',TRUE); END;");
            statement.execute("BEGIN DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',TRUE); END;");
        } catch (SQLException ignored) {
            System.err.println("WARN: DBMS_METADATA transform settings failed; continuing with defaults.");
        }
    }

    private static List<DbObject> listObjects(Connection connection, String type) throws SQLException {
        String sql = """
            SELECT OBJECT_TYPE, OBJECT_NAME
              FROM USER_OBJECTS
             WHERE OBJECT_TYPE = ?
               AND OBJECT_NAME NOT LIKE 'BIN$%'
             ORDER BY OBJECT_NAME
            """;
        List<DbObject> objects = new ArrayList<>();
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, type);
            try (ResultSet rs = statement.executeQuery()) {
                while (rs.next()) {
                    String objectType = rs.getString(1);
                    String objectName = rs.getString(2);
                    if ("SEQUENCE".equals(objectType) && objectName != null && objectName.startsWith("ISEQ$$_")) {
                        continue;
                    }
                    objects.add(new DbObject(objectType, objectName));
                }
            }
        }
        return objects;
    }

    private static List<DbObject> listProgramObjects(Connection connection) throws SQLException {
        String sql = """
            SELECT OBJECT_TYPE, OBJECT_NAME
              FROM USER_OBJECTS
             WHERE OBJECT_TYPE IN ('PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'FUNCTION')
               AND OBJECT_NAME NOT LIKE 'BIN$%'
             ORDER BY DECODE(OBJECT_TYPE, 'PACKAGE', 1, 'PACKAGE BODY', 2, 'PROCEDURE', 3, 'FUNCTION', 4, 9), OBJECT_NAME
            """;
        List<DbObject> objects = new ArrayList<>();
        try (PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet rs = statement.executeQuery()) {
            while (rs.next()) {
                String objectType = rs.getString(1);
                if ("PACKAGE BODY".equals(objectType)) {
                    objectType = "PACKAGE_BODY";
                }
                objects.add(new DbObject(objectType, rs.getString(2)));
            }
        }
        return objects;
    }

    private static List<DbObject> listIndexes(Connection connection) throws SQLException {
        String sql = """
            SELECT 'INDEX', INDEX_NAME
              FROM USER_INDEXES
             WHERE GENERATED = 'N'
               AND INDEX_NAME NOT LIKE 'BIN$%'
               AND INDEX_NAME NOT IN (SELECT CONSTRAINT_NAME FROM USER_CONSTRAINTS WHERE CONSTRAINT_NAME IS NOT NULL)
             ORDER BY INDEX_NAME
            """;
        List<DbObject> objects = new ArrayList<>();
        try (PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet rs = statement.executeQuery()) {
            while (rs.next()) {
                objects.add(new DbObject(rs.getString(1), rs.getString(2)));
            }
        }
        return objects;
    }

    private static void writeObjects(Connection connection, Path file, String fixedType, List<DbObject> objects)
            throws IOException, SQLException {
        try (BufferedWriter writer = Files.newBufferedWriter(file, StandardCharsets.UTF_8)) {
            writer.write("-- Generated by scripts/OracleSqlExporter.java at " + LocalDateTime.now());
            writer.newLine();
            writer.write("SET DEFINE OFF;");
            writer.newLine();
            writer.newLine();
            for (DbObject object : objects) {
                String type = fixedType == null ? object.type() : fixedType;
                writer.write("-- " + type + " " + object.name());
                writer.newLine();
                String ddl = getDdl(connection, type, object.name());
                writer.write(ddl == null || ddl.isBlank() ? "-- DDL unavailable" : ddl.stripTrailing());
                writer.newLine();
                writer.write("/");
                writer.newLine();
                writer.newLine();
            }
        }
        System.out.println("Wrote " + file + " (" + objects.size() + " objects)");
    }

    private static String getDdl(Connection connection, String type, String name) {
        String sql = "SELECT DBMS_METADATA.GET_DDL(?, ?) FROM DUAL";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, type);
            statement.setString(2, name);
            try (ResultSet rs = statement.executeQuery()) {
                if (rs.next()) {
                    Object value = rs.getObject(1);
                    if (value instanceof Clob clob) {
                        return clob.getSubString(1, Math.toIntExact(clob.length()));
                    }
                    return value == null ? null : value.toString();
                }
            }
        } catch (Exception ex) {
            return "-- Failed to export " + type + " " + name + ": " + ex.getMessage();
        }
        return null;
    }

    private static void writeData(Connection connection, Path file, List<TableExport> exportedTables)
            throws IOException, SQLException {
        List<String> tables = userTables(connection);
        try (BufferedWriter writer = Files.newBufferedWriter(file, StandardCharsets.UTF_8)) {
            writer.write("-- Generated data inserts at " + LocalDateTime.now());
            writer.newLine();
            writer.write("SET DEFINE OFF;");
            writer.newLine();
            writer.newLine();

            for (String table : tables) {
                long rowCount = exportTableData(connection, writer, table);
                exportedTables.add(new TableExport(table, rowCount));
                System.out.println("Exported data " + table + ": " + rowCount + " rows");
            }
            writer.write("COMMIT;");
            writer.newLine();
        }
    }

    private static List<String> userTables(Connection connection) throws SQLException {
        List<String> tables = new ArrayList<>();
        try (PreparedStatement statement = connection.prepareStatement(
                "SELECT TABLE_NAME FROM USER_TABLES WHERE TABLE_NAME NOT LIKE 'BIN$%' ORDER BY TABLE_NAME");
             ResultSet rs = statement.executeQuery()) {
            while (rs.next()) {
                tables.add(rs.getString(1));
            }
        }
        return tables;
    }

    private static long exportTableData(Connection connection, BufferedWriter writer, String table)
            throws SQLException, IOException {
        long rowCount = 0;
        String sql = "SELECT * FROM " + quoteIdent(table);
        try (Statement statement = connection.createStatement(ResultSet.TYPE_FORWARD_ONLY, ResultSet.CONCUR_READ_ONLY)) {
            statement.setFetchSize(200);
            try (ResultSet rs = statement.executeQuery(sql)) {
                ResultSetMetaData meta = rs.getMetaData();
                int columns = meta.getColumnCount();
                writer.write("-- Data for " + table);
                writer.newLine();
                while (rs.next()) {
                    writer.write("INSERT INTO " + quoteIdent(table) + " (");
                    for (int i = 1; i <= columns; i++) {
                        if (i > 1) writer.write(", ");
                        writer.write(quoteIdent(meta.getColumnName(i)));
                    }
                    writer.write(") VALUES (");
                    for (int i = 1; i <= columns; i++) {
                        if (i > 1) writer.write(", ");
                        writer.write(toSqlLiteral(rs, i, meta.getColumnType(i)));
                    }
                    writer.write(");");
                    writer.newLine();
                    rowCount++;
                }
                writer.newLine();
            }
        } catch (SQLException ex) {
            writer.write("-- Failed to export data for " + table + ": " + ex.getMessage());
            writer.newLine();
        }
        return rowCount;
    }

    private static String toSqlLiteral(ResultSet rs, int index, int sqlType) throws SQLException {
        Object value = rs.getObject(index);
        if (value == null) return "NULL";
        return switch (sqlType) {
            case Types.CHAR, Types.VARCHAR, Types.NCHAR, Types.NVARCHAR, Types.LONGVARCHAR, Types.LONGNVARCHAR ->
                    "'" + value.toString().replace("'", "''") + "'";
            case Types.DATE, Types.TIMESTAMP, Types.TIMESTAMP_WITH_TIMEZONE -> {
                Timestamp timestamp = rs.getTimestamp(index);
                yield timestamp == null ? "NULL" : "TO_TIMESTAMP('" + timestamp + "', 'YYYY-MM-DD HH24:MI:SS.FF')";
            }
            case Types.CLOB, Types.NCLOB -> clobLiteral(rs.getClob(index));
            case Types.BLOB, Types.BINARY, Types.VARBINARY, Types.LONGVARBINARY -> "NULL /* binary data skipped */";
            case Types.BIT, Types.BOOLEAN -> Boolean.TRUE.equals(value) ? "1" : "0";
            default -> {
                if (value instanceof BigDecimal || value instanceof Number) {
                    yield value.toString();
                }
                yield "'" + value.toString().replace("'", "''") + "'";
            }
        };
    }

    private static String clobLiteral(Clob clob) throws SQLException {
        if (clob == null) return "NULL";
        long length = clob.length();
        if (length == 0) return "EMPTY_CLOB()";
        String text = clob.getSubString(1, Math.toIntExact(Math.min(length, 32000)));
        String escaped = text.replace("'", "''");
        if (length > 32000) {
            escaped += "/* truncated from " + length + " chars */";
        }
        return "TO_CLOB('" + escaped + "')";
    }

    private static String quoteIdent(String name) {
        return "\"" + name.replace("\"", "\"\"") + "\"";
    }

    private static void writeManifest(Connection connection, Path file, String jdbcUrl, String username, List<TableExport> tables)
            throws IOException, SQLException {
        DatabaseMetaData meta = connection.getMetaData();
        try (BufferedWriter writer = Files.newBufferedWriter(file, StandardCharsets.UTF_8)) {
            writer.write("# Oracle SQL Export Manifest");
            writer.newLine();
            writer.newLine();
            writer.write("- Time: " + LocalDateTime.now());
            writer.newLine();
            writer.write("- URL: " + jdbcUrl);
            writer.newLine();
            writer.write("- User: " + username);
            writer.newLine();
            writer.write("- Database: " + meta.getDatabaseProductName() + " " + meta.getDatabaseProductVersion());
            writer.newLine();
            writer.newLine();
            writer.write("| Table | Rows |");
            writer.newLine();
            writer.write("| --- | ---: |");
            writer.newLine();
            for (TableExport table : tables) {
                writer.write("| `" + table.name() + "` | " + table.rows() + " |");
                writer.newLine();
            }
        }
    }
}
