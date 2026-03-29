package com.sotalog.android.data.remote.api

import retrofit2.http.Field
import retrofit2.http.FormUrlEncoded
import retrofit2.http.POST

interface QRZLogbookApi {

    @FormUrlEncoded
    @POST("api")
    suspend fun execute(
        @Field("KEY") apiKey: String,
        @Field("ACTION") action: String,
        @Field("ADIF") adif: String? = null,
        @Field("OPTION") option: String? = null,
    ): String
}
