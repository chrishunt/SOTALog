package com.sotalog.android.ui.logging

import android.view.HapticFeedbackConstants
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sotalog.android.ui.components.CallsignField
import com.sotalog.android.ui.components.MetadataStrip
import com.sotalog.android.ui.components.NumberKeyRow
import com.sotalog.android.ui.theme.SOTALogTheme

/**
 * QSO entry panel pinned at the bottom of the active log screen.
 * Contains the OmniField (callsign input), metadata strip, and number key row.
 */
@Composable
fun QSOEntryPanel(
    logId: Long,
    viewModel: QSOEntryViewModel = hiltViewModel(),
) {
    val appColors = SOTALogTheme.appColors
    val view = LocalView.current

    val entryText by viewModel.entryText.collectAsStateWithLifecycle()
    var textFieldValue by remember { mutableStateOf(TextFieldValue("")) }

    // Sync ViewModel → TextFieldValue when ViewModel clears/changes the text externally
    LaunchedEffect(entryText) {
        if (entryText != textFieldValue.text) {
            textFieldValue = TextFieldValue(entryText, TextRange(entryText.length))
        }
    }

    val rstSent by viewModel.rstSent.collectAsStateWithLifecycle()
    val rstReceived by viewModel.rstReceived.collectAsStateWithLifecycle()
    val frequencyText by viewModel.frequencyText.collectAsStateWithLifecycle()
    val mode by viewModel.mode.collectAsStateWithLifecycle()
    val name by viewModel.name.collectAsStateWithLifecycle()
    val qth by viewModel.qth.collectAsStateWithLifecycle()
    val potaRefInput by viewModel.potaRefInput.collectAsStateWithLifecycle()
    val potaRefFormatted by viewModel.potaRefFormatted.collectAsStateWithLifecycle()
    val potaRefValid by viewModel.potaRefValid.collectAsStateWithLifecycle()
    val sotaRefInput by viewModel.sotaRefInput.collectAsStateWithLifecycle()
    val sotaRefFormatted by viewModel.sotaRefFormatted.collectAsStateWithLifecycle()
    val sotaRefValid by viewModel.sotaRefValid.collectAsStateWithLifecycle()
    val timesWorked by viewModel.timesWorked.collectAsStateWithLifecycle()
    val workedToday by viewModel.workedToday.collectAsStateWithLifecycle()
    val isDupe by viewModel.isDupe.collectAsStateWithLifecycle()
    val saveCount by viewModel.saveCount.collectAsStateWithLifecycle()
    val editingQSO by viewModel.editingQSO.collectAsStateWithLifecycle()

    val focusRequester = remember { FocusRequester() }

    // Haptic feedback on save
    LaunchedEffect(saveCount) {
        if (saveCount > 0) {
            view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
        }
    }

    // Auto-focus the callsign field
    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceContainer),
    ) {
        HorizontalDivider()

        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            // Editing banner
            if (editingQSO != null) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            color = appColors.orange.copy(alpha = 0.1f),
                            shape = RoundedCornerShape(8.dp),
                        )
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                ) {
                    Icon(
                        Icons.Default.Edit,
                        contentDescription = null,
                        tint = appColors.orange,
                    )
                    Text(
                        text = "Editing: ${viewModel.parsedCallsign}",
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                        color = appColors.orange,
                        modifier = Modifier.padding(start = 8.dp),
                    )
                    Spacer(Modifier.weight(1f))
                    TextButton(onClick = { viewModel.cancelEditing() }) {
                        Text("Cancel", color = appColors.orange)
                    }
                }
            }

            // Metadata strip
            MetadataStrip(
                rstSent = rstSent,
                onRstSentChanged = { viewModel.onRstSentChanged(it) },
                rstReceived = rstReceived,
                onRstReceivedChanged = { viewModel.onRstReceivedChanged(it) },
                frequencyText = frequencyText,
                onFrequencyChanged = { viewModel.onFrequencyChanged(it) },
                mode = mode,
                onModeToggle = { viewModel.toggleMode() },
                name = name,
                onNameChanged = { viewModel.onNameChanged(it) },
                qth = qth,
                onQthChanged = { viewModel.onQthChanged(it) },
                potaRefInput = potaRefInput,
                onPotaRefChanged = { viewModel.onPotaRefChanged(it) },
                potaRefFormatted = potaRefFormatted,
                potaRefValid = potaRefValid,
                sotaRefInput = sotaRefInput,
                onSotaRefChanged = { viewModel.onSotaRefChanged(it) },
                sotaRefFormatted = sotaRefFormatted,
                sotaRefValid = sotaRefValid,
                onSubmit = { focusRequester.requestFocus() },
            )

            // Callsign OmniField
            CallsignField(
                textFieldValue = textFieldValue,
                onTextFieldValueChanged = { newValue ->
                    textFieldValue = newValue
                    viewModel.onEntryTextChanged(newValue.text)
                },
                timesWorked = timesWorked,
                workedToday = workedToday,
                isDupe = isDupe,
                onSubmit = {
                    viewModel.saveQSO()
                    focusRequester.requestFocus()
                },
                modifier = Modifier.focusRequester(focusRequester),
            )

            // Number key row for quick digit/slash entry
            NumberKeyRow(
                onKey = { char ->
                    val cursor = textFieldValue.selection.start
                    val newText = textFieldValue.text.substring(0, cursor) + char +
                        textFieldValue.text.substring(cursor)
                    val newCursor = cursor + char.length
                    textFieldValue = TextFieldValue(newText, TextRange(newCursor))
                    viewModel.onEntryTextChanged(newText)
                },
            )
        }
    }
}
