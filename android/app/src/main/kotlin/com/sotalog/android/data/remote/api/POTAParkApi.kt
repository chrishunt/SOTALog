package com.sotalog.android.data.remote.api

import retrofit2.http.GET
import retrofit2.http.Path

interface POTAParkApi {

    @GET("park/{reference}")
    suspend fun getPark(
        @Path("reference") reference: String,
    ): String

    @GET("park/grids/{grid}/{distance}")
    suspend fun getParksByGrid(
        @Path("grid") grid: String,
        @Path("distance") distanceKm: Int,
    ): String
}
