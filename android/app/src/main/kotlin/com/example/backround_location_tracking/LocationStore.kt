package com.example.backround_location_tracking

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.util.UUID

object LocationStore {
    private const val DB_NAME = "location_records.db"
    private const val TABLE = "locations"

    fun insert(
        context: Context,
        sessionId: String,
        latitude: Double,
        longitude: Double,
        accuracy: Float,
        timestamp: Long,
        id: String = UUID.randomUUID().toString(),
    ): String {
        val values = ContentValues().apply {
            put("id", id)
            put("sessionId", sessionId)
            put("latitude", latitude)
            put("longitude", longitude)
            put("accuracy", accuracy.toDouble())
            put("timestamp", timestamp)
        }
        db(context).insertWithOnConflict(TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE)
        return id
    }

    fun getBySession(context: Context, sessionId: String): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        val cursor = db(context).query(
            TABLE,
            null,
            "sessionId = ?",
            arrayOf(sessionId),
            null,
            null,
            "timestamp DESC",
        )
        cursor.use { c ->
            while (c.moveToNext()) {
                result.add(rowToMap(c))
            }
        }
        return result
    }

    fun countForSession(context: Context, sessionId: String): Int {
        val cursor = db(context).rawQuery(
            "SELECT COUNT(*) FROM $TABLE WHERE sessionId = ?",
            arrayOf(sessionId),
        )
        cursor.use { return if (it.moveToFirst()) it.getInt(0) else 0 }
    }

    fun countAll(context: Context): Int {
        val cursor = db(context).rawQuery("SELECT COUNT(*) FROM $TABLE", null)
        cursor.use { return if (it.moveToFirst()) it.getInt(0) else 0 }
    }

    private fun rowToMap(c: android.database.Cursor): Map<String, Any?> {
        return mapOf(
            "id" to c.getString(c.getColumnIndexOrThrow("id")),
            "sessionId" to c.getString(c.getColumnIndexOrThrow("sessionId")),
            "latitude" to c.getDouble(c.getColumnIndexOrThrow("latitude")),
            "longitude" to c.getDouble(c.getColumnIndexOrThrow("longitude")),
            "accuracy" to c.getDouble(c.getColumnIndexOrThrow("accuracy")),
            "timestamp" to c.getLong(c.getColumnIndexOrThrow("timestamp")),
        )
    }

    private fun db(context: Context): SQLiteDatabase {
        return StoreDatabase(context.applicationContext).writableDatabase
    }

    private class StoreDatabase(context: Context) :
        SQLiteOpenHelper(context, DB_NAME, null, 1) {

        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE $TABLE (
                    id TEXT PRIMARY KEY,
                    sessionId TEXT NOT NULL,
                    latitude REAL NOT NULL,
                    longitude REAL NOT NULL,
                    accuracy REAL NOT NULL,
                    timestamp INTEGER NOT NULL
                )
                """.trimIndent(),
            )
            db.execSQL("CREATE INDEX idx_session ON $TABLE (sessionId, timestamp)")
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            db.execSQL("DROP TABLE IF EXISTS $TABLE")
            onCreate(db)
        }
    }
}
