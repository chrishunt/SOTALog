package com.sotalog.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sotalog.android.ui.theme.SOTALogTheme

/**
 * Large monospaced callsign input field with optional times-worked badge.
 * Auto-uppercases input. This is the dominant visual element on the logging screen.
 */
@Composable
fun CallsignField(
    text: String,
    onTextChanged: (String) -> Unit,
    timesWorked: Int = 0,
    workedToday: Int = 0,
    isDupe: Boolean = false,
    onSubmit: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val appColors = SOTALogTheme.appColors

    val badgeText = when {
        isDupe -> "DUPE"
        workedToday > 0 && timesWorked > 0 -> "$workedToday today \u00B7 x$timesWorked"
        workedToday > 0 -> "$workedToday today"
        timesWorked > 0 -> "x$timesWorked"
        else -> null
    }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier,
    ) {
        TextField(
            value = text,
            onValueChange = { newValue ->
                onTextChanged(newValue.uppercase().filter { c ->
                    c.isLetterOrDigit() || c == '/' || c == ' ' || c == '.'
                })
            },
            placeholder = {
                Text(
                    text = "W1AW 59 59 CA W6SD133",
                    style = TextStyle(
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 28.sp,
                    ),
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                )
            },
            textStyle = TextStyle(
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp,
                color = MaterialTheme.colorScheme.onSurface,
            ),
            singleLine = true,
            keyboardOptions = KeyboardOptions(
                capitalization = KeyboardCapitalization.Characters,
                autoCorrectEnabled = false,
                keyboardType = KeyboardType.Ascii,
                imeAction = ImeAction.Send,
            ),
            keyboardActions = KeyboardActions(
                onSend = { onSubmit() },
            ),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = Color.Transparent,
                unfocusedContainerColor = Color.Transparent,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
            ),
            modifier = Modifier.weight(1f),
        )

        if (badgeText != null) {
            Text(
                text = badgeText,
                style = TextStyle(
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                ),
                color = appColors.orange,
                modifier = Modifier
                    .background(
                        color = appColors.orange.copy(alpha = 0.15f),
                        shape = RoundedCornerShape(6.dp),
                    )
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            )
        }
    }
}
