package com.sotalog.android.di

import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import com.sotalog.android.BuildConfig
import com.sotalog.android.data.remote.api.POTALocationApi
import com.sotalog.android.data.remote.api.POTAParkApi
import com.sotalog.android.data.remote.api.POTASpotApi
import com.sotalog.android.data.remote.api.QRZLogbookApi
import com.sotalog.android.data.remote.api.QRZLookupApi
import com.sotalog.android.data.remote.api.SOTASpotApi
import com.sotalog.android.data.remote.api.SOTASummitApi
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import java.util.concurrent.TimeUnit
import javax.inject.Qualifier
import javax.inject.Singleton

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class SOTACatClient

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class QRZLogbookRetrofit

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class QRZLookupRetrofit

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class SOTARetrofit

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class POTARetrofit

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    private const val QRZ_LOGBOOK_BASE_URL = "https://logbook.qrz.com/"
    private const val QRZ_XML_BASE_URL = "https://xmldata.qrz.com/"
    private const val SOTA_BASE_URL = "https://api-db2.sota.org.uk/"
    private const val POTA_BASE_URL = "https://api.pota.app/"

    @Provides
    @Singleton
    fun provideJson(): Json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        isLenient = true
    }

    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient {
        val builder = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)

        if (BuildConfig.DEBUG) {
            val logging = HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
            }
            builder.addInterceptor(logging)
        }

        return builder.build()
    }

    @Provides
    @Singleton
    @SOTACatClient
    fun provideSOTACatClient(): OkHttpClient =
        OkHttpClient.Builder()
            .connectTimeout(5, TimeUnit.SECONDS)
            .readTimeout(5, TimeUnit.SECONDS)
            .writeTimeout(5, TimeUnit.SECONDS)
            .build()

    @Provides
    @Singleton
    @QRZLogbookRetrofit
    fun provideQRZLogbookRetrofit(client: OkHttpClient, json: Json): Retrofit =
        Retrofit.Builder()
            .baseUrl(QRZ_LOGBOOK_BASE_URL)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()

    @Provides
    @Singleton
    @QRZLookupRetrofit
    fun provideQRZLookupRetrofit(client: OkHttpClient, json: Json): Retrofit =
        Retrofit.Builder()
            .baseUrl(QRZ_XML_BASE_URL)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()

    @Provides
    @Singleton
    @SOTARetrofit
    fun provideSOTARetrofit(client: OkHttpClient, json: Json): Retrofit =
        Retrofit.Builder()
            .baseUrl(SOTA_BASE_URL)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()

    @Provides
    @Singleton
    @POTARetrofit
    fun providePOTARetrofit(client: OkHttpClient, json: Json): Retrofit =
        Retrofit.Builder()
            .baseUrl(POTA_BASE_URL)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()

    @Provides
    @Singleton
    fun provideQRZLogbookApi(@QRZLogbookRetrofit retrofit: Retrofit): QRZLogbookApi =
        retrofit.create(QRZLogbookApi::class.java)

    @Provides
    @Singleton
    fun provideQRZLookupApi(@QRZLookupRetrofit retrofit: Retrofit): QRZLookupApi =
        retrofit.create(QRZLookupApi::class.java)

    @Provides
    @Singleton
    fun provideSOTASpotApi(@SOTARetrofit retrofit: Retrofit): SOTASpotApi =
        retrofit.create(SOTASpotApi::class.java)

    @Provides
    @Singleton
    fun provideSOTASummitApi(@SOTARetrofit retrofit: Retrofit): SOTASummitApi =
        retrofit.create(SOTASummitApi::class.java)

    @Provides
    @Singleton
    fun providePOTASpotApi(@POTARetrofit retrofit: Retrofit): POTASpotApi =
        retrofit.create(POTASpotApi::class.java)

    @Provides
    @Singleton
    fun providePOTAParkApi(@POTARetrofit retrofit: Retrofit): POTAParkApi =
        retrofit.create(POTAParkApi::class.java)

    @Provides
    @Singleton
    fun providePOTALocationApi(@POTARetrofit retrofit: Retrofit): POTALocationApi =
        retrofit.create(POTALocationApi::class.java)
}
