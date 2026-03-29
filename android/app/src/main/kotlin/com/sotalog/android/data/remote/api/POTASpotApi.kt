package com.sotalog.android.data.remote.api

import retrofit2.http.GET

interface POTASpotApi {

    @GET("spot/activator")
    suspend fun getActivatorSpots(): String
}
