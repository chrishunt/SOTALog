package com.sotalog.android.data.remote.api

import okhttp3.ResponseBody
import retrofit2.http.GET
import retrofit2.http.Query

interface SOTASpotApi {

    @GET("api/spots/epoch")
    suspend fun getEpoch(): ResponseBody

    @GET("api/spots")
    suspend fun getSpots(
        @Query("limit") limit: Int = 50,
        @Query("filter") filter: String? = null,
    ): ResponseBody
}
