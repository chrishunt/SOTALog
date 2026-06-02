package com.sotalog.android.di

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.sotalog.android.data.local.database.converter.Converters
import com.sotalog.android.data.local.database.dao.CallsignHistoryDao
import com.sotalog.android.data.local.database.dao.CWMacroDao
import com.sotalog.android.data.local.database.dao.LogDao
import com.sotalog.android.data.local.database.dao.QSODao
import com.sotalog.android.data.local.database.dao.ReferenceDao
import com.sotalog.android.domain.models.CWMacro
import com.sotalog.android.domain.models.CallsignHistory
import com.sotalog.android.domain.models.Log
import com.sotalog.android.domain.models.POTAPark
import com.sotalog.android.domain.models.QSO
import com.sotalog.android.domain.models.ReferenceMetadata
import com.sotalog.android.domain.models.SOTASummit
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Database(
    entities = [
        Log::class,
        QSO::class,
        CallsignHistory::class,
        POTAPark::class,
        SOTASummit::class,
        ReferenceMetadata::class,
        CWMacro::class,
    ],
    version = 6,
    exportSchema = true,
)
@TypeConverters(Converters::class)
abstract class SOTALogDatabase : RoomDatabase() {
    abstract fun qsoDao(): QSODao
    abstract fun logDao(): LogDao
    abstract fun callsignHistoryDao(): CallsignHistoryDao
    abstract fun cwMacroDao(): CWMacroDao
    abstract fun referenceDao(): ReferenceDao
}

val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS `cwMacro` (
                `id` INTEGER PRIMARY KEY AUTOINCREMENT,
                `position` INTEGER NOT NULL,
                `label` TEXT NOT NULL,
                `template` TEXT NOT NULL
            )
            """.trimIndent()
        )
    }
}

val MIGRATION_2_3 = object : Migration(2, 3) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS `index_qso_callsign_band_date_timeOn`
            ON `qso` (`callsign`, `band`, `date`, `timeOn`)
            """.trimIndent()
        )
    }
}

val MIGRATION_3_4 = object : Migration(3, 4) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE INDEX IF NOT EXISTS `index_qso_qrzLogId`
            ON `qso` (`qrzLogId`)
            """.trimIndent()
        )
    }
}

val MIGRATION_4_5 = object : Migration(4, 5) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE INDEX IF NOT EXISTS `index_potaPark_latitude_longitude`
            ON `potaPark` (`latitude`, `longitude`)
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE INDEX IF NOT EXISTS `index_sotaSummit_latitude_longitude`
            ON `sotaSummit` (`latitude`, `longitude`)
            """.trimIndent()
        )
    }
}

// The worked count is now derived from the qso table on demand, so the cached
// (and historically drift-prone) counter column is removed. SQLite on minSdk 28
// predates ALTER TABLE DROP COLUMN, so rebuild the table the portable way.
val MIGRATION_5_6 = object : Migration(5, 6) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS `callsignHistory_new` (
                `callsign` TEXT NOT NULL,
                `name` TEXT,
                `qth` TEXT,
                `grid` TEXT,
                `lastWorked` INTEGER,
                PRIMARY KEY(`callsign`)
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            INSERT INTO `callsignHistory_new` (`callsign`, `name`, `qth`, `grid`, `lastWorked`)
            SELECT `callsign`, `name`, `qth`, `grid`, `lastWorked` FROM `callsignHistory`
            """.trimIndent()
        )
        db.execSQL("DROP TABLE `callsignHistory`")
        db.execSQL("ALTER TABLE `callsignHistory_new` RENAME TO `callsignHistory`")
    }
}

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): SOTALogDatabase =
        Room.databaseBuilder(context, SOTALogDatabase::class.java, "sotalog.db")
            .addMigrations(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5, MIGRATION_5_6)
            .build()

    @Provides
    fun provideQSODao(db: SOTALogDatabase): QSODao = db.qsoDao()

    @Provides
    fun provideLogDao(db: SOTALogDatabase): LogDao = db.logDao()

    @Provides
    fun provideCallsignHistoryDao(db: SOTALogDatabase): CallsignHistoryDao =
        db.callsignHistoryDao()

    @Provides
    fun provideCWMacroDao(db: SOTALogDatabase): CWMacroDao = db.cwMacroDao()

    @Provides
    fun provideReferenceDao(db: SOTALogDatabase): ReferenceDao = db.referenceDao()
}
