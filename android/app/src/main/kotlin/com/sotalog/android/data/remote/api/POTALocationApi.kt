package com.sotalog.android.data.remote.api

import retrofit2.http.GET
import retrofit2.http.Path

interface POTALocationApi {

    @GET("programs")
    suspend fun getPrograms(): String

    @GET("location/{locationId}/parks")
    suspend fun getParksByLocation(
        @Path("locationId") locationId: String,
    ): String
}
