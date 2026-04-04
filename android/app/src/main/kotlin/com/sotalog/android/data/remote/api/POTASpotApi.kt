package com.sotalog.android.data.remote.api

import okhttp3.ResponseBody
import retrofit2.http.GET

interface POTASpotApi {

    @GET("spot/activator")
    suspend fun getActivatorSpots(): ResponseBody
}
