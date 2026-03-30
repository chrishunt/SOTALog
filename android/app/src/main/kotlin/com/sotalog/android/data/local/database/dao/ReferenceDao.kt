package com.sotalog.android.data.local.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.sotalog.android.domain.models.POTAPark
import com.sotalog.android.domain.models.ReferenceMetadata
import com.sotalog.android.domain.models.SOTASummit

@Dao
interface ReferenceDao {

    // SOTA Summits

    @Query("SELECT * FROM sotaSummit WHERE code = :code")
    suspend fun getSummitByCode(code: String): SOTASummit?

    @Query("SELECT * FROM sotaSummit WHERE codeNormalized LIKE :prefix || '%' ORDER BY code ASC LIMIT :limit")
    suspend fun searchSummitsByNormalizedPrefix(prefix: String, limit: Int = 20): List<SOTASummit>

    @Query("SELECT * FROM sotaSummit WHERE name LIKE '%' || :query || '%' ORDER BY code ASC LIMIT :limit")
    suspend fun searchSummitsByName(query: String, limit: Int = 20): List<SOTASummit>

    @Query(
        """
        SELECT * FROM sotaSummit
        WHERE latitude BETWEEN :minLat AND :maxLat
        AND longitude BETWEEN :minLon AND :maxLon
        ORDER BY code ASC
        """
    )
    suspend fun getSummitsInBounds(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double,
    ): List<SOTASummit>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSummits(summits: List<SOTASummit>)

    @Query("DELETE FROM sotaSummit")
    suspend fun deleteAllSummits()

    @Query("SELECT COUNT(*) FROM sotaSummit")
    suspend fun getSummitCount(): Int

    // POTA Parks

    @Query("SELECT * FROM potaPark WHERE reference = :reference")
    suspend fun getParkByReference(reference: String): POTAPark?

    @Query("SELECT * FROM potaPark WHERE referenceNormalized LIKE :prefix || '%' ORDER BY reference ASC LIMIT :limit")
    suspend fun searchParksByNormalizedPrefix(prefix: String, limit: Int = 20): List<POTAPark>

    @Query("SELECT * FROM potaPark WHERE name LIKE '%' || :query || '%' ORDER BY reference ASC LIMIT :limit")
    suspend fun searchParksByName(query: String, limit: Int = 20): List<POTAPark>

    @Query(
        """
        SELECT * FROM potaPark
        WHERE latitude BETWEEN :minLat AND :maxLat
        AND longitude BETWEEN :minLon AND :maxLon
        ORDER BY reference ASC
        """
    )
    suspend fun getParksInBounds(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double,
    ): List<POTAPark>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertParks(parks: List<POTAPark>)

    @Query("DELETE FROM potaPark")
    suspend fun deleteAllParks()

    @Query("SELECT COUNT(*) FROM potaPark")
    suspend fun getParkCount(): Int

    // Reference Metadata

    @Query("SELECT * FROM referenceMetadata WHERE `key` = :key")
    suspend fun getMetadata(key: String): ReferenceMetadata?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertMetadata(metadata: ReferenceMetadata)
}
