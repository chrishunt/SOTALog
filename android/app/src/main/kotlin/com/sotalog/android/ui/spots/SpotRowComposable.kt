package com.sotalog.android.ui.spots

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.sotalog.android.domain.models.Spot
import com.sotalog.android.ui.theme.SOTALogTheme

@Composable
fun SpotRowComposable(
    spot: Spot,
    isWorked: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val alpha = if (isWorked) 0.4f else 1.0f

    Column(
        modifier = modifier.alpha(alpha),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        // Line 1: Callsign, frequency, age
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = spot.activatorCallsign,
                style = MaterialTheme.typography.bodyLarge.copy(
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Medium,
                ),
                textDecoration = if (isWorked) TextDecoration.LineThrough else TextDecoration.None,
            )

            Spacer(modifier = Modifier.weight(1f))

            Text(
                text = String.format("%.3f", spot.frequency),
                style = MaterialTheme.typography.bodyLarge.copy(
                    fontFamily = FontFamily.Monospace,
                ),
            )

            Spacer(modifier = Modifier.width(8.dp))

            Text(
                text = "${spot.ageMinutes}m",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        // Line 2: Reference info + band/mode badge
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            ReferenceInfo(spot = spot, modifier = Modifier.weight(1f))

            Text(
                text = "${spot.band.uppercase()} ${spot.mode}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        // Line 3: Comments (if any)
        val comments = spot.comments
        if (!comments.isNullOrBlank()) {
            Text(
                text = comments,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun ReferenceInfo(spot: Spot, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        val potaRef = spot.potaReference
        val sotaRef = spot.sotaReference

        if (potaRef != null) {
            POTAIcon(modifier = Modifier.size(12.dp))
            Text(
                text = potaRef,
                style = MaterialTheme.typography.bodySmall.copy(
                    fontFamily = FontFamily.Monospace,
                ),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (sotaRef == null) {
                spot.potaReferenceName?.let { name ->
                    Text(
                        text = name,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }

        if (sotaRef != null) {
            SOTAIcon(modifier = Modifier.size(12.dp))
            Text(
                text = sotaRef,
                style = MaterialTheme.typography.bodySmall.copy(
                    fontFamily = FontFamily.Monospace,
                ),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (potaRef == null) {
                spot.sotaReferenceName?.let { name ->
                    Text(
                        text = name,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

@Composable
fun POTAIcon(modifier: Modifier = Modifier) {
    val color = SOTALogTheme.appColors.green
    Canvas(modifier = modifier) {
        drawCircle(color = color, radius = size.minDimension / 2)
    }
}

@Composable
fun SOTAIcon(modifier: Modifier = Modifier) {
    val color = SOTALogTheme.appColors.blue
    Canvas(modifier = modifier) {
        val path = Path().apply {
            moveTo(size.width / 2, 0f)
            lineTo(size.width, size.height)
            lineTo(0f, size.height)
            close()
        }
        drawPath(path, color)
    }
}
