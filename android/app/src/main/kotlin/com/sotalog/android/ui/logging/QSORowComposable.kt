package com.sotalog.android.ui.logging

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sotalog.android.domain.models.QSO
import com.sotalog.android.ui.components.ReferenceIcon
import com.sotalog.android.ui.components.ReferenceType

/**
 * Single QSO row in the log list.
 *
 * Shows: time(UTC) | callsign(monospace, bold) | reference icons | band+mode badge
 * Second line (if present): name and/or QTH
 */
@Composable
fun QSORow(
    qso: QSO,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            // Time UTC
            Text(
                text = formatTimeUTC(qso.timeOn) + "Z",
                style = TextStyle(
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                ),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            // Callsign
            Text(
                text = qso.callsign,
                style = TextStyle(
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                ),
                color = MaterialTheme.colorScheme.onSurface,
            )

            Spacer(Modifier.weight(1f))

            // Reference icons
            if (qso.potaRef != null) {
                ReferenceIcon(type = ReferenceType.POTA)
            }
            if (qso.sotaRef != null) {
                ReferenceIcon(type = ReferenceType.SOTA)
            }

            // Band + Mode badge
            Text(
                text = "${qso.band.uppercase()} ${qso.mode}",
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

        // Detail line: name / QTH
        val detail = buildDetailText(qso.name, qso.qth)
        if (detail != null) {
            Text(
                text = detail,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                modifier = Modifier.padding(start = 54.dp),
            )
        }
    }
}

private fun formatTimeUTC(timeOn: String): String {
    if (timeOn.length != 4) return timeOn
    return timeOn.substring(0, 2) + ":" + timeOn.substring(2)
}

private fun buildDetailText(name: String?, qth: String?): String? {
    val n = name?.takeIf { it.isNotEmpty() }
    val q = qth?.takeIf { it.isNotEmpty() }
    return when {
        n != null && q != null -> "$n \u00B7 $q"
        n != null -> n
        q != null -> q
        else -> null
    }
}
