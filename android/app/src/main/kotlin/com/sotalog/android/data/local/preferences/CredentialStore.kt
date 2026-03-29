package com.sotalog.android.data.local.preferences

import android.content.SharedPreferences
import com.sotalog.android.di.EncryptedPrefs
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CredentialStore @Inject constructor(
    @EncryptedPrefs private val prefs: SharedPreferences,
) {

    companion object {
        const val QRZ_API_KEY = "qrzAPIKey"
        const val QRZ_USERNAME = "qrzUsername"
        const val QRZ_PASSWORD = "qrzPassword"
        const val QRZ_SESSION_KEY = "qrzSessionKey"
        const val MY_CALLSIGN = "myCallsign"
    }

    fun save(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }

    fun load(key: String): String? =
        prefs.getString(key, null)

    fun delete(key: String) {
        prefs.edit().remove(key).apply()
    }
}
