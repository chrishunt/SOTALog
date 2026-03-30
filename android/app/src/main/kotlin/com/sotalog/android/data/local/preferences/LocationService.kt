package com.sotalog.android.data.local.preferences

import android.annotation.SuppressLint
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.sotalog.android.domain.services.MaidenheadConverter
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class LocationService @Inject constructor(
    private val fusedLocationClient: FusedLocationProviderClient,
) {

    private val _currentGrid = MutableStateFlow<String?>(null)
    val currentGrid: StateFlow<String?> = _currentGrid.asStateFlow()

    private val _currentLatitude = MutableStateFlow<Double?>(null)
    val currentLatitude: StateFlow<Double?> = _currentLatitude.asStateFlow()

    private val _currentLongitude = MutableStateFlow<Double?>(null)
    val currentLongitude: StateFlow<Double?> = _currentLongitude.asStateFlow()

    @SuppressLint("MissingPermission")
    fun requestLocation() {
        val cancellationToken = CancellationTokenSource()
        fusedLocationClient.getCurrentLocation(
            Priority.PRIORITY_BALANCED_POWER_ACCURACY,
            cancellationToken.token,
        ).addOnSuccessListener { location ->
            if (location != null) {
                _currentLatitude.value = location.latitude
                _currentLongitude.value = location.longitude
                _currentGrid.value = MaidenheadConverter.gridSquare(
                    latitude = location.latitude,
                    longitude = location.longitude,
                )
            }
        }
    }
}
