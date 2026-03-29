package com.sotalog.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sotalog.android.ui.theme.SOTALogTheme

/**
 * Editable field types for the metadata strip.
 */
private enum class EditField {
    RST_SENT, RST_RECEIVED, FREQUENCY, NAME, QTH, POTA_REF, SOTA_REF, NONE
}

/**
 * Horizontal strip of tappable metadata chips.
 * Tap any segment to edit inline. Displays frequency, mode, RST, and references.
 */
@Composable
fun MetadataStrip(
    rstSent: String,
    onRstSentChanged: (String) -> Unit,
    rstReceived: String,
    onRstReceivedChanged: (String) -> Unit,
    frequencyText: String,
    onFrequencyChanged: (String) -> Unit,
    mode: String,
    onModeToggle: () -> Unit,
    name: String,
    onNameChanged: (String) -> Unit,
    qth: String,
    onQthChanged: (String) -> Unit,
    potaRefInput: String,
    onPotaRefChanged: (String) -> Unit,
    potaRefFormatted: String?,
    potaRefValid: Boolean,
    sotaRefInput: String,
    onSotaRefChanged: (String) -> Unit,
    sotaRefFormatted: String?,
    sotaRefValid: Boolean,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val appColors = SOTALogTheme.appColors
    var editingField by remember { mutableStateOf(EditField.NONE) }

    val isEditingLine1 = editingField in listOf(
        EditField.RST_SENT, EditField.RST_RECEIVED, EditField.FREQUENCY,
        EditField.POTA_REF, EditField.SOTA_REF,
    )
    val isEditingLine2 = editingField in listOf(EditField.NAME, EditField.QTH)

    val chipTextStyle = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontSize = 14.sp,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )

    // Line 1: frequency . mode . RST sent . RST received [. refs]
    if (isEditingLine1) {
        MetadataEditor(
            editingField = editingField,
            rstSent = rstSent,
            onRstSentChanged = onRstSentChanged,
            rstReceived = rstReceived,
            onRstReceivedChanged = onRstReceivedChanged,
            frequencyText = frequencyText,
            onFrequencyChanged = onFrequencyChanged,
            potaRefInput = potaRefInput,
            onPotaRefChanged = onPotaRefChanged,
            sotaRefInput = sotaRefInput,
            onSotaRefChanged = onSotaRefChanged,
            mode = mode,
            onDismiss = {
                editingField = EditField.NONE
                onSubmit()
            },
        )
    } else {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = modifier.fillMaxWidth(),
        ) {
            MetadataChip(
                text = frequencyText,
                onClick = { editingField = EditField.FREQUENCY },
                textStyle = chipTextStyle,
            )
            DotSeparator()
            MetadataChip(
                text = mode,
                onClick = onModeToggle,
                textStyle = chipTextStyle,
            )
            DotSeparator()
            MetadataChip(
                text = rstSent,
                onClick = { editingField = EditField.RST_SENT },
                textStyle = chipTextStyle,
            )
            DotSeparator()
            MetadataChip(
                text = rstReceived,
                onClick = { editingField = EditField.RST_RECEIVED },
                textStyle = chipTextStyle,
            )

            if (potaRefValid && potaRefFormatted != null) {
                DotSeparator()
                ReferenceChip(
                    text = potaRefFormatted,
                    color = appColors.green,
                    onClick = { editingField = EditField.POTA_REF },
                    textStyle = chipTextStyle,
                )
            } else if (potaRefInput.isNotEmpty()) {
                DotSeparator()
                MetadataChip(
                    text = potaRefInput,
                    onClick = { editingField = EditField.POTA_REF },
                    textStyle = chipTextStyle,
                )
            }

            if (sotaRefValid && sotaRefFormatted != null) {
                DotSeparator()
                ReferenceChip(
                    text = sotaRefFormatted,
                    color = appColors.blue,
                    onClick = { editingField = EditField.SOTA_REF },
                    textStyle = chipTextStyle,
                )
            } else if (sotaRefInput.isNotEmpty()) {
                DotSeparator()
                MetadataChip(
                    text = sotaRefInput,
                    onClick = { editingField = EditField.SOTA_REF },
                    textStyle = chipTextStyle,
                )
            }

            Spacer(Modifier.weight(1f))
        }
    }

    // Line 2: name . QTH (only when populated)
    if (isEditingLine2) {
        MetadataEditor(
            editingField = editingField,
            rstSent = rstSent,
            onRstSentChanged = onRstSentChanged,
            rstReceived = rstReceived,
            onRstReceivedChanged = onRstReceivedChanged,
            frequencyText = frequencyText,
            onFrequencyChanged = onFrequencyChanged,
            potaRefInput = potaRefInput,
            onPotaRefChanged = onPotaRefChanged,
            sotaRefInput = sotaRefInput,
            onSotaRefChanged = onSotaRefChanged,
            mode = mode,
            name = name,
            onNameChanged = onNameChanged,
            qth = qth,
            onQthChanged = onQthChanged,
            onDismiss = {
                editingField = EditField.NONE
                onSubmit()
            },
        )
    } else if (name.isNotEmpty() || qth.isNotEmpty()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (name.isNotEmpty()) {
                MetadataChip(
                    text = name,
                    onClick = { editingField = EditField.NAME },
                    textStyle = chipTextStyle.copy(fontFamily = FontFamily.Default),
                )
            }
            if (name.isNotEmpty() && qth.isNotEmpty()) {
                DotSeparator()
            }
            if (qth.isNotEmpty()) {
                MetadataChip(
                    text = qth,
                    onClick = { editingField = EditField.QTH },
                    textStyle = chipTextStyle.copy(fontFamily = FontFamily.Default),
                )
            }
            Spacer(Modifier.weight(1f))
        }
    }
}

@Composable
private fun MetadataChip(
    text: String,
    onClick: () -> Unit,
    textStyle: TextStyle,
) {
    Text(
        text = text,
        style = textStyle,
        modifier = Modifier
            .clickable(onClick = onClick)
            .background(
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.1f),
                shape = CircleShape,
            )
            .padding(horizontal = 6.dp, vertical = 2.dp),
    )
}

@Composable
private fun ReferenceChip(
    text: String,
    color: androidx.compose.ui.graphics.Color,
    onClick: () -> Unit,
    textStyle: TextStyle,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
        modifier = Modifier
            .clickable(onClick = onClick)
            .background(
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.1f),
                shape = CircleShape,
            )
            .padding(horizontal = 6.dp, vertical = 2.dp),
    ) {
        Text(text = text, style = textStyle)
        Icon(
            imageVector = Icons.Default.CheckCircle,
            contentDescription = "Valid",
            tint = color,
            modifier = Modifier.padding(start = 2.dp),
        )
    }
}

@Composable
private fun DotSeparator() {
    Text(
        text = " \u00B7 ",
        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
        fontSize = 14.sp,
    )
}

@Composable
private fun MetadataEditor(
    editingField: EditField,
    rstSent: String,
    onRstSentChanged: (String) -> Unit,
    rstReceived: String,
    onRstReceivedChanged: (String) -> Unit,
    frequencyText: String,
    onFrequencyChanged: (String) -> Unit,
    potaRefInput: String,
    onPotaRefChanged: (String) -> Unit,
    sotaRefInput: String,
    onSotaRefChanged: (String) -> Unit,
    mode: String,
    name: String = "",
    onNameChanged: (String) -> Unit = {},
    qth: String = "",
    onQthChanged: (String) -> Unit = {},
    onDismiss: () -> Unit,
) {
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(editingField) {
        focusRequester.requestFocus()
    }

    when (editingField) {
        EditField.RST_SENT -> {
            OutlinedTextField(
                value = rstSent,
                onValueChange = onRstSentChanged,
                label = { Text("RST Sent") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Number,
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(onDone = { onDismiss() }),
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focusRequester),
            )
        }
        EditField.RST_RECEIVED -> {
            OutlinedTextField(
                value = rstReceived,
                onValueChange = onRstReceivedChanged,
                label = { Text("RST Received") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Number,
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(onDone = { onDismiss() }),
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focusRequester),
            )
        }
        EditField.FREQUENCY -> {
            OutlinedTextField(
                value = frequencyText,
                onValueChange = onFrequencyChanged,
                label = { Text("Frequency (MHz)") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Decimal,
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(onDone = { onDismiss() }),
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focusRequester),
            )
        }
        EditField.POTA_REF -> {
            OutlinedTextField(
                value = potaRefInput,
                onValueChange = { onPotaRefChanged(it.uppercase().filter { c -> c.isLetterOrDigit() || c == '-' }) },
                label = { Text("Park Reference") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Characters,
                    autoCorrectEnabled = false,
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(onDone = { onDismiss() }),
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focusRequester),
            )
        }
        EditField.SOTA_REF -> {
            OutlinedTextField(
                value = sotaRefInput,
                onValueChange = { onSotaRefChanged(it.uppercase().filter { c -> c.isLetterOrDigit() || c == '/' || c == '-' }) },
                label = { Text("Summit Reference") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Characters,
                    autoCorrectEnabled = false,
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(onDone = { onDismiss() }),
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focusRequester),
            )
        }
        EditField.NAME -> {
            OutlinedTextField(
                value = name,
                onValueChange = onNameChanged,
                label = { Text("Name") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    autoCorrectEnabled = false,
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(onDone = { onDismiss() }),
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focusRequester),
            )
        }
        EditField.QTH -> {
            OutlinedTextField(
                value = qth,
                onValueChange = { onQthChanged(it.uppercase()) },
                label = { Text("QTH") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Characters,
                    autoCorrectEnabled = false,
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(onDone = { onDismiss() }),
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focusRequester),
            )
        }
        EditField.NONE -> { /* no-op */ }
    }
}
