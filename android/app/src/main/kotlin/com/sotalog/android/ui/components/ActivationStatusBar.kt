package com.sotalog.android.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Forest
import androidx.compose.material.icons.filled.Landscape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sotalog.android.ui.theme.SOTALogTheme

private const val POTA_THRESHOLD = 10
private const val SOTA_THRESHOLD = 4

/**
 * Activation progress display.
 *
 * Shows QSO count plus per-reference progress:
 * - "5 QSOs  tree US-4431  5/10" (orange fraction when incomplete)
 * - "12 QSOs  tree US-4431  checkmark" (green checkmark when complete)
 * - SOTA uses blue checkmark / mountain icon
 */
@Composable
fun ActivationStatusBar(
    qsoCount: Int,
    potaReference: String?,
    sotaReference: String?,
    modifier: Modifier = Modifier,
) {
    val appColors = SOTALogTheme.appColors

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        modifier = modifier.padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        // QSO count
        Text(
            text = "$qsoCount",
            style = TextStyle(
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
            ),
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = "QSOs",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        // POTA block
        if (potaReference != null) {
            ReferenceProgressBlock(
                icon = { ReferenceIcon(type = ReferenceType.POTA) },
                reference = potaReference,
                count = qsoCount,
                threshold = POTA_THRESHOLD,
                completeColor = appColors.green,
                incompleteColor = appColors.orange,
            )
        }

        // SOTA block
        if (sotaReference != null) {
            ReferenceProgressBlock(
                icon = { ReferenceIcon(type = ReferenceType.SOTA) },
                reference = sotaReference,
                count = qsoCount,
                threshold = SOTA_THRESHOLD,
                completeColor = appColors.blue,
                incompleteColor = appColors.orange,
            )
        }
    }
}

@Composable
private fun ReferenceProgressBlock(
    icon: @Composable () -> Unit,
    reference: String,
    count: Int,
    threshold: Int,
    completeColor: Color,
    incompleteColor: Color,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        icon()
        Text(
            text = reference,
            style = TextStyle(
                fontFamily = FontFamily.Monospace,
                fontSize = 12.sp,
            ),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        ActivationProgress(
            count = count,
            threshold = threshold,
            completeColor = completeColor,
            incompleteColor = incompleteColor,
        )
    }
}

@Composable
fun ActivationProgress(
    count: Int,
    threshold: Int,
    completeColor: Color,
    incompleteColor: Color,
    modifier: Modifier = Modifier,
) {
    if (count >= threshold) {
        Icon(
            imageVector = Icons.Default.CheckCircle,
            contentDescription = "Complete",
            tint = completeColor,
            modifier = modifier.size(16.dp),
        )
    } else {
        Text(
            text = "$count/$threshold",
            style = TextStyle(
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                fontSize = 12.sp,
            ),
            color = incompleteColor,
            modifier = modifier,
        )
    }
}

enum class ReferenceType { POTA, SOTA }

@Composable
fun ReferenceIcon(
    type: ReferenceType,
    modifier: Modifier = Modifier,
) {
    val appColors = SOTALogTheme.appColors
    when (type) {
        ReferenceType.POTA -> Icon(
            imageVector = Icons.Default.Forest,
            contentDescription = "POTA",
            tint = appColors.green,
            modifier = modifier.size(16.dp),
        )
        ReferenceType.SOTA -> Icon(
            imageVector = Icons.Default.Landscape,
            contentDescription = "SOTA",
            tint = appColors.blue,
            modifier = modifier.size(16.dp),
        )
    }
}
