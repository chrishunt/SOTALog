package com.sotalog.android.ui.spots

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sotalog.android.domain.models.Spot

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SpotsScreen(
    workedKeys: Set<String> = emptySet(),
    onSpotSelected: (Spot) -> Unit = {},
    onDismiss: () -> Unit = {},
    viewModel: SpotsViewModel = hiltViewModel(),
) {
    val spots by viewModel.spots.collectAsStateWithLifecycle()
    val sourceFilter by viewModel.sourceFilter.collectAsStateWithLifecycle()
    val modeFilter by viewModel.modeFilter.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()

    DisposableEffect(Unit) {
        viewModel.startAutoRefresh()
        onDispose { viewModel.stopAutoRefresh() }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Spots") },
                actions = {
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Done")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            // Filter row
            FilterRow(
                sourceFilter = sourceFilter,
                modeFilter = modeFilter,
                onSourceFilterChanged = viewModel::setSourceFilter,
                onModeFilterChanged = viewModel::setModeFilter,
            )

            val spotsByBand by viewModel.spotsByBand.collectAsStateWithLifecycle()

            PullToRefreshBox(
                isRefreshing = isLoading,
                onRefresh = { viewModel.refresh() },
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    isLoading && spots.isEmpty() -> {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center,
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                CircularProgressIndicator()
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    "Loading spots...",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                    spotsByBand.isEmpty() -> {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center,
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(
                                    "No Spots",
                                    style = MaterialTheme.typography.titleLarge,
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    "Pull to refresh or wait for activators.",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                    else -> {
                        LazyColumn(modifier = Modifier.fillMaxSize()) {
                            spotsByBand.forEach { group ->
                                item(key = "header_${group.band}") {
                                    BandHeader(band = group.band, count = group.spots.size)
                                }
                                items(
                                    items = group.spots,
                                    key = { it.id },
                                ) { spot ->
                                    SpotRowComposable(
                                        spot = spot,
                                        isWorked = isWorked(spot, workedKeys),
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable { onSpotSelected(spot) }
                                            .padding(horizontal = 16.dp, vertical = 4.dp),
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FilterRow(
    sourceFilter: SourceFilter,
    modeFilter: ModeFilter,
    onSourceFilterChanged: (SourceFilter) -> Unit,
    onModeFilterChanged: (ModeFilter) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // Source filters
        SourceFilter.entries.forEach { filter ->
            FilterChip(
                selected = sourceFilter == filter,
                onClick = { onSourceFilterChanged(filter) },
                label = {
                    Text(
                        when (filter) {
                            SourceFilter.ALL -> "All"
                            SourceFilter.POTA -> "POTA"
                            SourceFilter.SOTA -> "SOTA"
                        },
                    )
                },
            )
        }

        Spacer(modifier = Modifier.width(8.dp))

        // Mode filters
        ModeFilter.entries.forEach { filter ->
            FilterChip(
                selected = modeFilter == filter,
                onClick = { onModeFilterChanged(filter) },
                label = {
                    Text(
                        when (filter) {
                            ModeFilter.ALL -> "All"
                            ModeFilter.CW -> "CW"
                            ModeFilter.SSB -> "SSB"
                        },
                    )
                },
            )
        }
    }
}

@Composable
private fun BandHeader(band: String, count: Int) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = band.uppercase(),
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = "$count",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

private fun isWorked(spot: Spot, workedKeys: Set<String>): Boolean {
    val callsign = spot.activatorCallsign.uppercase()
    val band = spot.band
    val mode = spot.mode

    val potaRef = spot.potaReference
    if (potaRef != null) {
        val suffix = "|$callsign|$potaRef|$band|$mode"
        if (workedKeys.any { it.endsWith(suffix) }) return true
    }
    val sotaRef = spot.sotaReference
    if (sotaRef != null) {
        val suffix = "|$callsign|$sotaRef|$band|$mode"
        if (workedKeys.any { it.endsWith(suffix) }) return true
    }
    return false
}
