package com.sotalog.android.ui.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import com.sotalog.android.ui.activations.LogListScreen
import com.sotalog.android.ui.activations.NewLogScreen
import com.sotalog.android.ui.logging.ActiveLogScreen
import com.sotalog.android.ui.sync.QRZLoginScreen
import com.sotalog.android.ui.sync.QRZSyncScreen
import com.sotalog.android.ui.sync.ReferenceManagerScreen
import kotlinx.serialization.Serializable

// Type-safe route definitions
@Serializable
object LogList

@Serializable
object NewLog

@Serializable
data class ActiveLog(val logId: Long)

@Serializable
object QRZSync

@Serializable
data class QRZLogin(val service: String)

@Serializable
object ReferenceManager

// Tab definitions
enum class TopLevelRoute(
    val label: String,
    val icon: ImageVector,
    val route: Any,
) {
    Activations("Activations", Icons.AutoMirrored.Filled.List, LogList),
    Sync("Sync", Icons.Default.Sync, QRZSync),
}

@Composable
fun SOTALogNavigation() {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    val showBottomBar = TopLevelRoute.entries.any { tab ->
        currentDestination?.hierarchy?.any { it.hasRoute(tab.route::class) } == true
    }

    Scaffold(
        bottomBar = {
            AnimatedVisibility(
                visible = showBottomBar,
                enter = slideInVertically { it },
                exit = slideOutVertically { it },
            ) {
                NavigationBar {
                    TopLevelRoute.entries.forEach { tab ->
                        NavigationBarItem(
                            icon = { Icon(tab.icon, contentDescription = tab.label) },
                            label = { Text(tab.label) },
                            selected = currentDestination?.hierarchy?.any {
                                it.hasRoute(tab.route::class)
                            } == true,
                            onClick = {
                                navController.navigate(tab.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                        )
                    }
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = LogList,
            enterTransition = { fadeIn() + slideInHorizontally { it / 4 } },
            exitTransition = { fadeOut() + slideOutHorizontally { -it / 4 } },
            popEnterTransition = { fadeIn() + slideInHorizontally { -it / 4 } },
            popExitTransition = { fadeOut() + slideOutHorizontally { it / 4 } },
            modifier = Modifier.padding(innerPadding),
        ) {
            composable<LogList> {
                LogListScreen(
                    onNewLog = { navController.navigate(NewLog) },
                    onOpenLog = { navController.navigate(ActiveLog(it)) },
                )
            }
            composable<NewLog> {
                NewLogScreen(
                    onLogCreated = { logId ->
                        navController.navigate(ActiveLog(logId)) {
                            popUpTo<LogList>()
                        }
                    },
                    onBack = { navController.popBackStack() },
                )
            }
            composable<ActiveLog> { backStackEntry ->
                val activeLog = backStackEntry.toRoute<ActiveLog>()
                ActiveLogScreen(
                    logId = activeLog.logId,
                    onBack = { navController.popBackStack() },
                )
            }
            composable<QRZSync> {
                QRZSyncScreen(
                    onLoginLogbook = { navController.navigate(QRZLogin("logbook")) },
                    onLoginCallsign = { navController.navigate(QRZLogin("callsign")) },
                    onReferenceManager = { navController.navigate(ReferenceManager) },
                )
            }
            composable<QRZLogin> { backStackEntry ->
                val login = backStackEntry.toRoute<QRZLogin>()
                QRZLoginScreen(
                    service = login.service,
                    onBack = { navController.popBackStack() },
                )
            }
            composable<ReferenceManager> {
                ReferenceManagerScreen(
                    onBack = { navController.popBackStack() },
                )
            }
        }
    }
}
