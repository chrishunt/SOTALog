package com.sotalog.android.data.remote.api

import retrofit2.http.GET
import retrofit2.http.Query

interface SOTASpotApi {

    @GET("api/spots/epoch")
    suspend fun getEpoch(): String

    @GET("api/spots")
    suspend fun getSpots(
        @Query("limit") limit: Int = 50,
        @Query("filter") filter: String? = null,
    ): String
}
