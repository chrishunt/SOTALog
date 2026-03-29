package com.sotalog.android.domain.models

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "cwMacro")
data class CWMacro(
    @PrimaryKey(autoGenerate = true)
    val id: Long? = null,
    val position: Int,
    val label: String,
    val template: String,
) {
    companion object {
        val defaults: List<CWMacro> = listOf(
            CWMacro(position = 0, label = "CQ", template = "CQ {activity} DE {myCall} K"),
            CWMacro(position = 1, label = "?", template = "{call}?"),
            CWMacro(position = 2, label = "EXCH", template = "{call} UR {rst} {rst} BK"),
            CWMacro(position = 3, label = "TU", template = "BK TU 72 DE {myCall} E E"),
            CWMacro(position = 4, label = "CALL", template = "{myCall}"),
            CWMacro(position = 5, label = "S2S", template = "BK {rst} ON {mySOTA} BK"),
        )
    }
}
