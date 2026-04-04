package com.sotalog.android.ui.logging

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.sotalog.android.domain.models.Log
import com.sotalog.android.domain.services.SOTAmatService

@Composable
fun SpotMeScreen(
    log: Log,
    frequencyMHz: String,
    mode: String,
    onDismiss: () -> Unit = {},
) {
    var comment by remember { mutableStateOf("") }
    val context = LocalContext.current

    val spotMessage = SOTAmatService.spotMessage(
        log = log,
        frequencyMHz = frequencyMHz,
        mode = mode,
        comment = comment.ifBlank { null },
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // Title bar
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Spot Me",
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.weight(1f),
            )
            IconButton(onClick = onDismiss) {
                Icon(Icons.Default.Close, contentDescription = "Done")
            }
        }

        Text(
            text = "Post your spot via SOTAmat SMS.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        // Message preview
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = MaterialTheme.colorScheme.surfaceVariant,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(
                text = spotMessage ?: "",
                style = MaterialTheme.typography.bodyMedium.copy(
                    fontFamily = FontFamily.Monospace,
                ),
                modifier = Modifier.padding(12.dp),
            )
        }

        // Comment field
        OutlinedTextField(
            value = comment,
            onValueChange = { comment = it },
            label = { Text("e.g. QRT, Running 5W") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )

        // Send button
        Button(
            onClick = { sendSMS(context, spotMessage ?: "") },
            enabled = spotMessage != null,
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
        ) {
            Text(
                text = "Send via SMS",
                fontWeight = FontWeight.Bold,
            )
        }

        Spacer(modifier = Modifier.weight(1f))
    }
}

private fun sendSMS(context: Context, message: String) {
    val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:${SOTAmatService.PHONE_NUMBER}")).apply {
        putExtra("sms_body", message)
    }
    try {
        context.startActivity(intent)
    } catch (_: Exception) {
        // No SMS app available
    }
}
