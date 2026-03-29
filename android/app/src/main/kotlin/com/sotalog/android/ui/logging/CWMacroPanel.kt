package com.sotalog.android.ui.logging

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.sotalog.android.domain.models.CWMacro
import com.sotalog.android.ui.theme.SOTALogTheme

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun CWMacroPanel(
    macros: List<CWMacro>,
    expandTemplate: (String) -> String = { it },
    onSendMacro: (CWMacro) -> Unit = {},
    onSaveMacro: (CWMacro) -> Unit = {},
    onResetMacro: (Int) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    var editingMacro by remember { mutableStateOf<CWMacro?>(null) }

    // 3x2 grid of macro buttons
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        val rows = macros.chunked(3)
        rows.forEach { rowMacros ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                rowMacros.forEach { macro ->
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier
                            .weight(1f)
                            .height(44.dp)
                            .combinedClickable(
                                onClick = { onSendMacro(macro) },
                                onLongClick = { editingMacro = macro },
                            ),
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(
                                text = macro.label,
                                style = MaterialTheme.typography.labelLarge,
                                fontWeight = FontWeight.Medium,
                                textAlign = TextAlign.Center,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }
                // Fill remaining space if row is shorter than 3
                repeat(3 - rowMacros.size) {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
        }
    }

    // Edit dialog
    editingMacro?.let { macro ->
        CWMacroEditDialog(
            macro = macro,
            expandTemplate = expandTemplate,
            onSave = { updated ->
                onSaveMacro(updated)
                editingMacro = null
            },
            onReset = {
                onResetMacro(macro.position)
                editingMacro = null
            },
            onDismiss = { editingMacro = null },
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CWMacroEditDialog(
    macro: CWMacro,
    expandTemplate: (String) -> String,
    onSave: (CWMacro) -> Unit,
    onReset: () -> Unit,
    onDismiss: () -> Unit,
) {
    var label by remember { mutableStateOf(macro.label) }
    var template by remember { mutableStateOf(macro.template) }

    val preview = expandTemplate(template)
    val variables = listOf("{myCall}", "{call}", "{rst}", "{mySOTA}", "{myPOTA}", "{activity}")

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Edit Macro") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = label,
                    onValueChange = { label = it },
                    label = { Text("Button Label") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )

                OutlinedTextField(
                    value = template,
                    onValueChange = { template = it },
                    label = { Text("Template") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )

                // Variable chips
                Text(
                    text = "Variables",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    variables.forEach { variable ->
                        Surface(
                            shape = RoundedCornerShape(50),
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.1f),
                        ) {
                            Text(
                                text = variable,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                            )
                        }
                    }
                }

                // Preview
                if (preview.isNotEmpty()) {
                    Text(
                        text = "Preview",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = preview,
                        style = MaterialTheme.typography.bodySmall.copy(
                            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                        ),
                    )
                    Text(
                        text = "${preview.length}/24",
                        style = MaterialTheme.typography.labelSmall,
                        color = if (preview.length > 24) {
                            SOTALogTheme.appColors.red
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                    )
                }

                // Reset to default button
                TextButton(
                    onClick = onReset,
                    modifier = Modifier.align(Alignment.CenterHorizontally),
                ) {
                    Text(
                        text = "Reset to Default",
                        color = SOTALogTheme.appColors.red,
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    onSave(macro.copy(label = label, template = template))
                },
                enabled = label.isNotBlank() && template.isNotBlank() && preview.length <= 24,
            ) {
                Text("Save", fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        },
    )
}
