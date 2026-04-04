package com.sotalog.android.ui.activations

import android.view.HapticFeedbackConstants
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Radio
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sotalog.android.domain.models.Log
import com.sotalog.android.ui.components.ActivationProgress
import com.sotalog.android.ui.components.POTA_THRESHOLD
import com.sotalog.android.ui.components.ReferenceIcon
import com.sotalog.android.ui.components.ReferenceType
import com.sotalog.android.ui.components.SOTA_THRESHOLD
import com.sotalog.android.ui.theme.SOTALogTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LogListScreen(
    onNewLog: () -> Unit,
    onOpenLog: (Long) -> Unit,
    viewModel: LogListViewModel = hiltViewModel(),
) {
    val logs by viewModel.logs.collectAsStateWithLifecycle()
    val qsoCounts by viewModel.qsoCounts.collectAsStateWithLifecycle()
    val bandsByLog by viewModel.bandsByLog.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            LargeTopAppBar(
                title = { Text("Activations") },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = onNewLog, shape = CircleShape) {
                Icon(Icons.Default.Add, contentDescription = "New Activation")
            }
        },
    ) { padding ->
        if (logs.isEmpty()) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Default.Radio,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier
                            .size(48.dp)
                            .padding(bottom = 8.dp),
                    )
                    Text(
                        "No Activations",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        "Tap + to start your first activation.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
            ) {
                items(
                    items = logs,
                    key = { it.id ?: 0L },
                ) { log ->
                    val logId = log.id ?: 0L
                    val view = LocalView.current
                    SwipeToDeleteRow(
                        onDelete = {
                            view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                            viewModel.deleteLog(logId)
                        },
                    ) {
                        LogRow(
                            log = log,
                            qsoCount = qsoCounts[logId] ?: 0,
                            bands = bandsByLog[logId] ?: emptyList(),
                            onClick = { onOpenLog(logId) },
                        )
                    }
                    HorizontalDivider()
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeToDeleteRow(
    onDelete: () -> Unit,
    content: @Composable () -> Unit,
) {
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
                    .background(SOTALogTheme.appColors.red)
                    .padding(horizontal = 20.dp),
            ) {
                Icon(
                    Icons.Default.Delete,
                    contentDescription = "Delete",
                    tint = MaterialTheme.colorScheme.onError,
                )
            }
        },
        enableDismissFromStartToEnd = false,
    ) {
        Box(
            modifier = Modifier.background(MaterialTheme.colorScheme.surface),
        ) {
            content()
        }
    }
}

@Composable
private fun LogRow(
    log: Log,
    qsoCount: Int,
    bands: List<String>,
    onClick: () -> Unit,
) {
    val appColors = SOTALogTheme.appColors
    val hasReferences = log.potaReference != null || log.sotaReference != null

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        // Row 1: Callsign + Date
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = log.myCallsign,
                style = TextStyle(
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Medium,
                    fontSize = 16.sp,
                ),
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = log.formattedDate,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        if (hasReferences) {
            // Row 2: Reference blocks + band badges
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 2.dp),
            ) {
                if (log.potaReference != null) {
                    ReferenceBlock(
                        type = ReferenceType.POTA,
                        reference = log.potaReference,
                        qsoCount = qsoCount,
                        threshold = POTA_THRESHOLD,
                        completeColor = appColors.green,
                        incompleteColor = appColors.orange,
                    )
                }
                if (log.sotaReference != null) {
                    ReferenceBlock(
                        type = ReferenceType.SOTA,
                        reference = log.sotaReference,
                        qsoCount = qsoCount,
                        threshold = SOTA_THRESHOLD,
                        completeColor = appColors.blue,
                        incompleteColor = appColors.orange,
                    )
                }
                Spacer(Modifier.weight(1f))
                bands.forEach { band ->
                    BandBadge(band)
                }
            }

            // Row 3: QSO count + reference names
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier.padding(top = 2.dp),
            ) {
                Text(
                    text = "$qsoCount",
                    style = TextStyle(
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                    ),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = "QSOs",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                val names = listOfNotNull(log.parkName, log.summitName)
                if (names.isNotEmpty()) {
                    Text(
                        text = "\u00B7",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                    )
                    Text(
                        text = names.joinToString(" \u00B7 "),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                        maxLines = 1,
                    )
                }
            }
        } else {
            // No references: QSO count + bands on one row
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 2.dp),
            ) {
                Text(
                    text = "$qsoCount",
                    style = TextStyle(
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                    ),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = "QSOs",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.weight(1f))
                bands.forEach { band ->
                    BandBadge(band)
                }
            }
        }
    }
}

@Composable
private fun ReferenceBlock(
    type: ReferenceType,
    reference: String,
    qsoCount: Int,
    threshold: Int,
    completeColor: androidx.compose.ui.graphics.Color,
    incompleteColor: androidx.compose.ui.graphics.Color,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        ReferenceIcon(type = type)
        Text(
            text = reference,
            style = TextStyle(
                fontFamily = FontFamily.Monospace,
                fontSize = 12.sp,
            ),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
        )
        ActivationProgress(
            count = qsoCount,
            threshold = threshold,
            completeColor = completeColor,
            incompleteColor = incompleteColor,
        )
    }
}

@Composable
private fun BandBadge(band: String) {
    Text(
        text = band.uppercase(),
        style = TextStyle(
            fontWeight = FontWeight.Bold,
            fontSize = 10.sp,
        ),
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier
            .background(
                color = MaterialTheme.colorScheme.surfaceVariant,
                shape = RoundedCornerShape(4.dp),
            )
            .padding(horizontal = 6.dp, vertical = 2.dp),
    )
}
