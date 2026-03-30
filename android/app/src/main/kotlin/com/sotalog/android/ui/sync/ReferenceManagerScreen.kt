package com.sotalog.android.ui.sync

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sotalog.android.ui.components.ReferenceDownloadRow

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReferenceManagerScreen(
    onBack: () -> Unit = {},
    viewModel: QRZSyncViewModel = hiltViewModel(),
) {
    val parkCount by viewModel.parkCount.collectAsStateWithLifecycle()
    val summitCount by viewModel.summitCount.collectAsStateWithLifecycle()
    val syncStatus by viewModel.syncStatus.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.loadCounts()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { androidx.compose.material3.Text("Reference Databases") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
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
                .padding(innerPadding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            ReferenceDownloadRow(
                title = "POTA Parks",
                count = parkCount,
                unitName = "parks",
                isLoading = syncStatus is SyncStatus.PreparingReferences,
                onRefresh = { viewModel.downloadParks() },
            )

            HorizontalDivider()

            ReferenceDownloadRow(
                title = "SOTA Summits",
                count = summitCount,
                unitName = "summits",
                isLoading = syncStatus is SyncStatus.PreparingReferences,
                onRefresh = { viewModel.downloadSummits() },
            )
        }
    }
}
