package com.sotalog.android.data.remote.api

import okhttp3.ResponseBody
import retrofit2.http.GET

interface SOTASpotApi {

    @GET("api/spots/epoch")
    suspend fun getEpoch(): ResponseBody

    @GET("api/spots/-1/all/cw,ssb,fm")
    suspend fun getSpots(): ResponseBody
}
