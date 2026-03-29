package com.sotalog.android.ui.activations

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Forest
import androidx.compose.material.icons.filled.Landscape
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sotalog.android.domain.models.POTAPark
import com.sotalog.android.domain.models.SOTASummit
import com.sotalog.android.ui.theme.SOTALogTheme
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NewLogScreen(
    onLogCreated: (Long) -> Unit,
    onBack: () -> Unit,
    viewModel: NewLogViewModel = hiltViewModel(),
) {
    val appColors = SOTALogTheme.appColors
    val scope = rememberCoroutineScope()

    val myCallsign by viewModel.myCallsign.collectAsStateWithLifecycle()
    val myGrid by viewModel.myGrid.collectAsStateWithLifecycle()
    val potaReference by viewModel.potaReference.collectAsStateWithLifecycle()
    val sotaReference by viewModel.sotaReference.collectAsStateWithLifecycle()
    val parkName by viewModel.parkName.collectAsStateWithLifecycle()
    val summitName by viewModel.summitName.collectAsStateWithLifecycle()
    val parkSearchResults by viewModel.parkSearchResults.collectAsStateWithLifecycle()
    val summitSearchResults by viewModel.summitSearchResults.collectAsStateWithLifecycle()
    val nearbyParks by viewModel.nearbyParks.collectAsStateWithLifecycle()
    val nearbySummits by viewModel.nearbySummits.collectAsStateWithLifecycle()
    val hasPOTAData by viewModel.hasPOTAData.collectAsStateWithLifecycle()
    val hasSOTAData by viewModel.hasSOTAData.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.checkReferenceData()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("New Activation") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.Close, contentDescription = "Cancel")
                    }
                },
                actions = {
                    Button(
                        onClick = {
                            scope.launch {
                                val logId = viewModel.createLog()
                                onLogCreated(logId)
                            }
                        },
                        enabled = myCallsign.isNotEmpty(),
                        modifier = Modifier.padding(end = 8.dp),
                    ) {
                        Text("Start", fontWeight = FontWeight.Bold)
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Station section
            Text(
                "Station",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            OutlinedTextField(
                value = myCallsign,
                onValueChange = { viewModel.onCallsignChanged(it.uppercase()) },
                label = { Text("My Callsign") },
                singleLine = true,
                textStyle = TextStyle(
                    fontFamily = FontFamily.Monospace,
                    fontSize = 22.sp,
                ),
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Characters,
                    autoCorrectEnabled = false,
                ),
                modifier = Modifier.fillMaxWidth(),
            )

            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                OutlinedTextField(
                    value = myGrid ?: "",
                    onValueChange = { },
                    label = { Text("Grid Square") },
                    readOnly = true,
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Characters,
                        autoCorrectEnabled = false,
                    ),
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = { viewModel.requestLocation() }) {
                    Icon(
                        Icons.Default.LocationOn,
                        contentDescription = "Get location",
                        tint = MaterialTheme.colorScheme.primary,
                    )
                }
            }

            HorizontalDivider()

            // POTA section
            Text(
                "POTA",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            if (hasPOTAData) {
                OutlinedTextField(
                    value = potaReference,
                    onValueChange = { viewModel.onPotaReferenceChanged(it.uppercase()) },
                    label = { Text("Park Reference (e.g. US-4431)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Characters,
                        autoCorrectEnabled = false,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )

                if (parkName != null) {
                    Text(
                        text = parkName!!,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                // Show nearby parks or search results
                val parksToShow = if (potaReference.isEmpty() && nearbyParks.isNotEmpty()) {
                    nearbyParks
                } else {
                    parkSearchResults
                }
                val isNearby = potaReference.isEmpty() && nearbyParks.isNotEmpty()

                parksToShow.forEach { park ->
                    ParkRow(
                        park = park,
                        isNearby = isNearby,
                        distanceMiles = viewModel.distanceMiles(park.latitude, park.longitude),
                        onClick = { viewModel.selectPark(park) },
                    )
                }
            } else {
                Text(
                    text = "Download POTA park data to enable park search",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            HorizontalDivider()

            // SOTA section
            Text(
                "SOTA",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            if (hasSOTAData) {
                OutlinedTextField(
                    value = sotaReference,
                    onValueChange = { viewModel.onSotaReferenceChanged(it.uppercase()) },
                    label = { Text("Summit Reference (e.g. W4C/CM-001)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Characters,
                        autoCorrectEnabled = false,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )

                if (summitName != null) {
                    Text(
                        text = summitName!!,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                val summitsToShow = if (sotaReference.isEmpty() && nearbySummits.isNotEmpty()) {
                    nearbySummits
                } else {
                    summitSearchResults
                }
                val isNearby = sotaReference.isEmpty() && nearbySummits.isNotEmpty()

                summitsToShow.forEach { summit ->
                    SummitRow(
                        summit = summit,
                        isNearby = isNearby,
                        distanceMiles = viewModel.distanceMiles(summit.latitude, summit.longitude),
                        onClick = { viewModel.selectSummit(summit) },
                    )
                }
            } else {
                Text(
                    text = "Download SOTA summit data to enable summit search",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Spacer(Modifier.height(32.dp))
        }
    }
}

@Composable
private fun ParkRow(
    park: POTAPark,
    isNearby: Boolean,
    distanceMiles: Double?,
    onClick: () -> Unit,
) {
    val appColors = SOTALogTheme.appColors

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 6.dp),
    ) {
        Icon(
            imageVector = if (isNearby) Icons.Default.LocationOn else Icons.Default.Forest,
            contentDescription = null,
            tint = appColors.green,
            modifier = Modifier.padding(end = 6.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = park.reference,
                style = TextStyle(
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Medium,
                    fontSize = 16.sp,
                ),
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = park.name,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (distanceMiles != null) {
            Text(
                text = "%.0f mi".format(distanceMiles),
                style = TextStyle(
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                ),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun SummitRow(
    summit: SOTASummit,
    isNearby: Boolean,
    distanceMiles: Double?,
    onClick: () -> Unit,
) {
    val appColors = SOTALogTheme.appColors

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 6.dp),
    ) {
        Icon(
            imageVector = if (isNearby) Icons.Default.LocationOn else Icons.Default.Landscape,
            contentDescription = null,
            tint = appColors.blue,
            modifier = Modifier.padding(end = 6.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = summit.code,
                style = TextStyle(
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Medium,
                    fontSize = 16.sp,
                ),
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = "${summit.name} (${summit.points ?: 0}pt)",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (distanceMiles != null) {
            Text(
                text = "%.0f mi".format(distanceMiles),
                style = TextStyle(
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                ),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
