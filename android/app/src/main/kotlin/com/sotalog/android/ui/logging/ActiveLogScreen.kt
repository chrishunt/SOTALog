package com.sotalog.android.ui.logging

import android.content.Context
import android.content.Intent
import android.view.HapticFeedbackConstants
import android.view.WindowManager
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sotalog.android.ui.components.ActivationStatusBar
import com.sotalog.android.ui.theme.SOTALogTheme
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActiveLogScreen(
    logId: Long,
    onBack: () -> Unit,
    viewModel: ActiveLogViewModel = hiltViewModel(),
) {
    val log by viewModel.log.collectAsStateWithLifecycle()
    val qsos by viewModel.qsos.collectAsStateWithLifecycle()
    val context = LocalContext.current

    // Keep screen on while logging
    DisposableEffect(Unit) {
        val activity = context as? android.app.Activity
        activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        onDispose {
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    val currentLog = log ?: return

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = currentLog.myCallsign,
                        fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    if (qsos.isNotEmpty()) {
                        IconButton(onClick = { shareExportFiles(context, viewModel) }) {
                            Icon(Icons.Default.Share, contentDescription = "Export")
                        }
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            // Activation status header
            ActivationStatusBar(
                qsoCount = qsos.size,
                potaReference = currentLog.potaReference,
                sotaReference = currentLog.sotaReference,
            )

            HorizontalDivider()

            // QSO list
            Box(modifier = Modifier.weight(1f)) {
                if (qsos.isEmpty()) {
                    Text(
                        text = "Logged contacts appear here",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .padding(top = 24.dp),
                    )
                }

                LazyColumn(modifier = Modifier.fillMaxSize()) {
                    items(
                        items = qsos,
                        key = { it.id ?: 0L },
                    ) { qso ->
                        val canEdit = !qso.syncedToQRZ
                        val view = LocalView.current
                        SwipeToDeleteQSO(
                            enabled = canEdit,
                            onDelete = {
                                view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                                qso.id?.let { viewModel.deleteQSO(it) }
                            },
                        ) {
                            QSORow(
                                qso = qso,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .then(
                                        if (canEdit) Modifier.clickable {
                                            // QSO editing is handled via the entry view model
                                        } else Modifier
                                    )
                                    .padding(horizontal = 16.dp, vertical = 4.dp),
                            )
                        }
                        HorizontalDivider()
                    }
                }
            }

            // QSO Entry panel pinned at bottom
            QSOEntryPanel(logId = logId)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeToDeleteQSO(
    enabled: Boolean,
    onDelete: () -> Unit,
    content: @Composable () -> Unit,
) {
    if (!enabled) {
        content()
        return
    }

    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                onDelete()
                false
            } else {
                false
            }
        },
    )

    SwipeToDismissBox(
        state = dismissState,
        backgroundContent = {
            Box(
                contentAlignment = Alignment.CenterEnd,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 20.dp),
            ) {
                Icon(
                    Icons.Default.Delete,
                    contentDescription = "Delete",
                    tint = SOTALogTheme.appColors.red,
                )
            }
        },
        enableDismissFromStartToEnd = false,
    ) {
        content()
    }
}

private fun shareExportFiles(context: Context, viewModel: ActiveLogViewModel) {
    val files = viewModel.exportFiles
    if (files.isEmpty()) return

    val uris = files.map { file ->
        val cacheDir = File(context.cacheDir, "exports")
        cacheDir.mkdirs()
        val outputFile = File(cacheDir, file.filename)
        outputFile.writeText(file.content)
        FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", outputFile)
    }

    val intent = if (uris.size == 1) {
        Intent(Intent.ACTION_SEND).apply {
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_STREAM, uris.first())
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    } else {
        Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = "application/octet-stream"
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }

    context.startActivity(Intent.createChooser(intent, "Export ADIF"))
}
