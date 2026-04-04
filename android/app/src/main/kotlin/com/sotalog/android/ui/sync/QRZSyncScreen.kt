package com.sotalog.android.ui.sync

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Upload
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sotalog.android.ui.theme.SOTALogTheme
import java.io.File
import java.text.SimpleDateFormat
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QRZSyncScreen(
    onLoginLogbook: () -> Unit = {},
    onLoginCallsign: () -> Unit = {},
    onReferenceManager: () -> Unit = {},
    viewModel: QRZSyncViewModel = hiltViewModel(),
) {
    val hasAPIKey by viewModel.hasAPIKey.collectAsStateWithLifecycle()
    val hasCredentials by viewModel.hasCredentials.collectAsStateWithLifecycle()
    val username by viewModel.username.collectAsStateWithLifecycle()
    val unsyncedCount by viewModel.unsyncedCount.collectAsStateWithLifecycle()
    val syncStatus by viewModel.syncStatus.collectAsStateWithLifecycle()
    val lastSyncDate by viewModel.lastSyncDate.collectAsStateWithLifecycle()
    val parkCount by viewModel.parkCount.collectAsStateWithLifecycle()
    val summitCount by viewModel.summitCount.collectAsStateWithLifecycle()

    var showLogbookSignOut by remember { mutableStateOf(false) }
    var showCallsignSignOut by remember { mutableStateOf(false) }

    val context = LocalContext.current

    LaunchedEffect(Unit) {
        viewModel.loadState()
    }

    val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior()

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        topBar = {
            LargeTopAppBar(
                title = { Text("Sync") },
                scrollBehavior = scrollBehavior,
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            // Logbook Sync Section
            SectionHeader("Logbook Sync")

            if (hasAPIKey) {
                SyncStatusRow(
                    syncStatus = syncStatus,
                    unsyncedCount = unsyncedCount,
                    isBusy = viewModel.isBusy,
                    onUpload = { viewModel.uploadAll() },
                )

                OutlinedButton(
                    onClick = { viewModel.refreshFromQRZ() },
                    enabled = !viewModel.isBusy,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Re-download all from QRZ")
                }

                lastSyncDate?.let { date ->
                    val formatted = SimpleDateFormat("MMM d, yyyy h:mm a", Locale.getDefault()).format(date)
                    Text(
                        text = "Last synced: $formatted",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                TextButton(
                    onClick = { showLogbookSignOut = true },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = SOTALogTheme.appColors.red,
                    ),
                ) {
                    Text("Sign Out")
                }
            } else {
                Button(
                    onClick = onLoginLogbook,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Sign In to QRZ", fontWeight = FontWeight.Bold)
                }
                Text(
                    text = "Upload and download QSOs with QRZ.com",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            HorizontalDivider()

            // Callsign Lookup Section
            SectionHeader("Callsign Lookup")

            if (hasCredentials) {
                username?.let { user ->
                    Row {
                        Text("Signed in as ")
                        Text(
                            text = user.uppercase(),
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }

                TextButton(
                    onClick = { showCallsignSignOut = true },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = SOTALogTheme.appColors.red,
                    ),
                ) {
                    Text("Sign Out")
                }
            } else {
                Button(
                    onClick = onLoginCallsign,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Sign In to QRZ", fontWeight = FontWeight.Bold)
                }
                Text(
                    text = "Look up name and location for callsigns.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            HorizontalDivider()

            // Export Section
            SectionHeader("Export")

            OutlinedButton(
                onClick = { shareADIF(context, viewModel) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Export all as ADIF")
            }

            HorizontalDivider()

            // Reference Databases Section
            SectionHeader("Reference Databases")

            ReferenceRow(
                title = "POTA Parks",
                count = parkCount,
                unitName = "parks",
                isLoading = syncStatus is SyncStatus.PreparingReferences,
                onRefresh = { viewModel.downloadParks() },
            )

            ReferenceRow(
                title = "SOTA Summits",
                count = summitCount,
                unitName = "summits",
                isLoading = syncStatus is SyncStatus.PreparingReferences,
                onRefresh = { viewModel.downloadSummits() },
            )

            Spacer(modifier = Modifier.height(16.dp))
        }
    }

    // Sign-out confirmation dialogs
    if (showLogbookSignOut) {
        AlertDialog(
            onDismissRequest = { showLogbookSignOut = false },
            title = { Text("Sign Out of Logbook Sync?") },
            text = { Text("Your QSOs are not affected.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.clearAPIKey()
                        showLogbookSignOut = false
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = SOTALogTheme.appColors.red,
                    ),
                ) {
                    Text("Sign Out")
                }
            },
            dismissButton = {
                TextButton(onClick = { showLogbookSignOut = false }) {
                    Text("Cancel")
                }
            },
        )
    }

    if (showCallsignSignOut) {
        AlertDialog(
            onDismissRequest = { showCallsignSignOut = false },
            title = { Text("Sign Out of Callsign Lookup?") },
            text = { Text("Callsign lookups will stop working.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.clearXMLCredentials()
                        showCallsignSignOut = false
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = SOTALogTheme.appColors.red,
                    ),
                ) {
                    Text("Sign Out")
                }
            },
            dismissButton = {
                TextButton(onClick = { showCallsignSignOut = false }) {
                    Text("Cancel")
                }
            },
        )
    }
}

@Composable
private fun SyncStatusRow(
    syncStatus: SyncStatus,
    unsyncedCount: Int,
    isBusy: Boolean,
    onUpload: () -> Unit,
) {
    val appColors = SOTALogTheme.appColors

    when (syncStatus) {
        is SyncStatus.Synced, is SyncStatus.Idle -> {
            if (unsyncedCount == 0) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = appColors.green,
                    )
                    Text(
                        text = "All QSOs uploaded",
                        color = appColors.green,
                    )
                }
            } else {
                Button(
                    onClick = onUpload,
                    enabled = !isBusy,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = appColors.orange,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(Icons.Default.Upload, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Upload $unsyncedCount QSOs")
                }
            }
        }
        is SyncStatus.Uploading -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                Text("Uploading ${syncStatus.done}/${syncStatus.total}...")
            }
        }
        is SyncStatus.PreparingReferences -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                Text("Fetching reference data...")
            }
        }
        is SyncStatus.Downloading -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                Text("Downloading... ${syncStatus.count} QSOs")
            }
        }
        is SyncStatus.Importing -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                Text("Importing...")
            }
        }
        is SyncStatus.Error -> {
            Text(
                text = syncStatus.message,
                color = SOTALogTheme.appColors.red,
            )
        }
    }
}

@Composable
private fun ReferenceRow(
    title: String,
    count: Int,
    unitName: String,
    isLoading: Boolean,
    onRefresh: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
            )
            Text(
                text = if (count > 0) {
                    "%,d $unitName".format(count)
                } else {
                    "Not downloaded"
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        if (isLoading) {
            CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
        } else {
            OutlinedButton(onClick = onRefresh) {
                Text("Refresh")
            }
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

private fun shareADIF(context: Context, viewModel: QRZSyncViewModel) {
    val adif = viewModel.exportADIF()
    if (adif.content.isBlank()) return

    try {
        val file = File(context.cacheDir, adif.filename.ifBlank { "export.adi" })
        file.writeText(adif.content)

        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )

        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(shareIntent, "Export ADIF"))
    } catch (_: Exception) {
        // Silently fail — file sharing is best-effort
    }
}
