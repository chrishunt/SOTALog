package com.sotalog.android.ui.sync

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.clickable
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sotalog.android.ui.theme.SOTALogTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QRZLoginScreen(
    service: String,
    onBack: () -> Unit = {},
    viewModel: QRZSyncViewModel = hiltViewModel(),
) {
    val isTestingCredentials by viewModel.isTestingCredentials.collectAsStateWithLifecycle()
    val apiKeyTestResult by viewModel.apiKeyTestResult.collectAsStateWithLifecycle()
    val xmlLoginTestResult by viewModel.xmlLoginTestResult.collectAsStateWithLifecycle()

    val isLogbook = service == "logbook"
    val title = if (isLogbook) "Logbook Sync" else "Callsign Lookup"

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (isLogbook) {
                LogbookLoginContent(
                    isTestingCredentials = isTestingCredentials,
                    testResult = apiKeyTestResult,
                    onSave = { apiKey ->
                        viewModel.saveAPIKey(apiKey)
                    },
                    onSuccess = onBack,
                )
            } else {
                CallsignLoginContent(
                    isTestingCredentials = isTestingCredentials,
                    testResult = xmlLoginTestResult,
                    onSave = { username, password ->
                        viewModel.saveCallsignCredentials(username, password)
                    },
                    onSuccess = onBack,
                )
            }
        }
    }
}

@Composable
private fun LogbookLoginContent(
    isTestingCredentials: Boolean,
    testResult: CredentialTestResult?,
    onSave: (String) -> Unit,
    onSuccess: () -> Unit,
) {
    var apiKey by remember { mutableStateOf("") }
    var didSave by remember { mutableStateOf(false) }
    val uriHandler = LocalUriHandler.current

    OutlinedTextField(
        value = apiKey,
        onValueChange = { apiKey = it },
        label = { Text("API Key") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Text,
            imeAction = ImeAction.Done,
        ),
        keyboardActions = KeyboardActions(
            onDone = {
                didSave = true
                onSave(apiKey)
            },
        ),
    )

    Text(
        text = "Find your API key at QRZ.com",
        style = MaterialTheme.typography.bodySmall.copy(
            color = MaterialTheme.colorScheme.primary,
            textDecoration = TextDecoration.Underline,
        ),
        modifier = Modifier.clickable {
            uriHandler.openUri("https://www.qrz.com/docs/logbook30/api")
        },
    )

    if (didSave) {
        CredentialStatusIndicator(
            isTesting = isTestingCredentials,
            result = testResult,
            label = "API key",
        )
    }

    Spacer(modifier = Modifier.height(8.dp))

    Button(
        onClick = {
            didSave = true
            onSave(apiKey)
        },
        enabled = apiKey.isNotBlank() && !isTestingCredentials,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text("Save", fontWeight = FontWeight.Bold)
    }

    // Auto-navigate back on success
    LaunchedEffect(testResult) {
        if (didSave && testResult is CredentialTestResult.Success) {
            onSuccess()
        }
    }
}

@Composable
private fun CallsignLoginContent(
    isTestingCredentials: Boolean,
    testResult: CredentialTestResult?,
    onSave: (String, String) -> Unit,
    onSuccess: () -> Unit,
) {
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var didSave by remember { mutableStateOf(false) }

    OutlinedTextField(
        value = username,
        onValueChange = { username = it },
        label = { Text("Callsign") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Text,
            imeAction = ImeAction.Next,
        ),
    )

    OutlinedTextField(
        value = password,
        onValueChange = { password = it },
        label = { Text("Password") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Password,
            imeAction = ImeAction.Done,
        ),
        keyboardActions = KeyboardActions(
            onDone = {
                didSave = true
                onSave(username, password)
            },
        ),
    )

    if (didSave) {
        CredentialStatusIndicator(
            isTesting = isTestingCredentials,
            result = testResult,
            label = "Credentials",
        )
    }

    Spacer(modifier = Modifier.height(8.dp))

    Button(
        onClick = {
            didSave = true
            onSave(username, password)
        },
        enabled = username.isNotBlank() && password.isNotBlank() && !isTestingCredentials,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text("Save", fontWeight = FontWeight.Bold)
    }

    // Auto-navigate back on success
    LaunchedEffect(testResult) {
        if (didSave && testResult is CredentialTestResult.Success) {
            onSuccess()
        }
    }
}

@Composable
private fun CredentialStatusIndicator(
    isTesting: Boolean,
    result: CredentialTestResult?,
    label: String,
) {
    val appColors = SOTALogTheme.appColors

    if (isTesting && result == null) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            CircularProgressIndicator(modifier = Modifier.size(16.dp))
            Text(
                text = "Testing ${label.lowercase()}...",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    } else if (result != null) {
        when (result) {
            is CredentialTestResult.Success -> {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = appColors.green,
                        modifier = Modifier.size(16.dp),
                    )
                    Text(
                        text = "$label verified",
                        style = MaterialTheme.typography.bodySmall,
                        color = appColors.green,
                    )
                }
            }
            is CredentialTestResult.Failure -> {
                Row(
                    verticalAlignment = Alignment.Top,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(
                        Icons.Default.Error,
                        contentDescription = null,
                        tint = appColors.red,
                        modifier = Modifier.size(16.dp),
                    )
                    Text(
                        text = result.message,
                        style = MaterialTheme.typography.bodySmall,
                        color = appColors.red,
                        maxLines = 3,
                    )
                }
            }
        }
    }
}
