package com.sotalog.android.data.remote.api

import retrofit2.http.GET
import retrofit2.http.Path

interface SOTASummitApi {

    @GET("api/associations")
    suspend fun getAssociations(): String

    @GET("api/associations/{associationCode}")
    suspend fun getAssociation(
        @Path("associationCode") associationCode: String,
    ): String

    @GET("api/summits/{summitCode}")
    suspend fun getSummit(
        @Path("summitCode") summitCode: String,
    ): String
}
