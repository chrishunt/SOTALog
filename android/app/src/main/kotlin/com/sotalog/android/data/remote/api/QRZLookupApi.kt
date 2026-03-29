package com.sotalog.android.data.remote.api

import retrofit2.http.GET
import retrofit2.http.Query

interface QRZLookupApi {

    @GET("xml/current/")
    suspend fun lookup(
        @Query("s") sessionKey: String,
        @Query("callsign") callsign: String,
    ): String

    @GET("xml/current/")
    suspend fun getSession(
        @Query("username") username: String,
        @Query("password") password: String,
    ): String
}
