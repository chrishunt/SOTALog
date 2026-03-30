package com.sotalog.android.data.remote.api

import retrofit2.http.GET
import retrofit2.http.Path

interface POTALocationApi {

    @GET("locations")
    suspend fun getLocations(): String

    @GET("location/parks/{locationCode}")
    suspend fun getParksByLocation(
        @Path("locationCode") locationCode: String,
    ): String
}
