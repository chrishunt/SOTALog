package com.sotalog.android.data.repositories

import com.sotalog.android.data.local.database.dao.ReferenceDao
import com.sotalog.android.domain.models.POTAPark
import com.sotalog.android.domain.models.ReferenceMetadata
import com.sotalog.android.domain.models.SOTASummit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.cos
import kotlin.math.sqrt

@Singleton
class ReferenceRepository @Inject constructor(
    private val referenceDao: ReferenceDao,
) {

    // POTA Parks

    suspend fun searchParks(query: String, limit: Int = 20): List<POTAPark> =
        withContext(Dispatchers.IO) {
            val normalized = POTAPark.normalize(query)
            val byRef = referenceDao.searchParksByNormalizedPrefix(normalized, limit)
            if (byRef.isNotEmpty()) return@withContext byRef
            // Fall back to name search
            referenceDao.searchParksByName(query, limit)
        }

    suspend fun fetchPark(reference: String): POTAPark? = withContext(Dispatchers.IO) {
        referenceDao.getParkByReference(reference)
    }

    suspend fun fetchParkByNormalized(normalized: String): POTAPark? =
        withContext(Dispatchers.IO) {
            val results = referenceDao.searchParksByNormalizedPrefix(normalized, 1)
            results.firstOrNull { it.referenceNormalized == normalized }
        }

    suspend fun importParks(parks: List<POTAPark>) = withContext(Dispatchers.IO) {
        // Insert in batches to avoid transaction size limits
        parks.chunked(500).forEach { batch ->
            referenceDao.insertParks(batch)
        }
    }

    suspend fun parkCount(): Int = withContext(Dispatchers.IO) {
        referenceDao.getParkCount()
    }

    suspend fun deleteAllParks() = withContext(Dispatchers.IO) {
        referenceDao.deleteAllParks()
    }

    suspend fun nearbyParks(
        latitude: Double,
        longitude: Double,
        limit: Int = 10,
    ): List<POTAPark> = withContext(Dispatchers.IO) {
        // Bounding box: ~1 degree latitude ~ 111 km
        val latDelta = 1.0
        val lonDelta = 1.0 / cos(Math.toRadians(latitude))

        val candidates = referenceDao.getParksInBounds(
            minLat = latitude - latDelta,
            maxLat = latitude + latDelta,
            minLon = longitude - lonDelta,
            maxLon = longitude + lonDelta,
        )

        // Sort by equirectangular approximation distance
        val cosLat = cos(Math.toRadians(latitude))
        candidates
            .filter { it.latitude != null && it.longitude != null }
            .sortedBy { park ->
                val dLat = park.latitude!! - latitude
                val dLon = (park.longitude!! - longitude) * cosLat
                sqrt(dLat * dLat + dLon * dLon)
            }
            .take(limit)
    }

    suspend fun enrichParksWithCoordinates(
        coords: List<Triple<String, Double, Double>>,
    ) = withContext(Dispatchers.IO) {
        for ((reference, lat, lon) in coords) {
            val park = referenceDao.getParkByReference(reference) ?: continue
            referenceDao.insertParks(listOf(park.copy(latitude = lat, longitude = lon)))
        }
    }

    // SOTA Summits

    suspend fun searchSummits(query: String, limit: Int = 20): List<SOTASummit> =
        withContext(Dispatchers.IO) {
            val normalized = SOTASummit.normalize(query)
            val byCode = referenceDao.searchSummitsByNormalizedPrefix(normalized, limit)
            if (byCode.isNotEmpty()) return@withContext byCode
            // Fall back to name search
            referenceDao.searchSummitsByName(query, limit)
        }

    suspend fun fetchSummit(code: String): SOTASummit? = withContext(Dispatchers.IO) {
        referenceDao.getSummitByCode(code)
    }

    suspend fun fetchSummitByNormalized(normalized: String): SOTASummit? =
        withContext(Dispatchers.IO) {
            val results = referenceDao.searchSummitsByNormalizedPrefix(normalized, 1)
            results.firstOrNull { it.codeNormalized == normalized }
        }

    suspend fun importSummits(summits: List<SOTASummit>) = withContext(Dispatchers.IO) {
        summits.chunked(500).forEach { batch ->
            referenceDao.insertSummits(batch)
        }
    }

    suspend fun summitCount(): Int = withContext(Dispatchers.IO) {
        referenceDao.getSummitCount()
    }

    suspend fun deleteAllSummits() = withContext(Dispatchers.IO) {
        referenceDao.deleteAllSummits()
    }

    suspend fun nearbySummits(
        latitude: Double,
        longitude: Double,
        limit: Int = 10,
    ): List<SOTASummit> = withContext(Dispatchers.IO) {
        val latDelta = 1.0
        val lonDelta = 1.0 / cos(Math.toRadians(latitude))

        val candidates = referenceDao.getSummitsInBounds(
            minLat = latitude - latDelta,
            maxLat = latitude + latDelta,
            minLon = longitude - lonDelta,
            maxLon = longitude + lonDelta,
        )

        val cosLat = cos(Math.toRadians(latitude))
        candidates
            .filter { it.latitude != null && it.longitude != null }
            .sortedBy { summit ->
                val dLat = summit.latitude!! - latitude
                val dLon = (summit.longitude!! - longitude) * cosLat
                sqrt(dLat * dLat + dLon * dLon)
            }
            .take(limit)
    }

    // Metadata

    suspend fun fetchMetadata(key: String): ReferenceMetadata? = withContext(Dispatchers.IO) {
        referenceDao.getMetadata(key)
    }

    suspend fun saveMetadata(metadata: ReferenceMetadata) = withContext(Dispatchers.IO) {
        referenceDao.upsertMetadata(metadata)
    }
}
